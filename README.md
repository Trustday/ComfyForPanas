# ComfyForPanas: editor de imágenes con IA tipo Gemini, en tu PC (NVIDIA o AMD)

**Windows 10/11 · tarjetas NVIDIA (GTX 10 en adelante) y AMD Radeon (RX 6000, 7000 y 9000) · se actualiza con un doble clic en `Actualizar.bat`**

Subes una imagen, escribes lo que quieres cambiar ("ponle una gorra roja", "cámbiale el fondo a una playa") y la IA te devuelve la imagen editada. Puedes seguir editando el resultado las veces que quieras, como en Gemini o Grok, pero **todo corre en tu computador**: no se sube nada a internet.

Usa **Qwen-Image-2.1**, que hoy es el mejor modelo abierto para editar imágenes según el ranking independiente de Artificial Analysis. En nuestras pruebas dio resultados mucho mejores que Flux Kontext, el modelo del paquete anterior. Además, el editor **protege lo que no pediste cambiar**: la cara, el fondo y el resto de la imagen quedan idénticos al original, píxel por píxel.

> **¿Cuánto trabajo es?** Son 3 programas que se instalan con "siguiente, siguiente", una descarga de ComfyUI, un comando para bajar ComfyForPanas y 2 archivos a los que les haces doble clic. Lo más lento es la descarga de los modelos (entre 18 y 34 GB, según lo que elijas). Calcula una tarde.

> **¿Ya lo tienes instalado?** Para recibir arreglos y mejoras haz doble clic en **`Actualizar.bat`** ([sección 11](#11-actualizar)). Si tenías el paquete anterior en zip (`EditorQwen-Paquete`), mira la misma sección.

---

## 1. Qué necesitas

| | Mínimo | Recomendado |
|---|---|---|
| Tarjeta de video | NVIDIA GTX 1070 / RX 6600 con **8 GB** de VRAM | 12 GB o más |
| Memoria RAM | 16 GB | 32 GB |
| Espacio libre en disco | 40 GB | 40 GB en un **SSD** (los modelos cargan mucho más rápido) |
| Sistema | Windows 10 u 11 de 64 bits | |
| Internet | Para la instalación y la descarga de modelos | Después funciona sin internet |

**¿Cómo sé qué tarjeta y cuánta VRAM tengo?** Presiona `Ctrl + Shift + Esc` (Administrador de tareas) → pestaña **Rendimiento** → **GPU**. Arriba a la derecha sale el nombre de la tarjeta, y abajo, **"Memoria de GPU dedicada"** (esa es la VRAM). La RAM aparece en **Memoria**.

Después sigue **solo la sección de tu marca**: [NVIDIA (sección 3)](#3-instalación-con-tarjeta-nvidia) o [AMD (sección 4)](#4-instalación-con-tarjeta-amd-radeon).

---

## 2. Qué está probado y qué no (léelo)

| Parte | Estado |
|---|---|
| Editor, protección y modelos (Qwen-Image-2.1 Q8_0) | **Probados a fondo** en una NVIDIA GTX 1070 de 8 GB con 32 GB de RAM: ropa, fondo, pose, expresión, accesorios, pelo y ediciones en varias vueltas. |
| Scripts del paquete (instalar, descargar modelos, lanzador) | **Probados en una instalación limpia** del ComfyUI portable oficial para NVIDIA (versión 0.40.0, variante `cu126`): instalan todo, ComfyUI arranca, reconoce los nodos y los modelos, y el editor se abre. En esa instalación limpia **no se generaron imágenes**; la generación se probó en la instalación principal (mismos nodos y modelos, ComfyUI 0.41). De `3-Probar-Edicion` se probó la comprobación (conexión, nodos, modelos y subida de la imagen); la edición de prueba en sí no se ejecutó. |
| Codificador de texto "int8" (para PCs con 16 GB de RAM y tarjetas AMD) | **Probado**: el resultado es prácticamente idéntico al normal (diferencia media de 0.26 sobre 255). |
| **Modo Rápido (Turbo, 8 pasos)** | Usa el modelo y el muestreo de la **plantilla oficial** de ComfyUI para Qwen-Image-2.1 Turbo. En una prueba (una sonrisa) salió **prácticamente igual** que el modo Calidad. Su velocidad todavía no la medí. Si un resultado no te convence, repítelo en Calidad. |
| **Cambio grande** (pose o escena nueva) | **Probado en el editor** (GTX 1070, 1024): "en un bosque nevado con abrigo y un farol" y "sentada en una taberna con una jarra" cambiaron pose, escena y objetos, y mantuvieron cara, pelo y ropa. Tarda lo mismo que una edición normal. |
| **Varias imágenes** (＋ Imagen) | **Copiar la ropa: probado** (GTX 1070, modo Rápido, 768, con dos imágenes): la instrucción del botón **👕 Su ropa**, que nombra las prendas, **copió el uniforme completo sin texto extra** (chaqueta, top, cinturón y pantalón) y mantuvo cara, pelo, pose y fondo. Le quedó una franja roja del short original en el pantalón, que en la otra imagen es blanco liso. Tarda 11.3 s por paso: unos 2 min 30 s con los modelos ya cargados y casi 3 min la primera vez. **Juntar personajes: funcionó describiendo a cada uno** (768): con dos parejas distintas, abrazados y caminando de la mano salieron bien a la primera, en modo Rápido (unos 2 min 40 s) y en Calidad (25 pasos, unos 5 min 30 s). Cada uno mantuvo su cara, pelo, ojos y ropa, y quedó el fondo de ①. **Sin describirlos falló** (modo Rápido, 2 semillas, otro par de imágenes): Qwen dejó solo al personaje de ②, en su misma pose, y el tuyo desapareció. **La diferencia de altura entre personajes no es confiable:** pedida en la instrucción, Qwen la exageró o la ignoró; con una segunda edición, achicar a uno lo hizo verse más joven (proporciones de niño) y agrandar al otro no cambió nada. Con 3 o más imágenes: sin probar. **La pose de otra imagen no se copia**: probé 4 formas (modo Rápido y Calidad, las imágenes en los dos órdenes, y la pose descrita con palabras): o dejaba al personaje en su pose, o lo cambiaba por la persona de la otra imagen. |
| **LoRAs y ajustes de muestreo** (CFG, sampler) | **Probado que el editor los aplica:** CFG 3 con `er_sde` + `beta` funcionó y cada paso tardó el doble (9.3 s contra 4.7 s, a 512). **Con un LoRA hecho para Qwen 2.1 todavía no se probó.** Uno de SD 1.5 no hizo nada, como se espera. El nodo GGUF dice que los LoRAs funcionan "de forma experimental": prueba cada LoRA con la misma semilla, con y sin él. |
| NVIDIA RTX (serie 16, 20, 30, 40, 50) | **No probado por mí** (no tengo esas tarjetas). Usa el ComfyUI portable oficial y los mismos scripts; debería funcionar y ser bastante más rápido. |
| **AMD Radeon** | **Funciona** en una RX 6700 XT y en una RX 6600 XT (pruebas de usuarios con `comfyui-rocm`), pero **muy lento** en modo Calidad a 1024: 35 s por paso en la 6700 XT y 209 s por paso en la 6600 XT. Una edición además salió dañada. La causa es que **el modelo no cabe en la VRAM**: se copia desde la RAM en cada paso, y con 16 GB de RAM incluso desde el disco. Este paquete trae arreglos que **todavía no se probaron en una Radeon**: modo Rápido con un modelo Turbo más chico que cabe en la tarjeta, resolución 768, codificador int8, VAE en precisión completa (`--fp32-vae`) y una caché que libera RAM. Si ya lo tenías instalado, usa `4-Arreglo-AMD.bat` (sección 11). |

**Tiempos medidos en modo Calidad (GTX 1070, 8 GB):** unos **9 a 10 minutos por edición** a 1024 y unos **3 a 4 minutos** a 512. El modo Rápido debería tardar cerca de un tercio en la parte de dibujo (sin medir). El editor te muestra los segundos por paso y el tiempo restante mientras trabaja.

---

## 3. Instalación con tarjeta NVIDIA

### Paso 1 · Instala 3 programas (una sola vez)

1. **Git**: <https://git-scm.com/download/win>. Instálalo con todas las opciones por defecto (siguiente, siguiente…).
2. **7-Zip**: <https://www.7-zip.org/>. Sirve para descomprimir archivos `.7z`.
3. **Driver de NVIDIA actualizado**: <https://www.nvidia.com/es-la/drivers/> (o la app de NVIDIA). Si tu driver es viejo, ComfyUI no arranca.

### Paso 2 · Descarga ComfyUI (la versión "portable" oficial)

"Portable" quiere decir que no se instala: se descomprime y se usa. Elige **uno** según tu tarjeta:

| Tu tarjeta | Descarga |
|---|---|
| **RTX 20, 30, 40, 50 o GTX 16** (casi todas las actuales) | <https://github.com/comfyanonymous/ComfyUI/releases/latest/download/ComfyUI_windows_portable_nvidia.7z> |
| **GTX 10** (1050, 1060, 1070, 1080) o más antigua | <https://github.com/comfyanonymous/ComfyUI/releases/latest/download/ComfyUI_windows_portable_nvidia_cu126.7z> |

1. Crea una carpeta con un nombre corto, por ejemplo `C:\IA`. **Sin tildes ni ñ**, y que no esté dentro de "Archivos de programa".
2. Clic derecho en el archivo descargado → **7-Zip → Extraer aquí** (o "Extraer en…" y eliges `C:\IA`).
3. Te queda la carpeta **`C:\IA\ComfyUI_windows_portable`**. Esa es tu carpeta de ComfyUI.

### Paso 3 · Baja ComfyForPanas

1. Abre la carpeta `C:\IA` en el Explorador de archivos.
2. Haz clic en la **barra de direcciones** (arriba, donde dice `C:\IA`), escribe `cmd` y presiona Enter. Se abre una ventana negra que ya está en esa carpeta.
3. Copia esta línea, pégala en la ventana negra (clic derecho pega) y presiona Enter:

   ```
   git clone https://github.com/Trustday/ComfyForPanas
   ```

4. Te queda la carpeta **`C:\IA\ComfyForPanas`**. Ya puedes cerrar la ventana negra.

> **Otra forma, sin comandos:** en <https://github.com/Trustday/ComfyForPanas>, botón verde **Code → Download ZIP**. Antes de descomprimirlo: clic derecho en el zip → **Propiedades** → marca **Desbloquear** → Aceptar (así Windows no bloquea los scripts). `Actualizar.bat` funciona igual: la primera vez convierte la carpeta en una copia clonada.

### Paso 4 · Instala el editor

1. Abre `ComfyForPanas\scripts` y haz doble clic en **`1-Instalar-Nodos.bat`**.
2. Te pide la carpeta de ComfyUI: **arrastra la carpeta `ComfyUI_windows_portable` a la ventana negra** y presiona Enter.
3. Te pregunta cuántos GB de VRAM tiene tu tarjeta: escribe el número (ej. `12`) y Enter.
4. Espera a que todas las líneas digan `[ok]` y presiona una tecla para cerrar.

> Si Windows muestra "Windows protegió su PC", haz clic en **Más información → Ejecutar de todas formas**. Son scripts de texto que puedes abrir con el Bloc de notas para ver qué hacen.

### Paso 5 · Descarga los modelos (18 a 34 GB)

1. Doble clic en **`2-Descargar-Modelos.bat`**.
2. Arrastra otra vez la carpeta `ComfyUI_windows_portable` y presiona Enter.
3. Te pregunta dónde guardar los modelos: **presiona Enter** para guardarlos dentro de ComfyUI. Si tienes un **SSD** con espacio y ComfyUI quedó en un disco duro normal, mejor arrastra una carpeta del SSD (los modelos cargarán mucho más rápido).
4. Te pregunta si quieres el **modo Rápido (Turbo)**: presiona **Enter** para bajarlo (son 7.6 GB más, y edita unas 3 veces más rápido), o escribe `N` si no lo quieres.
5. Espera. Si se corta internet o algo sale en rojo, **vuelve a ejecutarlo**: la descarga sigue donde quedó.

El script elige solo la versión del codificador de texto: 17.5 GB si tienes 32 GB de RAM y una NVIDIA, o la versión "int8" de 9.4 GB (mismo resultado, carga más rápido) si tienes 16 GB de RAM o una tarjeta AMD.

### Paso 6 · ¡Úsalo!

Doble clic en **`C:\IA\ComfyUI_windows_portable\Abrir-Editor-Qwen.bat`** (lo creó el paso 4).

- Se abre una ventana negra llamada **"ComfyUI - Editor Qwen (no cerrar)"**. **No la cierres** mientras uses el editor.
- Cuando ComfyUI termina de arrancar, el editor se abre solo en tu navegador.
- Para tenerlo a mano: clic derecho en `Abrir-Editor-Qwen.bat` → **Enviar a → Escritorio (crear acceso directo)**.

Cómo se usa: [sección 5](#5-cómo-usar-el-editor).

### Paso 7 (opcional) · Prueba que todo funciona

Con el editor ya abierto, doble clic en **`3-Probar-Edicion.bat`**, arrastra la carpeta de ComfyUI y después una imagen tuya de una persona o personaje con el pelo visible. Hace una edición de prueba ("pelo rojo", en modo Calidad a resolución 512), te dice cuánto tardó y si funcionó. El resultado queda en `ComfyForPanas\referencia\resultado_prueba.png`.

---

## 4. Instalación con tarjeta AMD Radeon

El ComfyUI oficial todavía no cubre bien a todas las Radeon en Windows (las RX 6000 quedan fuera del portable oficial). Por eso se usa **`comfyui-rocm`**, una versión de la comunidad con instalador automático que soporta RX 6000, 7000 y 9000. Es la misma del paquete anterior.

> **¿Ya instalaste el paquete anterior (Editor-Kontext)?** Entonces ya tienes `comfyui-rocm`. Solo haz doble clic en **`comfyui-rocm-updater.bat`** (dentro de tu carpeta `comfyui-rocm`) para actualizarlo, y salta al **Paso 4**.

### Paso 1 · Instala estos programas (una sola vez)

1. **Git**: <https://git-scm.com/download/win>. Opciones por defecto.
2. **Visual C++ Runtime**: <https://aka.ms/vs/17/release/vc_redist.x64.exe>
3. **Visual Studio Build Tools**: <https://aka.ms/vs/17/release/vs_BuildTools.exe>. En el instalador marca **"Desarrollo para el escritorio con C++"** e instala (pesa varios GB).
4. **Driver AMD Adrenalin actualizado**: <https://www.amd.com/es/support/download/drivers.html>
5. Si tu procesador tiene **gráficos integrados** (muchos Ryzen terminados en G y los Ryzen 7000/9000), lo ideal es desactivarlos en la BIOS. Si no sabes cómo, sigue igual y mira la [sección 8](#8-problemas-y-soluciones) si aparece un error "HIP".

### Paso 2 · Instala comfyui-rocm

1. Entra a <https://github.com/patientx-cfz/comfyui-rocm/releases>, abre la versión más reciente y baja **"Source code (zip)"**.
2. Descomprímelo en la **raíz de un disco** y cambia el nombre de la carpeta a **`comfyui-rocm`** (ej. `C:\comfyui-rocm`). Sin tildes ni ñ, y no dentro de tu carpeta de usuario.
3. Doble clic en **`install.bat`**. Descarga Python y PyTorch para tu Radeon; tarda un buen rato.
4. Al terminar, doble clic una vez en **`comfyui-rocm-updater.bat`**.

### Paso 3 · Baja ComfyForPanas

Igual que en NVIDIA ([sección 3, paso 3](#paso-3--baja-comfyforpanas)): abre la raíz del disco (ej. `C:\`) en el Explorador, escribe `cmd` en la barra de direcciones, Enter, y pega:

```
git clone https://github.com/Trustday/ComfyForPanas
```

Te queda `C:\ComfyForPanas`. (Sin comandos: **Code → Download ZIP** en la página del repositorio, y **Desbloquear** el zip antes de descomprimirlo.)

### Paso 4 · Instala el editor

Doble clic en **`ComfyForPanas\scripts\1-Instalar-Nodos.bat`**, **arrastra la carpeta `comfyui-rocm`** a la ventana, Enter, y escribe los GB de VRAM de tu tarjeta (ej. `12` para una RX 6700 XT, `16` para una RX 6800/7800 XT).

En AMD, este paso además ajusta tu `comfyui-user.bat`:

- agrega la vista previa en vivo y un par de ajustes de memoria;
- pone el VAE en precisión completa (`--fp32-vae`), lo que evita imágenes negras o con ruido;
- quita `--cache-lru 20` del lanzador del fork, que mantiene los modelos ocupando la RAM. Sin esa opción, ComfyUI usa su caché normal y libera RAM cuando falta, algo clave con 16 GB.

### Paso 5 · Descarga los modelos

En AMD conviene usar **`4-Arreglo-AMD.bat`** en vez de `2-Descargar-Modelos.bat`: arrastra la carpeta `comfyui-rocm`, escribe los GB de VRAM y Enter. Hace dos cosas:

- **Baja los modelos con el tamaño justo para Radeon.** El modo Rápido va con un Turbo de 4.2 GB en tarjetas de hasta 12 GB, para que quepa entero en la VRAM, y el codificador de texto va en "int8".
- **Repite los ajustes del paso 4.**

Al terminar te dice cómo comprobar en la ventana de ComfyUI que el modelo cupo.

### Paso 6 · ¡Úsalo!

Doble clic en **`C:\comfyui-rocm\Abrir-Editor-Qwen.bat`**. Abre ComfyUI (con tu `comfyui-user.bat`) en una ventana que **no debes cerrar**, y luego el editor en el navegador.

> **La primera edición en una Radeon puede tardar mucho más** (varios minutos sin avance), porque la tarjeta prepara sus "cachés". Las siguientes son más rápidas. Después puedes usar `3-Probar-Edicion.bat` igual que en NVIDIA.

<details markdown="1"><summary>Plan B para AMD: ComfyUI oficial con ROCm 10 (solo Windows 11, más manual)</summary>

El README oficial de ComfyUI ya explica cómo usar las Radeon RX 6000 a 9000 en **Windows 11** con PyTorch de AMD (ROCm 10). Es una instalación manual con Python 3.13 (`git clone` de ComfyUI, un entorno de Python y un comando `pip`): <https://github.com/comfyanonymous/ComfyUI#amd-gpus-windows-rocm-100>. Los scripts de este paquete también funcionan con esa instalación si creas el entorno en una carpeta `venv` dentro de ComfyUI. No lo probé.
</details>

---

## 5. Cómo usar el editor

1. **Sube una imagen**: clic en el recuadro, arrástrala a la ventana o pégala con `Ctrl + V`.
2. **Escribe el cambio en inglés** y presiona Enter (o **Enviar**). Abajo del cuadro ves la frase exacta que se envía; el editor le agrega solo *"Keep everything else unchanged."* si tú no lo escribes.
3. **Espera**: verás la imagen formándose en vivo, el paso actual y el tiempo restante. El botón **⏹ Detener** cancela.
4. **El resultado pasa a ser la imagen que estás editando**: escribe otro cambio y se aplica sobre él. Así encadenas ediciones.

**⚡ Rápido / Calidad** (junto al botón Enviar):

- **Rápido** usa el modelo Turbo con 8 pasos y tarda unas 3 veces menos en dibujar. Úsalo para probar ideas y encadenar cambios.
- **Calidad** usa el modelo normal con 25 pasos. Úsalo para la versión final, o si un resultado en Rápido no te convenció.
- El editor parte en Rápido si bajaste el modelo Turbo. Cada resultado indica con qué modo se hizo.

**Cambio grande** (botón junto al cuadro de texto, se pone amarillo al activarlo): para **pose o escena nueva**, por ejemplo "sentada en una taberna con una jarra". Ahí cambia casi toda la imagen, así que la protección no sirve y podría dejar pedazos de la imagen anterior. Con el botón activo se usa la imagen completa de Qwen. Si escribes un pedido sin "keep", se le agrega *"Keep the same character and art style."* en vez de *"Keep everything else unchanged."*. **Apágalo para retoques** (ropa, gestos, accesorios): ahí la protección deja la cara y el fondo idénticos. Queda activo hasta que lo apagues o cierres el editor.

En cada resultado tienes:

| Botón | Para qué |
|---|---|
| **⇆ Comparar** | Antes/después con una barra que arrastras. |
| **⬇ Descargar** | Guarda la imagen. (Igual quedan todas en la carpeta de ComfyUI: `output\EditorQwen`). |
| **↻ Otra variante** | Repite el mismo pedido con otra "semilla": sale distinto. Úsalo si no te gustó. |
| **↳ Seguir desde aquí** | Vuelve a una versión anterior y sigue desde ella. También puedes usar las miniaturas de abajo. |
| **Usar sin proteger** | Si la protección dejó algo raro (una mezcla extraña), toma la imagen tal como la hizo Qwen. |

La conversación queda guardada aunque cierres el navegador. **＋ Nueva** empieza con otra imagen.

### Usar otras imágenes (＋ Imagen)

Además de la imagen de tu personaje, Qwen puede recibir **hasta 4 imágenes más** y usarlas como diga la instrucción: juntar a tu personaje con otro, ponerle la ropa de otra imagen, darle un objeto, etc.

1. Sube primero la imagen de **tu personaje**, como siempre. Es la que se edita.
2. Clic en **＋ Imagen** (junto al cuadro de texto) y elige una o varias imágenes. También puedes soltarlas sobre ese botón.
3. Sobre el cuadro de texto aparecen todas, numeradas:
   - **① Personaje (base)**: la imagen que se edita. De ella salen el tamaño del resultado, el estilo y el fondo.
   - **②, ③…**: las demás. Si sueltas una imagen sobre un recuadro, la cambia; **✕** la quita (las siguientes bajan un número).
4. Escribe la instrucción en inglés **nombrando las imágenes** `<image1>`, `<image2>`… Al tocar el número de un recuadro, el editor lo escribe por ti. También puedes poner "image 2" o "imagen 2": el editor lo cambia a `<image2>`.
5. Presiona **Enviar**. Bajo el cuadro de texto ves la instrucción completa y algunos avisos, por ejemplo si una imagen no se nombra.

**👕 Su ropa** (botón en cada recuadro): escribe la instrucción para vestir a ① con la ropa completa de esa imagen, prenda por prenda, y apaga **Cambio grande** para que la cara y el fondo queden idénticos. Puedes cambiarla antes de enviar.

Para todo lo demás escribes tu propia instrucción, describiendo a cada personaje. Por ejemplo: `The woman with long red hair and green eyes, wearing a white dress, from <image1> and the man with short blond hair, wearing a blue jacket, from <image2> are sitting together on a park bench, talking`

Ten en cuenta:

- **Para juntar personajes, describe a cada uno.** Nombra lo que los distingue (piel, pelo, ojos, ropa) junto a su `<imageN>`, como en el ejemplo. Así salieron bien en las pruebas, en modo Rápido y en Calidad. Sin describirlos, Qwen cambió a tu personaje por el de ② (ver la tabla de la sección 2).
- **Para juntar personajes o cambiar la pose, usa Cambio grande.** Con la protección activa solo se toma de Qwen la zona que cambió: sirve para ropa u objetos, pero si cambia toda la escena deja pedazos de la imagen anterior.
- **Si no escribes "keep"**, el editor agrega al final que conserve a cada personaje. Con Cambio grande: *"Keep each character's face, hair, eye color and body proportions exactly as in their own image, and the art style of <image1>."* Sin él: que conserve la cara, el pelo, el estilo y el fondo de ①.
- **La pose de otra imagen no se copia** (ver la tabla de la sección 2): con la foto de una pose, Qwen deja a tu personaje como estaba o lo cambia por la persona de esa imagen. La pose se pide con palabras.
- **Las imágenes se quedan puestas** para los pedidos siguientes, hasta que las quites con **✕**.
- **↻ Otra variante** repite el pedido con las mismas imágenes, la misma instrucción y la misma protección.
- **Ropa:** el botón **👕 Su ropa** nombra las prendas (top, chaqueta, pantalón o falda, cinturón y zapatos), porque con solo "the same outfit" Qwen copió la chaqueta y dejó el short. **Si aun así falta una prenda o se cuela un detalle de la ropa vieja, nómbralo en el texto**, por ejemplo *"Also replace her black shorts with the plain white pants and black belt"*.
- **Cada imagen extra hace más lento cada paso**: con dos imágenes, en una GTX 1070, 11.3 s por paso en modo Rápido a 768. Con tres o más no lo he medido.

**Opciones (⚙):**

| Opción | Qué hace |
|---|---|
| **Resolución** | **1024** = lo recomendado. **768** = cerca de la mitad del tiempo, con un poco menos de detalle (buena opción en tarjetas lentas). **512** = para probar ideas; pierde detalle (en caras pequeñas los gestos pueden no notarse). |
| **Pasos** | Solo para el modo Calidad: 25 es lo recomendado. El modo Rápido usa siempre 8. |
| **Semilla** | Vacía = al azar. Si pones un número, el mismo pedido da siempre el mismo resultado. |
| **Umbral de protección** | 20 es lo probado. Más alto = se toma de Qwen una zona más chica. |
| **LoRAs** | Hasta dos, con su fuerza (1 = normal). Ver [LoRAs (opcional)](#loras-opcional). |
| **CFG** | Solo modo Calidad. 1 es lo probado. Algunos LoRAs piden 3–6: con CFG mayor que 1 **cada paso tarda casi el doble** y se usa el prompt negativo. |
| **Prompt negativo** | Lo que no quieres que aparezca (en inglés). Solo se usa con CFG mayor que 1. |
| **Sampler / Scheduler** | Solo modo Calidad. Lo probado es `euler` + `simple`; cámbialos solo si un LoRA lo pide. **Muestreo probado** vuelve a CFG 1, euler y simple. |

Bajo el cuadro de texto ves lo que va a cambiar el resultado o el tiempo: Cambio grande, los LoRAs activos y el CFG.

### Cómo pedir las cosas (en inglés)

¿No te manejas con el inglés? Escribe en Google Translate y pega la traducción. Funciona mejor **un cambio por vez**; después encadenas.

| Quieres… | Escribe, por ejemplo |
|---|---|
| Cambiar la ropa | `Change her outfit to a plain white t-shirt and blue jeans` |
| Cambiar el fondo | `Change the background to a sandy beach at sunset` |
| Una pose | `Make her cross her arms over her chest` |
| Una expresión | `Make her smile happily` · `Make her look surprised` |
| Un accesorio | `Put a red baseball cap on her head` · `Put black sunglasses on her` |
| El pelo | `Change her hair color to red` · `Make her hair long` |
| Una escena nueva (con **Cambio grande**) | `Show the same woman sitting at a wooden table in a fantasy tavern at night, holding a large beer mug with both hands, laughing. Full body. Keep her face, hair and outfit exactly the same.` |

**Consejos:**

- **Sé concreto:** color, tipo de prenda y detalles. "A traditional red kimono with wide sleeves" sale mejor que "kimono".
- **Di dónde va un accesorio:** "a thin silver necklace **over her shirt collar**". Si no, puede que cambie la ropa para mostrarlo.
- **Para ropa nueva usa "Change her outfit to…"**, que reemplaza. Con "add…" la pone encima.
- **Si un resultado no te gusta, prueba ↻ Otra variante** antes de reescribir el pedido.
- **Para copiar una ropa que ya tienes en otra imagen o juntar a tu personaje con otro**, usa [＋ Imagen](#usar-otras-imágenes--imagen) en vez de describirlos. Las poses, en cambio, se piden con palabras.

### Proteger lo que no cambió (activo salvo con Cambio grande)

Qwen redibuja toda la imagen, así que la cara o el fondo pueden moverse un poquito aunque no lo pidas. El editor compara el resultado con tu imagen, detecta **solo la zona que de verdad cambió** y pega esa zona sobre tu original, con el borde suavizado. Todo lo demás queda **idéntico**, y el resultado sale del mismo tamaño que tu imagen. En gestos y accesorios toma también los alrededores del cambio, para que la cara quede coherente. En cada resultado ves qué porcentaje de la imagen se tomó de Qwen ("zona editada").

En nuestras pruebas (ropa, fondo, pose, expresión y accesorios), fuera de la zona editada la imagen quedó prácticamente igual al original: una diferencia media de 0.1 sobre 255 o menos. Sin la protección, la cara y el fondo se movían entre 5 y 7.

### LoRAs (opcional)

Un **LoRA** es un archivo chico (de 50 a 300 MB) que le enseña algo extra al modelo, como un estilo o un tipo de imagen, sin reemplazarlo.

1. Copia el archivo `.safetensors` a la carpeta **`models\loras`** de tu ComfyUI (ej. `C:\IA\ComfyUI_windows_portable\ComfyUI\models\loras`). Puedes usar subcarpetas.
2. En el editor, **⚙ Opciones → LoRAs**: elígelo y ajusta la fuerza. La lista se actualiza sola en unos segundos.
3. Si el autor del LoRA recomienda CFG, sampler o scheduler, ponlos en **Muestreo** y usa el modo **Calidad**. El modo Rápido usa siempre su receta fija.

Ten en cuenta:

- **Solo sirven LoRAs hechos para Qwen-Image 2.1.** Los de SD 1.5, SDXL/Illustrious, Qwen-Image antiguo o Qwen-Image-Edit 2509/2511 no dan error: simplemente no hacen nada.
- **Compruébalo:** fija una semilla en Opciones y haz el mismo pedido con y sin el LoRA. Si salen iguales, el LoRA no está actuando.
- Con el modo Rápido (Turbo) un LoRA puede funcionar distinto o no funcionar, porque se entrenan sobre el modelo normal.
- Cada resultado indica qué LoRAs y qué CFG se usaron.

---

## 6. Qué esperar según tu tarjeta

| VRAM | Funciona | Tiempo por edición (1024, modo Calidad) |
|---|---|---|
| 8 GB (GTX 1070, RTX 3060 Ti/3070, RX 6600) | Sí. Parte del modelo queda en la RAM. | ≈ 9–10 min en la GTX 1070 (**medido**); una RTX 3070 debería ser bastante más rápida |
| 12 GB (RTX 3060 12 GB, RTX 4070, RX 6700 XT) | Sí | RX 6700 XT: ≈ 18 min (35 s por paso), **medido por un usuario antes de los ajustes de AMD de este paquete**; RTX sin medir |
| 16 GB o más (RTX 4080/5080, RX 6800/7800 XT o superior) | Sí, el modelo cabe entero | sin medir |
| 6 GB o menos | Quizás, con un modelo más chico (`-Cuantizacion Q5_K_M`, ver sección 8) y resolución 768 o 512 | sin probar |

**El modo Rápido** debería reducir la parte de dibujo a cerca de un tercio (8 pasos en vez de 25). **La resolución 768** la reduce aproximadamente a la mitad. Se pueden combinar.

Siempre: **la primera edición de cada sesión tarda más**, porque carga los modelos. La versión "int8" del codificador de texto (la que se baja con 16 GB de RAM o con AMD) da el mismo resultado.

---

## 7. Extra: usarlo dentro de ComfyUI

Si te interesa ver el "motor": con ComfyUI abierto, entra a <http://127.0.0.1:8188>, menú **Workflows → Qwen21-Editar-GGUF**. Ahí está el mismo proceso en nodos, con una nota de uso. Eliges la imagen, escribes la instrucción y presionas **Ejecutar**.

**Workflows → Qwen21-Ropa-Referencia** es lo mismo que **＋ Imagen** con el botón **👕 Su ropa**: dos nodos de imagen, **1 · Personaje (base)** y **2 · Referencia (ropa)**, una instrucción que los nombra `<image1>` y `<image2>`, y la misma protección del workflow de una imagen.

**Workflows → Qwen21-Varias-Imagenes** trae tres nodos de imagen (`<image1>` a `<image3>`) y ningún nodo de protección, como **Cambio grande**. La instrucción de ejemplo trae huecos `[ ]` para describir a cada personaje y lo que hacen juntos. Para usar más imágenes, conecta otro **Load Image** al siguiente hueco `images.image_N` del nodo de texto.

---

## 8. Problemas y soluciones

| Lo que pasa | Qué hacer |
|---|---|
| El editor dice **"ComfyUI no responde"** | La ventana negra de ComfyUI se cerró o todavía está cargando. Vuelve a abrir `Abrir-Editor-Qwen.bat` y espera. |
| El editor dice **"Faltan nodos"** o **"Falta: …"** | Faltan nodos → vuelve a correr `1-Instalar-Nodos.bat` y reinicia ComfyUI (cierra la ventana negra y abre `Abrir-Editor-Qwen.bat`). Faltan modelos → corre `2-Descargar-Modelos.bat`. |
| `1-Instalar-Nodos` dice **"Tu ComfyUI es 0.xx y necesita 0.37"** | NVIDIA: baja de nuevo el portable (paso 2) o ejecuta `update\update_comfyui.bat`. AMD: ejecuta `comfyui-rocm-updater.bat`. |
| **"Falta Git"** | Instala Git (paso 1), cierra la ventana y vuelve a intentar. |
| Windows dice **"Windows protegió su PC"** | **Más información → Ejecutar de todas formas.** Si bajaste el zip, para que no vuelva a salir: desbloquéalo antes de descomprimirlo (paso 3). Con `git clone` no pasa. |
| `Actualizar.bat` dice que **archivos de ComfyForPanas se modificaron en este PC** | Alguien editó un archivo del paquete (por ejemplo, abrió un `.bat` con el Bloc de notas y guardó). Escribe `S` para volver a la versión oficial y seguir, o Enter para cancelar sin tocar nada. Tus imágenes y tus modelos no se tocan. |
| `Actualizar.bat` dice **"No pude bajar los cambios"** | Revisa internet y vuelve a intentar. Si sigue: borra la carpeta `ComfyForPanas` y bájala de nuevo (paso 3); después corre `Actualizar.bat`, que te pide la carpeta de ComfyUI una vez. |
| ComfyUI **no arranca** (NVIDIA) y la ventana menciona CUDA o driver | Actualiza el driver de NVIDIA. Si tu tarjeta es GTX 10 o más antigua, necesitas el portable **`cu126`** (paso 2). |
| **Muy lento**, o algunos pasos tardan 5 a 10 veces más que otros | VRAM justa. Cierra programas que usen la tarjeta (juegos, Wallpaper Engine, grabadores, otras pestañas con video). Si sigue, vuelve a correr `1-Instalar-Nodos.bat` e indica **menos** VRAM de la que tienes, para que reserve más. |
| Error **"out of memory"** / se queda sin memoria | Baja la resolución a 768 o 512 en Opciones. Si no basta, usa un modelo más chico: abre PowerShell en la carpeta `scripts` y ejecuta `.\Descargar-Modelos.ps1 -Ruta "C:\IA\ComfyUI_windows_portable" -Cuantizacion Q6_K` (o `Q5_K_M`). Después borra el `qwen-image-2.1-Q8_0.gguf` para que el editor use el nuevo. |
| Con **16 GB de RAM** el PC se pone muy lento | Asegúrate de usar el codificador `int8` (el script lo elige solo con menos de 31 GB de RAM). Cierra el navegador con muchas pestañas y otros programas pesados. |
| **El resultado salió casi igual** | El pedido era muy vago, o la resolución 512 no alcanzó para un gesto pequeño. Usa 1024, sé más concreto o prueba ↻ Otra variante. |
| **El resultado tiene una mezcla rara** (por ejemplo, media cara cambiada) | Usa **"Usar sin proteger"** en ese resultado, o súbele el umbral de protección en Opciones. |
| En la ventana de ComfyUI sale **"This model is not currently supported"** | El parche de ComfyUI-GGUF no quedó aplicado. Vuelve a correr `1-Instalar-Nodos.bat` y reinicia ComfyUI. Si actualizaste ComfyUI-GGUF por tu cuenta, repítelo. |
| **AMD:** error `HIP error: invalid kernel file` | Está usando los gráficos integrados del procesador. Desactívalos en la BIOS, o abre `comfyui-user.bat` con el Bloc de notas, busca la línea `:: set HIP_VISIBLE_DEVICES=1` y bórrale los `::` del comienzo (si no está, agrega `set HIP_VISIBLE_DEVICES=1` justo debajo de la línea `set "PARAMS=...` que agregó el paquete). |
| **AMD:** la primera edición tarda muchísimo | Es normal en Radeon: la tarjeta prepara sus cachés. Las siguientes son más rápidas. |
| **AMD: todas las ediciones son lentas** (más de 30 s por paso, mirando el paso 2 o 3; el 1 incluye preparar la tarjeta) | 1) Corre **`4-Arreglo-AMD.bat`**: baja un modelo Rápido de 4.2 GB que cabe en la tarjeta, ajusta la RAM y deja más VRAM libre para que no se desborde. 2) Usa el modo **⚡ Rápido** y la resolución **768** (o 512 para probar). 3) Cierra otros programas que usen la tarjeta o mucha RAM. 4) Si sigue lento: cierra ComfyUI y corre **`5-Diagnostico.bat`**, que mide la tarjeta. Además, durante una edición mira en el Administrador de tareas → Rendimiento → GPU la **"Memoria de GPU compartida"**: si sube más de 1 GB, la VRAM se está desbordando a la RAM. Manda a quien te ayude `referencia\diagnostico.txt`, esa captura, la línea `loaded ...` y los segundos por paso. |
| **AMD:** imágenes negras o con ruido, o el editor dice **"valores inválidos (NaN)"** | El mensaje dice en qué parte falló y qué hacer. Lo más común es el VAE en media precisión. Pasos: 1) **Abre ComfyUI siempre con `Abrir-Editor-Qwen.bat`**, no con `comfyui-rocm.bat`, para que arranque con `--fp32-vae`. 2) En las primeras líneas de la ventana negra, la que empieza con `starting with: [` debe incluir `fp32-vae`; si no, corre `4-Arreglo-AMD.bat`. 3) Si el error dice que falló **al dibujar**, prueba el otro modo (Rápido o Calidad); si solo falla uno, vuelve a bajar ese modelo. |
| **AMD:** la **primera** edición sale bien y **las siguientes** dan "valores inválidos (NaN)" | Es un error conocido de la memoria dinámica de ComfyUI en Radeon: un modelo que queda cargado en la tarjeta entre ediciones a veces se daña. Corre **`Actualizar.bat`** y reinicia ComfyUI: ahora el editor descarga los modelos de la tarjeta entre ediciones (cada una parte como la primera) y, si el VAE igual devuelve NaN, vuelve a decodificar en vez de perder la edición. Si aun así sale el error, cierra la ventana negra, abre de nuevo `Abrir-Editor-Qwen.bat` y manda la ventana completa a quien te ayuda. |
| **AMD:** cualquier otro error al instalar comfyui-rocm | Revisa la guía del propio proyecto: <https://github.com/patientx-cfz/comfyui-rocm> (y su `install.bat --debug`). |

Si pides ayuda a alguien, mándale **lo que dice la ventana negra de ComfyUI** (las últimas líneas) y lo que dijo `3-Probar-Edicion.bat`.

---

## 9. Qué trae ComfyForPanas

```
ComfyForPanas\
├─ README.md / GUIA.html          esta guía (GUIA.html se abre en el navegador, con enlaces clicables)
├─ Actualizar.bat                 baja la última versión y la instala en tu ComfyUI (NVIDIA y AMD)
├─ LEEME-ARREGLO-AMD.txt          resumen del arreglo para Radeon lentas
├─ scripts\
│   ├─ 1-Instalar-Nodos.bat       instala el editor en tu ComfyUI y crea Abrir-Editor-Qwen.bat
│   ├─ 2-Descargar-Modelos.bat    baja los modelos de Qwen-Image-2.1 (18 a 34 GB), reanuda si se corta y verifica cada archivo
│   ├─ 3-Probar-Edicion.bat       edición de prueba: dice si todo funciona y cuánto tarda
│   ├─ 4-Arreglo-AMD.bat          para Radeon: modo Rápido que cabe en la tarjeta, codificador liviano y ajustes de RAM
│   ├─ 5-Diagnostico.bat          mide en segundos la tarjeta (cálculo, copia RAM -> VRAM, memoria) y guarda un informe
│   └─ (los usan los .bat)        Instalar-Nodos.ps1, Descargar-Modelos.ps1, Actualizar.ps1, Abrir-Editor-Qwen.bat,
│                                 parchear_gguf.py, probar_edicion.py, diagnostico.py
├─ nodos\
│   ├─ ComfyUI-EditorQwen\        el editor web (se abre en http://127.0.0.1:8188/editor-qwen)
│   └─ ComfyUI-ProtegerEdicion\   el nodo "Proteger lo que no cambió"
├─ workflows\                     el mismo proceso para usar dentro de ComfyUI:
│   ├─ Qwen21-Editar-GGUF.json            editar una imagen
│   ├─ Qwen21-Ropa-Referencia.json        copiar la ropa de otra imagen
│   └─ Qwen21-Varias-Imagenes.json        varias imágenes en una instrucción (p. ej. personajes juntos)
├─ referencia\                    aquí quedan el resultado de la prueba y el informe del diagnóstico
└─ herramientas\generar_guia.py   rehace GUIA.html a partir de README.md (solo para quien mantiene el repositorio)
```

`1-Instalar-Nodos` guarda tu carpeta de ComfyUI y tu VRAM en `mi-instalacion.json`, así `Actualizar.bat` no te pregunta nada. Ese archivo es de tu PC y no se sube a GitHub.

**Modelos que se descargan** (desde Hugging Face, sin cuenta):

| Archivo | Carpeta | Tamaño |
|---|---|---|
| `qwen-image-2.1-Q8_0.gguf` (el modelo de edición, modo Calidad) | `models\diffusion_models` | 7.6 GB |
| `qwen-image-2.1-turbo-Q8_0.gguf` (modo Rápido, opcional) | `models\diffusion_models` | 7.6 GB |
| `qwen3vl_8b_bf16.safetensors` (codificador de texto; con 16 GB de RAM o AMD: `qwen3vl_8b_int8_convrot.safetensors`, 9.4 GB) | `models\text_encoders` | 17.5 GB |
| `qwen_image_2.1_vae_bf16.safetensors` | `models\vae` | 0.7 GB |

**Detalles técnicos** (para quien le interese):

- **Qué instala `1-Instalar-Nodos`:** el nodo `ComfyUI-GGUF` de city96, fijado en la versión probada (`6ea2651`), con un pequeño parche que le enseña a reconocer Qwen-Image-2.1. El GGUF de unsloth no trae los datos que ese nodo usa para identificar el modelo.
- **Qué hace la protección:** compara la salida de Qwen con tu imagen a 256 px y arma una máscara de la zona que cambió. Sobre ella:
  1. cierra la máscara (rellena huecos y une partes cercanas);
  2. descarta motas de ruido;
  3. en ediciones locales (menos del 5 % de la imagen) amplía la zona a su vecindario;
  4. agrega un borde suave y pega esa zona sobre tu original.
- **Con qué opciones arranca ComfyUI el lanzador:** `--preview-method auto` (vista previa en vivo) y `--reserve-vram` (deja memoria de video libre para Windows). En AMD, además:
  - `--disable-async-offload`;
  - `--fp32-vae` (evita NaN en el VAE);
  - quita `--cache-lru 20` del lanzador del fork, para que ComfyUI use su caché por presión de RAM.
- **Por qué AMD iba lento:** en RDNA 2 el modelo ya se calcula en fp32 (el log dice `manual cast: torch.float32`). El problema es la memoria:
  - con el Q8_0 a 1024 solo cabe parte del modelo en la VRAM (en la 6600 XT, 2.6 GB de 7.5) y el resto se copia en cada paso;
  - el fork desactiva la memoria fijada (`--disable-pinned-memory`), que es la que acelera esas copias;
  - con 16 GB de RAM y `--cache-lru` el modelo termina leyéndose del disco.

  Por eso `4-Arreglo-AMD` usa un Turbo Q4_K_M (4.2 GB) en tarjetas de hasta 12 GB, y el editor parte en 768 en Radeon.
- **NaN en AMD desde la segunda edición:** con la memoria dinámica de ComfyUI (DynamicVRAM, el log dice `prepared for dynamic VRAM loading`), en Radeon un modelo que queda en la VRAM entre usos puede leer pesos dañados, sobre todo si el VAE necesita más memoria de la libre ([Comfy-Org/ComfyUI#15452](https://github.com/Comfy-Org/ComfyUI/issues/15452)). Por eso el editor decodifica con el nodo `DecodificarSeguro`: en AMD descarga todos los modelos antes y después de decodificar (cada edición parte como la primera) y, en cualquier tarjeta, si el VAE devuelve NaN lo vuelve a cargar y decodifica otra vez (y si sigue, por partes de 512 px), sin repetir el dibujo. `--disable-dynamic-vram` también lo evita, pero usa más RAM y no lo probé.
- **Modo Rápido:** usa `qwen-image-2.1-turbo` con el muestreo de la plantilla oficial de ComfyUI: CFG 1, euler, 8 pasos con sigmas fijos (`1.0, 0.978453, 0.95418, 0.926626, 0.89508, 0.845148, 0.704534, 0.414568, 0`).
- **LoRAs:** el editor encadena hasta dos `LoraLoaderModelOnly` entre el modelo GGUF y `QwenImage21Cache`. En el workflow de ComfyUI ese nodo viene desactivado (bypass): elige el archivo y actívalo con Ctrl+B.
- **Cambio grande:** no agrega el nodo de protección; guarda la salida del VAE tal cual, al tamaño de trabajo (no se escala al tamaño de tu imagen).
- **Varias imágenes:** el nodo de texto de Qwen-Image-2.1 recibe tu personaje en `image_1` y las demás en `image_2`, `image_3`… (acepta hasta 16; el editor deja 4 extra), todas a la resolución de Opciones. Qwen edita la primera (el resultado toma su tamaño) y le antepone a cada una la etiqueta `<image1>`, `<image2>`…, que es como la plantilla oficial pide nombrarlas en la instrucción (no "the first image"). Con protección se compara contra tu personaje, igual que en una edición normal.
- **Sin acceso remoto:** el editor se sirve desde el mismo ComfyUI, así que no hace falta abrir ComfyUI a otras páginas (CORS).

---

## 10. Licencia y créditos

- **Qwen-Image-2.1** (Alibaba Qwen) se distribuye con la *Qwen Research License*: **uso personal y de investigación, no comercial**. Si quieres usar las imágenes con fines comerciales, revisa la licencia en <https://huggingface.co/Qwen/Qwen-Image-2.1>.
- Cuantización GGUF: [unsloth/Qwen-Image-2.1-GGUF](https://huggingface.co/unsloth/Qwen-Image-2.1-GGUF) · archivos para ComfyUI: [Comfy-Org/Qwen-Image-2.1](https://huggingface.co/Comfy-Org/Qwen-Image-2.1)
- [ComfyUI](https://github.com/comfyanonymous/ComfyUI) · [ComfyUI-GGUF](https://github.com/city96/ComfyUI-GGUF) (city96) · [comfyui-rocm](https://github.com/patientx-cfz/comfyui-rocm) (patientx)
- Ranking de modelos de edición: [Artificial Analysis, Image Editing (open weights)](https://artificialanalysis.ai/image/leaderboard/editing/open-weights)

---

## 11. Actualizar

**Es el mismo archivo para NVIDIA y AMD.** Doble clic en **`ComfyForPanas\Actualizar.bat`**:

1. Baja los cambios nuevos y te muestra la lista de qué cambió.
2. Vuelve a instalar el editor y la protección en tu ComfyUI. Usa la carpeta y la VRAM que indicaste en `1-Instalar-Nodos` (la primera vez, si no las tiene, te las pregunta). En AMD vuelve a dejar bien los ajustes de `comfyui-user.bat`.
3. Si ComfyUI estaba abierto, ciérralo y ábrelo de nuevo con **`Abrir-Editor-Qwen.bat`**. Si el editor estaba abierto en el navegador, recarga la página con `F5`.

No toca tus modelos, tus imágenes ni tu ComfyUI (solo los nodos del editor). Si un cambio necesita un modelo nuevo, la lista de cambios lo dice y te indica qué archivo correr.

### Si tenías el paquete anterior en zip (`EditorQwen-Paquete`)

1. Cierra la ventana negra de ComfyUI.
2. Baja ComfyForPanas (paso 3 de tu sección: [NVIDIA](#3-instalación-con-tarjeta-nvidia) o [AMD](#4-instalación-con-tarjeta-amd-radeon)) y haz doble clic en **`Actualizar.bat`**. Te pide una vez la carpeta de ComfyUI y la VRAM.
3. **Si aún no tenías el modo Rápido:**
   - **AMD:** doble clic en **`scripts\4-Arreglo-AMD.bat`**. Arrastra tu carpeta `comfyui-rocm`, escribe los GB de VRAM y presiona Enter. Baja el modelo Turbo del tamaño justo y al final te dice qué revisar.
   - **NVIDIA:** doble clic en **`scripts\2-Descargar-Modelos.bat`** y presiona Enter cuando pregunte por el modo Rápido. Lo que ya tenías no se vuelve a bajar.
4. Ya puedes borrar la carpeta `EditorQwen-Paquete` vieja.

En AMD, si tenías el codificador grande (`qwen3vl_8b_bf16.safetensors`, 17.5 GB), después puedes borrarlo: el editor ahora usa el "int8".

---

## 12. Entrenar el LoRA de un personaje (opcional)

Illustrious no sabe dibujar a **tu** personaje: si lo describes con texto, cada imagen sale con otra cara. Para que salga siempre el mismo hace falta un **LoRA**, un archivo chico (unos 40 MB) que se entrena con 20 a 35 imágenes del personaje. Después lo eliges en el modo Generar y escribes su palabra clave en la descripción.

El trabajo se divide en dos partes, que pueden hacer personas distintas:

| Quién | Qué hace | Tarjeta | Tiempo |
|---|---|---|---|
| **Dueño del personaje** | Elige las imágenes, completa la plantilla y arma el paquete con `8-Preparar-Paquete-LoRA.bat` | Cualquiera (NVIDIA o AMD): el etiquetado usa el procesador | Una tarde la primera vez |
| **Quien entrena** | Ejecuta `7-Entrenar-LoRA.bat` con el paquete | **NVIDIA con 8 GB o más** | GTX 1070: unas 2 h 45 min · RTX 30/40: unos 30 min (estimado) |

> **El repositorio es público:** guarda las imágenes y los LoRAs de tus personajes **fuera** de la carpeta ComfyForPanas.

### Paso 1 · Junta las imágenes (dueño del personaje)

1. Crea una carpeta para el personaje, por ejemplo `D:\lora\Aiko\`, y copia ahí sus mejores imágenes. Si tiene varios peinados puedes separarlos en subcarpetas (`suelto\`, `coleta\`), pero no hace falta.
2. Copia **`referencia\Plantilla-Personaje-LoRA.md`** a esa carpeta y complétala: palabra clave, edad, rasgos fijos y rasgos que cambian. Al final trae la lista para revisar las imágenes.

Lo más importante:

- **Calidad antes que cantidad:** 20 a 35 imágenes donde el personaje se vea claramente igual (cara, ojos, pelo, piel). Una imagen con otro color de ojos o con otra cara confunde al LoRA.
- **Variedad en todo lo demás:** poses, ángulos (de cerca, cuerpo entero, perfil, espalda), ropa y fondos. Si 10 imágenes tienen el mismo fondo, el LoRA lo dibujará siempre.
- **Sin texto ni marcas de agua.** La estrella de Gemini, abajo a la derecha, también cuenta: recorta ese borde.
- **¿Te falta un ángulo?** Hazlo con Qwen en el editor (**Cambio grande**) desde tu mejor imagen, por ejemplo *"Full body shot from head to toe, standing"* o *"Show her from the side in profile view"*. Revisa que siga viéndose adulta. **Nunca** uses imágenes hechas con Illustrious sin LoRA: no saben dibujar a tu personaje.

### Paso 2 · Arma el paquete (dueño del personaje)

1. Doble clic en **`ComfyForPanas\scripts\8-Preparar-Paquete-LoRA.bat`**.
2. Arrastra la carpeta de imágenes y presiona Enter. Escribe la **palabra clave** y pega los **rasgos fijos** en inglés, separados por coma; los dos están en tu plantilla.
3. La primera vez instala `onnxruntime` en el Python de tu ComfyUI y baja el etiquetador **WD14** (326 MB, desde Hugging Face, sin cuenta).
4. Al terminar quedan dos cosas junto a tu carpeta:
   - `Aiko_paquete\`: para revisar.
   - **`Aiko_paquete.zip`**: el paquete para entrenar.

Cada imagen recibe un `.txt` con la palabra clave y lo que se ve en ella (ropa, pose, fondo, peinado). Los rasgos fijos se quitan para que los aprenda la palabra clave; lo que cambia se deja, así después lo puedes pedir en el prompt.

**Revisa `Aiko_paquete\etiquetas_frecuentes.txt`.** Si una etiqueta aparece en casi todas las imágenes y es un rasgo fijo (por ejemplo `dark skin` en 35/35), agrégala a los rasgos fijos y vuelve a ejecutar el `.bat`: la quita de todos los `.txt`. También puedes corregir un `.txt` a mano. Por ejemplo, si el personaje tiene dos flequillos, puedes escribir `blunt bangs` o `swept bangs` en cada imagen. Al volver a ejecutarlo se conservan tus cambios, se etiquetan solo las imágenes nuevas y se rehace el zip.

### Paso 3 · Entrena (quien tenga NVIDIA)

1. **Cierra ComfyUI**: el entrenamiento necesita toda la memoria de la tarjeta.
2. Doble clic en **`ComfyForPanas\scripts\7-Entrenar-LoRA.bat`**, arrastra el `.zip` y presiona Enter.
3. **La primera vez:**
   - Instala **kohya sd-scripts**, el programa de entrenamiento, en `\EntrenarLoRA` del mismo disco que ComfyUI. Ocupa unos 7 GB y trae su propio Python 3.12 y torch 2.8.0, sin tocar tu ComfyUI.
   - Si no tienes **Illustrious-XL v1.1**, te ofrece bajarlo (6.9 GB).
4. Primero prepara las imágenes, lo que tarda unos minutos. Después entrena unos 1400 pasos y guarda una versión del LoRA por época (10 en total). El PC no se suspende mientras entrena; no cierres la ventana. Si se corta, ejecútalo de nuevo.
5. Al terminar copia las versiones a **`ComfyUI\models\loras\<palabra clave>\`**. Si entrenaste para otra persona, mándale el archivo elegido (o todos).

**¿Tu tarjeta aguantará?** En PowerShell, `.\Entrenar-LoRA.ps1 -Paquete "ruta\del\paquete.zip" -Prueba` entrena solo 20 pasos y muestra cuántos segundos tarda cada uno.

### Paso 4 · Elige la mejor versión

El LoRA se usa con Illustrious, no con Qwen. Dentro de ComfyUI, carga `Illustrious-XL-v1.1` con `Load Checkpoint`, agrega el nodo `LoraLoaderModelOnly` entre el modelo y el KSampler, y escribe la palabra clave al inicio del prompt. Cuando el editor tenga el modo **🎨 Generar**, también se elegirá ahí, en **⚙ Opciones → 🎨 Generar**. Compara las versiones (por ejemplo las épocas 4, 6, 8 y 10) con **la misma semilla y la misma descripción**, y también sin el LoRA:

- **Si le falta:** no se parece al personaje.
- **Si se pasó:** siempre sale con la misma pose, ropa o fondo, o la imagen se ve "quemada".

Quédate con la primera versión que ya se parece y todavía obedece la descripción.

**Qué está probado:**

- **GTX 1070 de 8 GB:** con kohya `690ea7f` y torch 2.8.0 cu126, `7-Entrenar-LoRA` con `-Prueba` funcionó de punta a punta: paquete, configuración, 20 pasos y LoRA guardado. Usó unos 7.7 GB de VRAM y tardó unos 7.5 s por paso a 1024. Un entrenamiento completo (1400 pasos) se probó solo hasta el paso 110, sin errores.
- **Todavía no se comprobó:** la calidad del LoRA, es decir, qué época conviene.
- **RTX 30/40:** no se probaron. El script usa bf16 en esas tarjetas.

**Detalles técnicos:**

- **Base y red:** Illustrious-XL v1.1. LoRA de rango 8 (alpha 4), solo en la U-Net.
- **Optimizador:** Adafactor con learning rate 3e-4, constante tras 50 pasos de calentamiento.
- **Imágenes:** 1024 px con grupos por proporción, sin agrandar las más chicas.
- **Memoria:** caché de latentes y del codificador de texto, y gradient checkpointing.
- **Precisión:** fp16 con el VAE en fp32 (bf16 en RTX 30 o más nueva).
- **Duración:** unos 140 pasos por época durante 10 épocas; las repeticiones de la carpeta `img\N_palabraclave` se calculan para eso.

Todo está en el `.toml` del paquete, que se puede editar. Viene de `referencia\LoRA-Personaje.toml`, y es la configuración que la documentación de kohya recomienda para SDXL con 8 GB.
