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
import nodes
from comfy.cli_args import args

try:
    import comfy.memory_management as memoria
except ImportError:  # ComfyUI antiguo, sin memoria dinamica (DynamicVRAM)
    memoria = None

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
        return ("ComfyUI ya usa el VAE en precision completa (--fp32-vae). Cierra la ventana de ComfyUI, abrelo de nuevo con "
                "Abrir-Editor-Qwen.bat (asi vuelve a leer los modelos del disco) y prueba otra vez; si se repite, manda la "
                "ventana de ComfyUI completa a quien te ayuda.")
    return ("ComfyUI arranco SIN --fp32-vae (VAE en precision completa), que evita esto en tarjetas AMD. Cierra la ventana "
            "de ComfyUI y abrelo con Abrir-Editor-Qwen.bat (no con comfyui-rocm.bat). Si sigue, corre 4-Arreglo-AMD.bat.")


def _sin_nan(t):
    return torch.isfinite(t).all().item()


def _amd_dinamico():
    # En Radeon con memoria dinamica (DynamicVRAM) un modelo que queda cargado en la tarjeta entre usos puede leer pesos
    # danados y dar NaN, sobre todo si el VAE necesita mas memoria de la libre (Comfy-Org/ComfyUI#15452). Con todo
    # recien cargado funciona: la primera edicion tras abrir ComfyUI sale bien.
    return comfy.model_management.is_amd() and getattr(memoria, "aimdo_enabled", False)


def _vaciar_vram():
    comfy.model_management.unload_all_models()
    comfy.model_management.soft_empty_cache()


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
        error = self._revisar(samples, positive)
        if error:
            if _amd_dinamico():
                # el siguiente intento parte con los modelos recien cargados
                _vaciar_vram()
                error += (" (En tarjetas AMD a veces se dana un modelo que quedo cargado de la edicion anterior; ya se "
                          "descargaron todos, asi que conviene intentar una vez mas igual.)")
            raise RuntimeError(error)
        return (samples,)

    @staticmethod
    def _revisar(samples, positive):
        for t, extra in positive:
            for ref in extra.get("reference_latents", None) or []:
                if not _sin_nan(ref):
                    return "Tu imagen se dano al leerla con el VAE (valores invalidos, NaN). " + _ayuda_vae()
            if not _sin_nan(t):
                return ("El codificador de texto produjo valores invalidos (NaN). Prueba otra vez con otra variante; "
                        "si se repite, manda la ventana de ComfyUI completa a quien te ayuda.")
        if not _sin_nan(samples["samples"]):
            return ("El modelo de edicion produjo valores invalidos (NaN) mientras dibujaba. Prueba el otro modo "
                    "(Rapido o Calidad); si solo falla uno, vuelve a bajar ese modelo con 2-Descargar-Modelos.bat "
                    "(puede estar danado). Si fallan los dos, manda la ventana de ComfyUI completa a quien te ayuda.")
        return None


class DecodificarSeguro:
    """VAE Decode que no pierde la edicion si el VAE devuelve NaN: descarga los modelos y decodifica otra vez."""

    @classmethod
    def INPUT_TYPES(cls):
        return {"required": {"samples": ("LATENT",), "vae": ("VAE",)}}

    RETURN_TYPES = ("IMAGE",)
    FUNCTION = "decodificar"
    CATEGORY = "image/edicion"
    DESCRIPTION = ("Como VAE Decode, pero si la imagen sale danada (NaN) descarga los modelos de la tarjeta y la decodifica "
                   "otra vez (y si sigue, por partes) en vez de perder lo que el modelo ya dibujo.")

    def decodificar(self, samples, vae):
        amd = _amd_dinamico()
        if amd:
            # el VAE se carga limpio y con toda la VRAM libre, como en la primera edicion tras abrir ComfyUI
            _vaciar_vram()
        try:
            img = nodes.VAEDecode().decode(vae, samples)[0]
            if not _sin_nan(img[..., :3]):
                logging.warning("[Editor Qwen] El VAE devolvio valores invalidos (NaN): se descargan los modelos y se decodifica otra vez.")
                _vaciar_vram()
                img = nodes.VAEDecode().decode(vae, samples)[0]
            if not _sin_nan(img[..., :3]):
                logging.warning("[Editor Qwen] Otra vez NaN: se decodifica por partes de 512 px.")
                _vaciar_vram()
                img = nodes.VAEDecodeTiled().decode(vae, samples, tile_size=512, overlap=64)[0]
        finally:
            if amd:
                # la proxima edicion tambien parte con los modelos recien cargados
                _vaciar_vram()
        if not _sin_nan(img[..., :3]):
            raise RuntimeError("La imagen se dano al decodificarla con el VAE (valores invalidos, NaN), incluso volviendo a "
                               "cargarlo. " + _ayuda_vae())
        return (img,)


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

NODE_CLASS_MAPPINGS = {"ProtegerSinCambios": ProtegerSinCambios, "VerificarValores": VerificarValores,
                       "DecodificarSeguro": DecodificarSeguro}
NODE_DISPLAY_NAME_MAPPINGS = {"ProtegerSinCambios": "Proteger lo que no cambio", "VerificarValores": "Verificar valores (NaN)",
                              "DecodificarSeguro": "VAE Decode con reintento (NaN)"}
