"""Agrega a ComfyUI-GGUF (city96) la deteccion de Qwen-Image-2.1.

El GGUF de unsloth (qwen-image-2.1-Q8_0.gguf y demas) no trae metadatos de arquitectura, asi que ComfyUI-GGUF intenta
adivinarla por los nombres de los tensores y no conoce Qwen-Image-2.1 ("This model is not currently supported").
Este parche le agrega esa deteccion en tools/convert.py. Es idempotente: si ya esta aplicado no hace nada.

Uso:  python parchear_gguf.py "<ComfyUI>\\custom_nodes\\ComfyUI-GGUF"
"""
import os
import re
import sys

CLASE = '''class ModelQwenImage21(ModelTemplate):
    arch = "qwen_image21"
    keys_detect = [
        ("txt_in.text_norm.weight", "transformer_blocks.0.img_mlp.gate_up.weight")
    ]

'''

ruta = os.path.join(sys.argv[1], "tools", "convert.py")
if not os.path.isfile(ruta):
    sys.exit(f"[ERROR] No existe {ruta}: ComfyUI-GGUF no esta instalado ahi.")
src = open(ruta, encoding="utf-8", newline="").read()
if "ModelQwenImage21" in src:
    print("[ok] ComfyUI-GGUF ya reconoce Qwen-Image-2.1")
    sys.exit(0)

eol = "\r\n" if "\r\n" in src else "\n"   # git en Windows suele dejar CRLF: se respeta el formato del archivo
m = re.search(r"^arch_list = \[(.*?)\]", src, flags=re.S | re.M)
if not m:
    sys.exit("[ERROR] No encontre 'arch_list' en tools/convert.py (cambio el formato de ComfyUI-GGUF). Ver README, seccion 8 (problemas).")
lista = m.group(1).rstrip()
nuevo = src[:m.start()] + CLASE.replace("\n", eol) + "arch_list = [" + lista + "," + eol + "             ModelQwenImage21]" + src[m.end():]
open(ruta, "w", encoding="utf-8", newline="").write(nuevo)
if "ModelQwenImage21]" not in open(ruta, encoding="utf-8").read():
    sys.exit("[ERROR] No se pudo verificar el parche.")
print("[ok] Parche aplicado: ComfyUI-GGUF ahora reconoce Qwen-Image-2.1")
