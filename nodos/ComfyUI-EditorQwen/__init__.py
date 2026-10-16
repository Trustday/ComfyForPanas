"""ComfyUI-EditorQwen: sirve el editor web tipo chat en http://127.0.0.1:8189/editor-qwen

El editor (editor.html) sube tu imagen, envia la instruccion con el workflow Qwen-Image-2.1 + "Proteger lo que no cambio"
y permite seguir editando el resultado en varias vueltas, con historial. No agrega nodos.
"""
import os

from aiohttp import web
from server import PromptServer

NODE_CLASS_MAPPINGS = {}
NODE_DISPLAY_NAME_MAPPINGS = {}

_HTML = os.path.join(os.path.dirname(__file__), "editor.html")


@PromptServer.instance.routes.get("/editor-qwen")
async def _editor(request):
    return web.FileResponse(_HTML, headers={"Cache-Control": "no-cache"})


print("[ComfyUI-EditorQwen] editor en /editor-qwen")
