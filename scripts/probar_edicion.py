"""Prueba de punta a punta del Editor Qwen contra un ComfyUI en marcha. Usa la libreria estandar + Pillow/numpy (ComfyUI ya los trae).

Uso:  probar_edicion.py [--server http://127.0.0.1:8188] [--imagen ruta.png] [--instr "texto en ingles"] [--res 512] [--pasos 25]

Hace una edicion con EXACTAMENTE el mismo grafo que el editor web (Qwen-Image-2.1 + proteger lo que no cambio), mide el tiempo
y dice si la imagen cambio y que parte se tomo de Qwen. Deja el resultado en referencia\\resultado_prueba.png.
"""
import argparse, json, os, re, sys, time, uuid, urllib.request, urllib.parse

aqui = os.path.dirname(os.path.abspath(__file__))
ap = argparse.ArgumentParser()
ap.add_argument('--server', default='http://127.0.0.1:8188')
ap.add_argument('--imagen', required=True, help='imagen de una persona o personaje con el pelo visible')
ap.add_argument('--instr', default='Change the hair color to red. Keep everything else unchanged.')
ap.add_argument('--res', type=int, default=512, help='resolucion de trabajo: 512 = prueba rapida, 1024 = calidad del editor')
ap.add_argument('--pasos', type=int, default=25)
ap.add_argument('--salida', default=os.path.join(aqui, '..', 'referencia', 'resultado_prueba.png'))
ap.add_argument('--solo-comprobar', action='store_true', help='revisa nodos y modelos y sube la imagen, sin generar (no usa la GPU)')
a = ap.parse_args()
SRV = a.server.rstrip('/')
a.imagen = a.imagen.strip().strip('"')
if not os.path.isfile(a.imagen):
    sys.exit(f'No encuentro la imagen "{a.imagen}". Arrastra a la ventana una imagen (PNG o JPG) de una persona o personaje.')


def get(path, raw=False):
    r = urllib.request.urlopen(SRV + path, timeout=60)
    return r.read() if raw else json.load(r)


def opts(spec):  # lista desplegable en formato clasico [[...],{}] o nuevo ["COMBO",{"options":[...]}]
    if spec and isinstance(spec[0], list):
        return spec[0]
    return (spec[1].get('options') if len(spec) > 1 and isinstance(spec[1], dict) else None) or []


def requeridos(node):
    try:
        return get('/object_info/' + urllib.parse.quote(node, safe=''))[node]['input']['required']
    except Exception:
        return None


print('== Comprobando ComfyUI, nodos y modelos ==')
try:
    st = get('/system_stats')
except Exception as e:
    sys.exit(f'ComfyUI no responde en {SRV} ({e}). Abrelo con Abrir-Editor-Qwen.bat y vuelve a intentar.')
dev = (st.get('devices') or [{}])[0]
gpu = re.sub(r'^\w+:\d+\s*', '', dev.get('name', '?')).rsplit(' : ', 1)[0]   # "cuda:0 NVIDIA GeForce GTX 1070 : cudaMallocAsync" -> nombre
print(f"GPU: {gpu}  |  VRAM {dev.get('vram_total', 0) / 2**30:.1f} GB  |  ComfyUI {st['system'].get('comfyui_version')}  |  torch {st['system'].get('pytorch_version')}")

falta = []
for n in ('TextEncodeQwenImage21', 'QwenImage21Cache'):
    if not requeridos(n):
        falta.append(f'nodo {n} (tu ComfyUI es demasiado viejo: necesitas 0.37 o mas)')
u, c, v = requeridos('UnetLoaderGGUF'), requeridos('CLIPLoader'), requeridos('VAELoader')
if not requeridos('ProtegerSinCambios'):
    falta.append('nodo ProtegerSinCambios (ejecuta 1-Instalar-Nodos.bat y reinicia ComfyUI)')
unet = next((m for m in opts(u['unet_name']) if 'qwen-image-2.1' in m.lower() and m.endswith('.gguf')), None) if u else None
clip = sorted(m for m in opts(c['clip_name']) if 'qwen3vl_8b' in m.lower()) if c else []
vae = next((m for m in opts(v['vae_name']) if 'qwen_image_2.1_vae' in m.lower()), None) if v else None
if not u: falta.append('nodo ComfyUI-GGUF (ejecuta 1-Instalar-Nodos.bat)')
elif not unet: falta.append('qwen-image-2.1-*.gguf en models\\diffusion_models')
if not clip: falta.append('qwen3vl_8b_*.safetensors en models\\text_encoders')
if not vae: falta.append('qwen_image_2.1_vae_bf16.safetensors en models\\vae')
try:
    get('/editor-qwen', raw=True)
except Exception:
    falta.append('el editor web /editor-qwen (ejecuta 1-Instalar-Nodos.bat y reinicia ComfyUI)')
if falta:
    sys.exit('FALTA:\n  - ' + '\n  - '.join(falta))
clip = next((m for m in clip if 'int8' in m.lower()), clip[0])   # como el editor: se prefiere int8 si esta
verificar = requeridos('VerificarValores') is not None
print(f'Modelo: {unet}  |  texto: {clip}  |  VAE: {vae}')

print('\n== Subiendo la imagen de prueba ==')
img_bytes = open(a.imagen, 'rb').read()
limite = uuid.uuid4().hex
cuerpo = (f'--{limite}\r\nContent-Disposition: form-data; name="image"; filename="prueba_editor_qwen.png"\r\n'
          f'Content-Type: image/png\r\n\r\n').encode() + img_bytes + (
          f'\r\n--{limite}\r\nContent-Disposition: form-data; name="overwrite"\r\n\r\ntrue\r\n--{limite}--\r\n').encode()
r = json.load(urllib.request.urlopen(urllib.request.Request(SRV + '/upload/image', data=cuerpo,
                                     headers={'Content-Type': 'multipart/form-data; boundary=' + limite}), timeout=60))
nombre = (r.get('subfolder') + '/' if r.get('subfolder') else '') + r['name']
print(f'Imagen subida como "{nombre}"')
if a.solo_comprobar:
    print('\nComprobacion OK: ComfyUI, nodos, modelos y editor estan listos (no se genero nada).')
    sys.exit(0)

g = {
    '1': {'class_type': 'LoadImage', 'inputs': {'image': nombre}},
    '2': {'class_type': 'UnetLoaderGGUF', 'inputs': {'unet_name': unet}},
    '3': {'class_type': 'QwenImage21Cache', 'inputs': {'model': ['2', 0], 'device': 'auto', 'dtype': 'default'}},
    '4': {'class_type': 'CLIPLoader', 'inputs': {'clip_name': clip, 'type': 'qwen_image', 'device': 'default'}},
    '5': {'class_type': 'VAELoader', 'inputs': {'vae_name': vae}},
    '6': {'class_type': 'TextEncodeQwenImage21', 'inputs': {'clip': ['4', 0], 'prompt': a.instr, 'negative_prompt': '', 'resolution': a.res,
                                                            'images.image_1': ['1', 0], 'vae': ['5', 0]}},
    '7': {'class_type': 'KSampler', 'inputs': {'model': ['3', 0], 'positive': ['6', 0], 'negative': ['6', 1], 'latent_image': ['6', 2],
                                               'seed': 42, 'steps': a.pasos, 'cfg': 1.0, 'sampler_name': 'euler', 'scheduler': 'simple', 'denoise': 1.0}},
    '8': {'class_type': 'VAEDecode', 'inputs': {'samples': ['16' if verificar else '7', 0], 'vae': ['5', 0]}},
    '12': {'class_type': 'ProtegerSinCambios', 'inputs': {'original': ['1', 0], 'editada': ['8', 0], 'umbral': 20}},
    '9': {'class_type': 'SaveImage', 'inputs': {'images': ['12', 0], 'filename_prefix': 'EditorQwen/prueba'}},
    '15': {'class_type': 'MaskToImage', 'inputs': {'mask': ['12', 1]}},
    '14': {'class_type': 'PreviewImage', 'inputs': {'images': ['15', 0]}},
}
if verificar:   # dice en que parte salieron valores invalidos (NaN), si pasa
    g['16'] = {'class_type': 'VerificarValores', 'inputs': {'samples': ['7', 0], 'positive': ['6', 0]}}
print(f'\n== Editando: "{a.instr}"  (resolucion {a.res}, {a.pasos} pasos) ==')
print('La primera vez carga los modelos (puede tardar varios minutos sin mostrar avance).')
t0 = time.time()
try:
    pid = json.load(urllib.request.urlopen(urllib.request.Request(SRV + '/prompt', data=json.dumps({'prompt': g}).encode(),
                                           headers={'Content-Type': 'application/json'}), timeout=60))['prompt_id']
except urllib.error.HTTPError as e:
    sys.exit('ComfyUI rechazo el trabajo: ' + e.read().decode()[:2000])
ultimo = 0
while True:
    time.sleep(5)
    h = get('/history/' + pid)
    if pid in h:
        break
    if time.time() - ultimo > 60:
        ultimo = time.time()
        print(f'  ... {int(time.time() - t0)} s')
seg = time.time() - t0
e = h[pid]
if e['status'].get('status_str') != 'success':
    err = next((m[1] for m in e['status'].get('messages', []) if m[0] == 'execution_error'), {})
    sys.exit(f"ERROR en ComfyUI tras {seg:.0f} s: {err.get('node_type')} - {err.get('exception_message', '')}")


def bajar(o):
    q = urllib.parse.urlencode({'filename': o['filename'], 'subfolder': o.get('subfolder', ''), 'type': o['type']})
    return get('/view?' + q, raw=True)


res = bajar(e['outputs']['9']['images'][0])
open(a.salida, 'wb').write(res)
print(f'\nTiempo total: {seg / 60:.1f} min ({seg:.0f} s).  Resultado: {os.path.abspath(a.salida)}')
try:
    import io
    import numpy as np
    from PIL import Image
    o = np.asarray(Image.open(a.imagen).convert('RGB'), float)
    p = np.asarray(Image.open(io.BytesIO(res)).convert('RGB'), float)
    z = np.asarray(Image.open(io.BytesIO(bajar(e['outputs']['14']['images'][0]))).convert('L'), float) / 255
    dif = np.abs(o - p).mean()
    zona = (z > 0.5).mean() * 100
    fuera = np.abs(o - p).mean(-1)[z < 0.02].mean() if (z < 0.02).any() else float('nan')
    print(f'Diferencia con la original: {dif:.1f}/255  |  zona tomada de Qwen: {zona:.1f} %  |  fuera de esa zona: {fuera:.2f}/255 (0 = identica)')
    if dif < 2:
        print('=> La imagen salio practicamente IGUAL. Revisa la seccion "Problemas" de la guia.')
    else:
        print('=> La imagen CAMBIO y lo demas quedo protegido. Abre el resultado: el pelo debe verse rojo.')
except Exception as ex:
    print(f'(no pude comparar las imagenes: {ex})')
