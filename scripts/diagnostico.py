"""Diagnostico rapido de la tarjeta para el Editor Qwen (unos segundos, no necesita ComfyUI abierto).

Mide lo que importa para saber por que una edicion va lenta:
  - cuanto calcula la tarjeta (TFLOPS en fp32, que es como trabaja el modelo en Radeon RX 6000 y GTX 10),
  - a que velocidad copia datos de la RAM a la tarjeta (lo que pasa cuando el modelo no cabe entero),
  - cuanta VRAM y RAM hay libres.
Guarda el resultado en referencia\\diagnostico.txt para mandarlo a quien te ayuda.

Uso:  python diagnostico.py  [--cpu]   (--cpu solo sirve para probar el script)
"""
import os
import platform
import sys
import time

import torch

try:
    import psutil
except ImportError:
    psutil = None

aqui = os.path.dirname(os.path.abspath(__file__))
salida = os.path.join(aqui, '..', 'referencia', 'diagnostico.txt')
lineas = []


def p(t=''):
    print(t, flush=True)
    lineas.append(t)


cpu = '--cpu' in sys.argv
p('== Diagnostico Editor Qwen ==')
p(f'Windows {platform.release()} | Python {platform.python_version()} | torch {torch.__version__}')
if psutil:
    vm = psutil.virtual_memory()
    p(f'RAM: {vm.total / 2**30:.1f} GB en total, {vm.available / 2**30:.1f} GB libres ahora')
if not cpu and not torch.cuda.is_available():
    p('PyTorch NO ve la tarjeta de video: ComfyUI estaria usando el procesador. Hay que reinstalar (install.bat del fork o el portable).')
    open(salida, 'w', encoding='utf-8').write('\n'.join(lineas))
    sys.exit(2)

dev = torch.device('cpu' if cpu else 'cuda')
sync = (lambda: None) if cpu else torch.cuda.synchronize
if not cpu:
    pr = torch.cuda.get_device_properties(0)
    libre, total = torch.cuda.mem_get_info()
    p(f'Tarjeta: {pr.name} | arquitectura {getattr(pr, "gcnArchName", "") or "cuda %d.%d" % (pr.major, pr.minor)}')
    p(f'VRAM: {total / 2**30:.1f} GB en total, {libre / 2**30:.1f} GB libres segun la tarjeta')


def tflops(dtype):
    n, k, m = (512, 1024, 1024) if cpu else (8192, 4096, 4096)   # una capa del modelo sobre ~8000 tokens
    a = torch.randn(n, k, device=dev, dtype=dtype)
    w = torch.randn(k, m, device=dev, dtype=dtype)
    for _ in range(3):
        a @ w
    sync()
    t = time.perf_counter()
    rep = 10
    for _ in range(rep):
        a @ w
    sync()
    return 2 * n * k * m * rep / (time.perf_counter() - t) / 1e12


def copia(pinned):
    mb = 64 if cpu else 512
    x = torch.empty(mb * 2**20 // 4, dtype=torch.float32)
    if pinned:
        x = x.pin_memory()
    if cpu:
        return float('nan')
    x.to(dev, non_blocking=pinned)
    sync()
    t = time.perf_counter()
    for _ in range(3):
        x.to(dev, non_blocking=pinned)
    sync()
    return 3 * mb / 1024 / (time.perf_counter() - t)


r32 = tflops(torch.float32)
p(f'Calculo fp32: {r32:6.2f} TFLOPS')
try:
    p(f'Calculo fp16: {tflops(torch.float16):6.2f} TFLOPS  (solo informativo)')
except Exception as e:
    p(f'Calculo fp16: no se pudo ({e})')
if not cpu:
    c1 = copia(False)
    p(f'Copia RAM -> tarjeta: {c1:5.1f} GB/s (memoria normal)')
    try:
        p(f'Copia RAM -> tarjeta: {copia(True):5.1f} GB/s (memoria fijada)')
    except Exception as e:
        p(f'Copia RAM -> tarjeta (memoria fijada): no se pudo ({e})')

p('')
p('== Que significa ==')
p('Referencia (maximos teoricos en fp32): GTX 1070 6.5 TFLOPS, RX 6600 XT 10.6, RX 6700 XT 13.2, RX 6800 16.2.')
p('Lo normal es medir entre la mitad y un 80 % de ese maximo.')
if not cpu:
    if r32 < 2:
        p('=> La tarjeta calcula MUCHO mas lento de lo normal: el problema es la instalacion de ROCm/PyTorch o el driver,')
        p('   no el editor. Actualiza el driver AMD y vuelve a correr install.bat / comfyui-rocm-updater.bat del fork.')
    else:
        p('=> La tarjeta calcula a buena velocidad. Si las ediciones van lentas, el problema es la memoria: mira durante una')
        p('   edicion el Administrador de tareas > Rendimiento > GPU. Si "Memoria de GPU compartida" sube mas de 1 GB,')
        p('   la VRAM se esta desbordando a la RAM (eso hace todo decenas de veces mas lento).')
    if c1 < 1:
        p('=> Las copias RAM -> tarjeta son muy lentas: conviene que el modelo quepa entero (modo Rapido y resolucion 768 o 512).')
open(salida, 'w', encoding='utf-8').write('\n'.join(lineas))
p('')
p(f'Guardado en {os.path.abspath(salida)}  (mandaselo a quien te ayuda)')
