"""Genera GUIA.html (indice, enlaces clicables, imagenes y boton Copiar) a partir de README.md.

Uso:  python herramientas/generar_guia.py      (necesita: pip install markdown)
Las anclas se generan como en GitHub (con tildes), asi los enlaces internos del README sirven en los dos lados.
"""
import io, os, re
import markdown

RAIZ = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
SRC = os.path.join(RAIZ, "README.md")
DST = os.path.join(RAIZ, "GUIA.html")


def slug_github(texto, sep):
    # igual que GitHub: minusculas, sin puntuacion (las tildes se mantienen), cada espacio pasa a guion
    return re.sub(r"[^\w\- ]", "", texto.strip().lower()).replace(" ", sep)


md = markdown.Markdown(extensions=["tables", "fenced_code", "sane_lists", "toc", "md_in_html"],
                       extension_configs={"toc": {"toc_depth": "2", "slugify": slug_github}})
body = md.convert(io.open(SRC, encoding="utf-8").read())
toc = md.toc
body = re.sub(r'<a href="(https?://[^"]+)"', r'<a href="\1" target="_blank" rel="noopener"', body)
body = body.replace("<img ", '<img loading="lazy" ')

html = """<!DOCTYPE html>
<html lang="es"><head><meta charset="utf-8">
<meta name="viewport" content="width=device-width,initial-scale=1">
<title>Guia del Editor Qwen</title>
<style>
:root{--bg:#fff;--fg:#1c2024;--mut:#5b6670;--line:#d8dee4;--card:#f6f8fa;--acc:#0b6bcb;--code:#eef1f4;--warn:#fff4e5}
@media (prefers-color-scheme:dark){:root{--bg:#0f1115;--fg:#e6e9ee;--mut:#9aa4af;--line:#2a313a;--card:#171b21;--acc:#6cb2ff;--code:#1d232b;--warn:#2a2217}}
*{box-sizing:border-box}
body{margin:0;background:var(--bg);color:var(--fg);font:16px/1.6 system-ui,Segoe UI,Roboto,sans-serif}
main{max-width:940px;margin:0 auto;padding:24px 16px 80px}
h1{font-size:1.9rem;line-height:1.25;margin:.2em 0 .3em}
h2{margin-top:2.2em;padding-top:.6em;border-top:1px solid var(--line);font-size:1.4rem}
h3{margin-top:1.8em;font-size:1.12rem}
a{color:var(--acc);overflow-wrap:anywhere}
code{background:var(--code);padding:.12em .38em;border-radius:5px;font-size:.92em;overflow-wrap:anywhere}
pre{background:var(--code);padding:14px 16px;border-radius:10px;overflow:auto;position:relative;border:1px solid var(--line)}
pre code{background:none;padding:0}
.copy{position:absolute;top:8px;right:8px;font:12px system-ui;background:var(--card);color:var(--fg);border:1px solid var(--line);border-radius:6px;padding:3px 9px;cursor:pointer}
blockquote{margin:1.1em 0;padding:.7em 1.1em;background:var(--warn);border-left:4px solid #e0a030;border-radius:6px}
blockquote p{margin:.3em 0}
table{border-collapse:collapse;width:100%;margin:1em 0;font-size:.94rem;display:block;overflow-x:auto}
th,td{border:1px solid var(--line);padding:7px 10px;text-align:left;vertical-align:top}
th{background:var(--card)}
img{max-width:100%;height:auto;border-radius:8px;border:1px solid var(--line)}
details{background:var(--card);border:1px solid var(--line);border-radius:10px;padding:8px 14px;margin:1em 0}
summary{cursor:pointer;font-weight:600}
.toc ul{margin:.4em 0;padding-left:1.1em}
li{margin:.25em 0}
hr{border:0;border-top:1px solid var(--line);margin:2em 0}
@media print{.copy{display:none}}
</style></head><body><main>
<details open class="toc"><summary>Indice</summary>
""" + toc + """
</details>
""" + body + """
</main>
<script>
document.querySelectorAll('pre').forEach(function(pre){
  var b=document.createElement('button'); b.className='copy'; b.textContent='Copiar';
  b.onclick=function(){ navigator.clipboard.writeText(pre.innerText.replace(/Copiar$/,'').trim()).then(function(){b.textContent='Copiado';setTimeout(function(){b.textContent='Copiar'},1400)}); };
  pre.appendChild(b);
});
</script></body></html>"""
io.open(DST, "w", encoding="utf-8", newline="").write(html)
ids = set(re.findall(r'id="([^"]+)"', html))
rotos = [h for h in re.findall(r'href="#([^"]+)"', html) if h not in ids]
print("GUIA.html:", len(html) // 1024, "KB | enlaces externos:", len(re.findall(r'<a href="https?://', html)),
      "| tablas:", html.count("<table>"), "| imagenes:", html.count("<img "), "| anclas rotas:", rotos or "ninguna")
