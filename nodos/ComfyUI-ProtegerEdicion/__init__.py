"""ComfyUI-ProtegerEdicion: pega sobre la imagen original solo la zona que el modelo de edicion realmente cambio.

Mismo algoritmo que "Proteger lo que no cambio" de Editor-Kontext.html (alli corre en el navegador):
compara original y editada a 256 px, umbraliza la diferencia, cierra la mascara (dilatar + erosionar, sin perder
zonas chicas como una boca), rellena los huecos interiores, agrega un margen y la lleva al tamano completo con un
borde suave de 6 px.
Fuera de esa zona el resultado es identico al original.
"""
import logging
import math

import numpy as np
import scipy.ndimage
import torch
import torch.nn.functional as F
import torchvision.transforms.functional as TF

import comfy.model_management
import comfy.utils
from comfy.cli_args import args

MIN_ZONA = 6     # pixeles (a 256 px): zonas mas chicas son ruido
LOCAL = 0.05       # fraccion de la imagen bajo la cual una edicion se considera local
VECINDARIO = 0.06  # en ediciones locales se toma de Qwen hasta esta distancia (fraccion del lado mayor) de lo detectado


def _blur(m, sigma):
    k = 2 * math.ceil(3 * sigma) + 1
    return TF.gaussian_blur(m, [k, k], [sigma, sigma])


def _blur_thr(m, sigma, thr):
    # umbral bajo = dilatar, umbral alto = erosionar
    return (_blur(m, sigma) > thr).float()


def change_mask(orig, edit, umbral):
    """orig, edit: [H, W, C] en 0..1, mismo tamano. Devuelve la mascara alfa [H, W] de la zona editada."""
    h, w = orig.shape[:2]
    s = 256 / max(h, w)
    sh, sw = max(16, round(h * s)), max(16, round(w * s))
    a = F.interpolate(orig.movedim(-1, 0)[None], (sh, sw), mode="bilinear", antialias=True)
    b = F.interpolate(edit.movedim(-1, 0)[None], (sh, sw), mode="bilinear", antialias=True)
    d = ((a - b).abs().mean(1, keepdim=True) * 2).clamp(max=1.0)
    db = _blur(d, 1.5)[0, 0].numpy()
    # En ediciones locales (gestos, accesorios) se toma todo el vecindario de lo detectado: al pedir una sonrisa los
    # ojos cambian mucho pero la boca puede ser solo una linea fina desplazada, que no supera el umbral, y la cara
    # quedaria mezclada. En ediciones grandes no: ahi el vecindario seria la deriva de Qwen alrededor del cambio.
    lab, n = scipy.ndimage.label(db > umbral * 2 / 255)
    det = np.isin(lab, np.nonzero(np.bincount(lab.ravel())[1:] >= MIN_ZONA)[0] + 1)
    if det.any() and det.mean() < LOCAL:
        det = scipy.ndimage.distance_transform_edt(~det) <= VECINDARIO * max(sh, sw)
    m = torch.from_numpy(det).float()[None, None]
    # el cierre (dilatar + erosionar) borra zonas chicas como un ojo: se vuelven a sumar las detectadas
    m = torch.maximum(_blur_thr(_blur_thr(m, 3, 0.08), 3, 0.92), m)
    m = torch.from_numpy(scipy.ndimage.binary_fill_holes(m[0, 0].numpy() > 0.5)).float()[None, None]
    m = _blur_thr(m, 2.5, 0.08)
    full = F.interpolate(m, (h, w), mode="bilinear")
    return (_blur(full, 6) * 2).clamp(max=1.0)[0, 0]


def _ayuda_vae():
    if args.fp32_vae:
        return ("ComfyUI ya usa el VAE en precision completa (--fp32-vae), asi que no deberia pasar: prueba otra vez con "
                "otra variante y, si se repite, manda la ventana de ComfyUI completa a quien te ayuda.")
    return ("ComfyUI arranco SIN --fp32-vae (VAE en precision completa), que evita esto en tarjetas AMD. Cierra la ventana "
            "de ComfyUI y abrelo con Abrir-Editor-Qwen.bat (no con comfyui-rocm.bat). Si sigue, corre 4-Arreglo-AMD.bat.")


def _sin_nan(t):
    return torch.isfinite(t).all().item()


class VerificarValores:
    """Revisa que no haya valores invalidos (NaN) antes de decodificar, para decir en que parte se danaron."""

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"samples": ("LATENT",), "positive": ("CONDITIONING",)}}

    RETURN_TYPES = ("LATENT",)
    FUNCTION = "verificar"
    CATEGORY = "image/edicion"
    DESCRIPTION = "Detiene la edicion con un mensaje claro si el texto, la imagen de referencia o el dibujo traen valores invalidos (NaN)."

    def verificar(self, samples, positive):
        for t, extra in positive:
            for ref in extra.get("reference_latents", None) or []:
                if not _sin_nan(ref):
                    raise RuntimeError("Tu imagen se dano al leerla con el VAE (valores invalidos, NaN). " + _ayuda_vae())
            if not _sin_nan(t):
                raise RuntimeError("El codificador de texto produjo valores invalidos (NaN). Prueba otra vez con otra variante; "
                                   "si se repite, manda la ventana de ComfyUI completa a quien te ayuda.")
        if not _sin_nan(samples["samples"]):
            raise RuntimeError("El modelo de edicion produjo valores invalidos (NaN) mientras dibujaba. Prueba el otro modo "
                               "(Rapido o Calidad); si solo falla uno, vuelve a bajar ese modelo con 2-Descargar-Modelos.bat "
                               "(puede estar danado). Si fallan los dos, manda la ventana de ComfyUI completa a quien te ayuda.")
        return (samples,)


class ProtegerSinCambios:
    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {
            "original": ("IMAGE",),
            "editada": ("IMAGE",),
            "umbral": ("INT", {"default": 20, "min": 1, "max": 128, "tooltip": "Diferencia media (sobre 255) desde la que un pixel cuenta como editado. Mas alto = zona mas chica."}),
        }}

    RETURN_TYPES = ("IMAGE", "MASK")
    RETURN_NAMES = ("imagen", "zona_editada")
    FUNCTION = "proteger"
    CATEGORY = "image/edicion"
    DESCRIPTION = "Escala la imagen editada al tamano del original y pega solo la zona que cambio; el resto queda identico al original."

    def proteger(self, original, editada, umbral):
        h, w = original.shape[1:3]
        # Qwen-Image-2.1 decodifica RGBA; con un original opaco el alfa es solo ruido (~0.8-1.0), se usa RGB
        editada = editada[..., :3]
        if not _sin_nan(editada):
            raise RuntimeError("La imagen se dano al decodificarla con el VAE (valores invalidos, NaN): saldria negra o con ruido. "
                               + _ayuda_vae())
        editada = comfy.utils.common_upscale(editada.movedim(-1, 1), w, h, "lanczos", "disabled").movedim(1, -1)
        imagenes, mascaras = [], []
        for i in range(editada.shape[0]):
            orig = original[min(i, original.shape[0] - 1)]
            alpha = change_mask(orig, editada[i], umbral)
            cobertura = (alpha > 0.5).float().mean().item()
            logging.info(f"Proteger: zona editada {cobertura:.1%} de la imagen")
            if cobertura <= 0.003:
                # casi nada cambio: se entrega la salida del modelo tal cual
                alpha = torch.ones_like(alpha)
            imagenes.append(orig * (1 - alpha[..., None]) + editada[i] * alpha[..., None])
            mascaras.append(alpha)
        return (torch.stack(imagenes), torch.stack(mascaras))


if comfy.model_management.is_amd() and not args.fp32_vae:
    logging.warning("[Editor Qwen] Tarjeta AMD sin --fp32-vae: pueden salir imagenes negras o con ruido. "
                    "Abre ComfyUI con Abrir-Editor-Qwen.bat (o corre 4-Arreglo-AMD.bat).")

NODE_CLASS_MAPPINGS = {"ProtegerSinCambios": ProtegerSinCambios, "VerificarValores": VerificarValores}
NODE_DISPLAY_NAME_MAPPINGS = {"ProtegerSinCambios": "Proteger lo que no cambio", "VerificarValores": "Verificar valores (NaN)"}
