"""Etiqueta las imagenes de un LoRA con WD14 (wd-v1-4-moat-tagger-v2, en la CPU) y escribe un .txt por imagen.

Uso: python etiquetar_wd14.py <carpeta_imagenes> <carpeta_modelo> <palabra_clave> [--quitar "long hair, red eyes"] [--umbral 0.35] [--todas]
Cada .txt queda: "<palabra_clave>, etiqueta1, etiqueta2, ...". Sin --todas solo etiqueta las imagenes que aun no tienen .txt,
para no perder lo que se haya corregido a mano. Al final muestra las etiquetas mas frecuentes del paquete.
"""
import argparse, collections, csv, sys
from pathlib import Path
import numpy as np
from PIL import Image, ImageOps
from onnxruntime import InferenceSession

EXT = ('.png', '.jpg', '.jpeg', '.webp')
ap = argparse.ArgumentParser()
ap.add_argument('carpeta'); ap.add_argument('modelo'); ap.add_argument('clave')
ap.add_argument('--quitar', default=''); ap.add_argument('--umbral', type=float, default=0.35); ap.add_argument('--todas', action='store_true')
a = ap.parse_args()
carpeta, modelo = Path(a.carpeta), Path(a.modelo)


def limpio(tag):
    # como kohya --remove_underscore: los emoticones cortos (^_^, >_<) se dejan igual
    return tag.replace('_', ' ') if len(tag) > 3 else tag


quitar = {t.strip().lower() for t in a.quitar.split(',') if t.strip()}
nombres, generales = [], []
with open(modelo / 'selected_tags.csv', encoding='utf-8') as f:
    r = csv.reader(f); next(r)
    for fila in r:
        nombres.append(limpio(fila[1])); generales.append(fila[2] == '0')   # 9 = rating, 4 = personaje conocido: no se usan

fotos = sorted(p for p in carpeta.iterdir() if p.suffix.lower() in EXT)
pendientes = [p for p in fotos if a.todas or not p.with_suffix('.txt').exists()]
if pendientes:
    sesion = InferenceSession(str(modelo / 'model.onnx'), providers=['CPUExecutionProvider'])
    entrada = sesion.get_inputs()[0]; lado = entrada.shape[1]
    for i, p in enumerate(pendientes, 1):
        img = ImageOps.exif_transpose(Image.open(p)).convert('RGB')
        k = lado / max(img.size)
        img = img.resize((int(img.width * k), int(img.height * k)), Image.LANCZOS)
        cuadro = Image.new('RGB', (lado, lado), (255, 255, 255))
        cuadro.paste(img, ((lado - img.width) // 2, (lado - img.height) // 2))
        x = np.asarray(cuadro, dtype=np.float32)[:, :, ::-1][None]   # el modelo espera BGR
        prob = sesion.run([sesion.get_outputs()[0].name], {entrada.name: x})[0][0]
        tags = [t for _, t in sorted(((prob[j], nombres[j]) for j in range(len(nombres)) if generales[j] and prob[j] > a.umbral), reverse=True)]
        p.with_suffix('.txt').write_text(', '.join(tags) + '\n', encoding='utf-8')
        print(f'  [{i}/{len(pendientes)}] {p.name}: {len(tags)} etiquetas', flush=True)
    print(f'Etiquetadas {len(pendientes)} imagenes.')
else:
    print('Todas las imagenes ya tenian su .txt (para rehacerlas usa -Reetiquetar).')

# todos los .txt (tambien los corregidos a mano): palabra clave primero y sin las etiquetas de "quitar"
cuenta = collections.Counter()
for p in fotos:
    txt = p.with_suffix('.txt')
    if not txt.exists():
        continue
    tags = [t.strip() for t in txt.read_text(encoding='utf-8').split(',')]
    tags = [t for t in tags if t and t != a.clave and t.lower() not in quitar]
    txt.write_text(', '.join([a.clave] + tags) + '\n', encoding='utf-8')
    cuenta.update(set(tags))

# resumen: etiquetas que salen en casi todas las imagenes suelen ser rasgos fijos que conviene quitar
n = len(fotos)
frec = [f'{t}: {c}/{n}' for t, c in cuenta.most_common()]
(carpeta.parent.parent / 'etiquetas_frecuentes.txt').write_text('\n'.join(frec) + '\n', encoding='utf-8')
print('\nEtiquetas mas frecuentes (si alguna es un rasgo que SIEMPRE tiene, agregala a los rasgos fijos y vuelve a ejecutar):')
print('  ' + ', '.join(frec[:30]))
sys.exit(0)
