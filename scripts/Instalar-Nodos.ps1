# Instala el Editor Qwen en un ComfyUI existente (NVIDIA portable, AMD comfyui-rocm o instalacion manual con venv).
#
# Uso (PowerShell):  .\Instalar-Nodos.ps1 -Ruta "D:\ComfyUI_windows_portable"  [-VramGB 12]  [-ReservaVram 1.0]  [-Puerto 8188]
#   -Ruta        carpeta de tu ComfyUI:
#                  NVIDIA portable   -> D:\ComfyUI_windows_portable   (o ...\ComfyUI_windows_portable\ComfyUI)
#                  AMD comfyui-rocm  -> D:\comfyui-rocm
#                  manual (git+venv) -> la carpeta donde esta main.py
#   -VramGB      GB de VRAM de tu tarjeta; con eso se elige la reserva (8 GB o menos -> 1.2 | 10-12 GB -> 1.0 | 16 GB o mas -> 0.8)
#   -ReservaVram GB de VRAM que ComfyUI deja libres para Windows y el navegador (si lo indicas, manda sobre -VramGB)
#   -Puerto      puerto de ComfyUI (8188 es el normal)
#
# Que hace:
#   1. Comprueba que ComfyUI sea 0.37 o mas nuevo (Qwen-Image-2.1 lo necesita).
#   2. Clona ComfyUI-GGUF (version probada) y le agrega la deteccion de Qwen-Image-2.1 (parchear_gguf.py).
#   3. Copia los nodos del paquete: ComfyUI-EditorQwen (el editor web) y ComfyUI-ProtegerEdicion (proteger lo que no cambio).
#   4. Copia el workflow Qwen21-Editar-GGUF.json para usarlo dentro de ComfyUI.
#   5. Instala las dependencias de ComfyUI-GGUF sin tocar torch.
#   6. Crea Abrir-Editor-Qwen.bat en la carpeta de ComfyUI (doble clic = arranca ComfyUI y abre el editor).
#      En AMD comfyui-rocm ademas agrega a comfyui-user.bat la vista previa y los ajustes de memoria.
#   7. Guarda la carpeta de ComfyUI y los GB de VRAM en mi-instalacion.json, para que Actualizar.bat no pregunte.
# Se puede repetir sin problema (actualiza los nodos del paquete).

param(
    [Parameter(Mandatory = $true)] [string]$Ruta,
    [string]$VramGB = '0',
    [double]$ReservaVram = -1,
    [int]$Puerto = 8188
)
$ErrorActionPreference = 'Stop'
$reservaAuto = $ReservaVram -lt 0
$gb = 0; [void][int]::TryParse(($VramGB -replace '[^\d]', ''), [ref]$gb)
if ($reservaAuto) {
    if ($gb -le 0) { $ReservaVram = 1.0 } elseif ($gb -le 8) { $ReservaVram = 1.2 } elseif ($gb -le 12) { $ReservaVram = 1.0 } else { $ReservaVram = 0.8 }
}
$paquete = Split-Path -Parent $PSScriptRoot
$GGUF_COMMIT = '6ea2651'   # ComfyUI-GGUF probado con el parche (12-ene-2026)

function Ok($t) { Write-Host "[ok] $t" -ForegroundColor Green }
function Falla($t) { Write-Host "[ERROR] $t" -ForegroundColor Red; exit 1 }
function Aviso($t) { Write-Host "[AVISO] $t" -ForegroundColor Yellow }

$Ruta = $Ruta.Trim('"').TrimEnd('\')
if (-not (Test-Path $Ruta)) { Falla "No existe la carpeta '$Ruta'." }

# ---------- 1. tipo de instalacion ----------
$tipo = $null
if ((Test-Path "$Ruta\python_embeded\python.exe") -and (Test-Path "$Ruta\ComfyUI\main.py")) {
    $tipo = 'portable'; $raiz = $Ruta; $comfy = "$Ruta\ComfyUI"; $py = "$Ruta\python_embeded\python.exe"
} elseif ((Test-Path "$Ruta\main.py") -and (Test-Path "$Ruta\..\python_embeded\python.exe")) {
    $tipo = 'portable'; $raiz = (Resolve-Path "$Ruta\..").Path; $comfy = $Ruta; $py = "$raiz\python_embeded\python.exe"
} elseif ((Test-Path "$Ruta\main.py") -and (Test-Path "$Ruta\python_env\python.exe")) {
    $tipo = 'amd-rocm'; $raiz = $Ruta; $comfy = $Ruta; $py = "$Ruta\python_env\python.exe"
} elseif ((Test-Path "$Ruta\main.py") -and (Test-Path "$Ruta\venv\Scripts\python.exe")) {
    $tipo = 'manual'; $raiz = $Ruta; $comfy = $Ruta; $py = "$Ruta\venv\Scripts\python.exe"
} elseif ((Test-Path "$Ruta\main.py") -and (Test-Path "$Ruta\.venv\Scripts\python.exe")) {
    $tipo = 'manual'; $raiz = $Ruta; $comfy = $Ruta; $py = "$Ruta\.venv\Scripts\python.exe"
} elseif ((Test-Path "$Ruta\main.py") -and $env:PYEXE) {
    $tipo = 'manual'; $raiz = $Ruta; $comfy = $Ruta; $py = $env:PYEXE
}
if (-not $tipo) {
    Falla "No reconozco '$Ruta' como ComfyUI. Pasa la carpeta ComfyUI_windows_portable (NVIDIA), comfyui-rocm (AMD) o la carpeta con main.py y venv."
}
$nombres = @{ 'portable' = 'NVIDIA portable oficial'; 'amd-rocm' = 'AMD comfyui-rocm'; 'manual' = 'instalacion manual' }
Ok ("Instalacion: {0}  |  ComfyUI en {1}" -f $nombres[$tipo], $comfy)
if ($tipo -eq 'amd-rocm' -and $reservaAuto) {
    # en Radeon con Windows, si la VRAM se llena se desborda a la RAM ("memoria de GPU compartida") y cada paso tarda
    # decenas de veces mas: se deja mas margen que en NVIDIA
    if ($gb -le 0) { $ReservaVram = 1.5 } elseif ($gb -le 8) { $ReservaVram = 2.0 } elseif ($gb -le 12) { $ReservaVram = 1.5 } else { $ReservaVram = 1.0 }
}
Ok ("Se dejaran {0} GB de VRAM libres para Windows y el navegador" -f $ReservaVram.ToString("0.0#", [System.Globalization.CultureInfo]::InvariantCulture))

# ---------- 2. version de ComfyUI ----------
$verTxt = Get-Content "$comfy\comfyui_version.py" -ErrorAction SilentlyContinue | Select-String '__version__' | Select-Object -First 1
if ($verTxt -and ($verTxt.ToString() -match '(\d+)\.(\d+)\.(\d+)')) {
    $ver = [version]("{0}.{1}.{2}" -f $Matches[1], $Matches[2], $Matches[3])
    if ($ver -lt [version]'0.37.0') {
        $como = @{ 'portable' = 'baja el portable mas reciente o ejecuta update\update_comfyui.bat';
                   'amd-rocm' = 'ejecuta comfyui-rocm-updater.bat';
                   'manual' = 'haz git pull y pip install -r requirements.txt' }
        Falla "Tu ComfyUI es $ver y Qwen-Image-2.1 necesita 0.37.0 o mas nuevo: $($como[$tipo])."
    }
    Ok "ComfyUI $ver"
} else { Aviso "No pude leer la version de ComfyUI; sigo de todas formas (necesitas 0.37.0 o mas nuevo)." }

# ---------- 3. ComfyUI-GGUF + parche ----------
if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Falla "Falta Git. Instalalo desde https://git-scm.com/download/win y vuelve a ejecutar." }
$cn = "$comfy\custom_nodes"
$gguf = "$cn\ComfyUI-GGUF"
if (-not (Test-Path $gguf)) {
    & git clone https://github.com/city96/ComfyUI-GGUF "$gguf"
    if ($LASTEXITCODE -ne 0) { Falla "No se pudo clonar ComfyUI-GGUF (revisa internet)." }
    & git -C "$gguf" -c advice.detachedHead=false checkout -q $GGUF_COMMIT
    Ok "ComfyUI-GGUF clonado (version $GGUF_COMMIT)"
} else { Ok "ComfyUI-GGUF ya estaba instalado" }
& $py "$PSScriptRoot\parchear_gguf.py" "$gguf"
if ($LASTEXITCODE -ne 0) { Falla "No se pudo parchar ComfyUI-GGUF (ver mensaje arriba)." }

# ---------- 4. nodos y workflow del paquete ----------
foreach ($n in 'ComfyUI-EditorQwen', 'ComfyUI-ProtegerEdicion') {
    New-Item -ItemType Directory -Force "$cn\$n" | Out-Null
    Copy-Item "$paquete\nodos\$n\*" "$cn\$n\" -Recurse -Force
    Ok "$n copiado"
}
$wf = "$comfy\user\default\workflows"
New-Item -ItemType Directory -Force $wf | Out-Null
Copy-Item "$paquete\workflows\*.json" $wf -Force
Ok "workflow Qwen21-Editar-GGUF.json copiado (menu Workflows de ComfyUI)"

# ---------- 5. dependencias (sin tocar torch) ----------
$cons = Join-Path $env:TEMP 'editorqwen_constraints.txt'
# "pip list --format=freeze" da nombre==version incluso si torch se instalo desde un archivo (como en el portable)
$ErrorActionPreference = 'Continue'
$fijos = @(& $py -m pip list --format=freeze --disable-pip-version-check 2>$null | Where-Object { $_ -match '^(torch|torchvision|torchaudio|rocm[^=]*)==' })
$ErrorActionPreference = 'Stop'
[System.IO.File]::WriteAllLines($cons, [string[]]$fijos)
if ($fijos.Count) { Ok ("se mantienen: " + ($fijos -join ', ')) }
& $py -m pip install -q -r "$gguf\requirements.txt" -c $cons --no-warn-script-location --disable-pip-version-check
if ($LASTEXITCODE -ne 0) { Aviso "pip devolvio un error instalando las dependencias de ComfyUI-GGUF (revisa el mensaje)." } else { Ok "dependencias de ComfyUI-GGUF instaladas" }

# ---------- 6. lanzador ----------
$inv = [System.Globalization.CultureInfo]::InvariantCulture
$lanzador = Get-Content "$PSScriptRoot\Abrir-Editor-Qwen.bat" -Raw
$lanzador = $lanzador -replace 'set "PUERTO=\d+"', ('set "PUERTO={0}"' -f $Puerto) -replace 'set "RESERVA=[\d.]+"', ('set "RESERVA={0}"' -f $ReservaVram.ToString("0.0#", $inv))
[System.IO.File]::WriteAllText("$raiz\Abrir-Editor-Qwen.bat", $lanzador, [System.Text.Encoding]::ASCII)
Ok "creado $raiz\Abrir-Editor-Qwen.bat"

if ($tipo -eq 'amd-rocm') {
    $user = "$raiz\comfyui-user.bat"
    if (-not (Test-Path $user)) {
        if (-not (Test-Path "$raiz\comfyui-rocm.bat")) { Falla "No encuentro comfyui-rocm.bat ni comfyui-user.bat en '$raiz'." }
        Copy-Item "$raiz\comfyui-rocm.bat" $user
        Ok "creado comfyui-user.bat a partir de comfyui-rocm.bat"
    }
    # el bloque del paquete se reescribe entero en cada instalacion (asi una version vieja queda actualizada)
    $cierre = ':: ' + ('-' * 75)
    $lineas = [System.Collections.Generic.List[string]]([System.IO.File]::ReadAllLines($user))
    $ini = -1
    for ($i = 0; $i -lt $lineas.Count; $i++) { if ($lineas[$i] -like ':: ---------- AJUSTES EDITOR QWEN*') { $ini = $i; break } }
    if ($ini -ge 0) {
        $fin = -1
        for ($j = $ini + 1; $j -lt [Math]::Min($lineas.Count, $ini + 20); $j++) { if ($lineas[$j].Trim() -eq $cierre) { $fin = $j; break } }
        if ($fin -lt 0) { Falla "El bloque AJUSTES EDITOR QWEN de comfyui-user.bat esta incompleto (editado a mano?). Borralo a mano y vuelve a ejecutar." }
        if ($fin + 1 -lt $lineas.Count -and $lineas[$fin + 1].Trim() -eq '') { $fin++ }
        $lineas.RemoveRange($ini, $fin - $ini + 1)
    }
    $idx = -1
    for ($i = 0; $i -lt $lineas.Count; $i++) { if ($lineas[$i] -like '*keeping the necessary packages up-to-date*') { $idx = $i; break } }
    if ($idx -lt 0) { Aviso "No encontre donde agregar los ajustes en comfyui-user.bat. Agrega a mano las lineas de la guia (seccion AMD)." }
    else {
        $bloque = @(
            ':: ---------- AJUSTES EDITOR QWEN (agregado por Instalar-Nodos.ps1) ----------',
            ':: --cache-lru 20 (del lanzador) deja los modelos guardados en la RAM; con 16 GB el modelo termina leyendose',
            ':: del disco en cada paso. Se quita para usar la cache normal de ComfyUI, que libera RAM cuando hace falta.',
            'set "PARAMS=%PARAMS:--cache-lru 20=%"',
            ':: --preview-method auto   : vista previa mientras genera',
            ':: --disable-async-offload : evita cuelgues al cambiar de modelo en RDNA2',
            ':: --reserve-vram X        : deja X GB de VRAM libres para Windows y el navegador',
            ':: --fp32-vae              : VAE en precision completa; evita imagenes negras o con ruido (NaN) en Radeon',
            ('set "PARAMS=%PARAMS% --preview-method auto --disable-async-offload --reserve-vram {0} --fp32-vae"' -f $ReservaVram.ToString("0.0#", $inv)),
            ':: Si sale "HIP error: invalid kernel file" (graficos integrados del procesador), quita los :: de la linea siguiente:',
            ':: set HIP_VISIBLE_DEVICES=1',
            ':: ---------------------------------------------------------------------------',
            '')
        $lineas.InsertRange($idx, [string[]]$bloque)
        [System.IO.File]::WriteAllLines($user, $lineas)
        Ok "comfyui-user.bat: vista previa, VAE en fp32 (sin imagenes negras) y cache que libera RAM"
    }
}

# ---------- 7. recordar esta instalacion (la usa Actualizar.bat) ----------
$config = [ordered]@{ Ruta = $Ruta; VramGB = $VramGB; Puerto = $Puerto }
if (-not $reservaAuto) { $config.ReservaVram = $ReservaVram }
[System.IO.File]::WriteAllText("$paquete\mi-instalacion.json", ($config | ConvertTo-Json), (New-Object System.Text.UTF8Encoding $false))
Ok "guardado mi-instalacion.json (Actualizar.bat usara esta carpeta de ComfyUI)"

Write-Host ""
Write-Host "Listo. Siguiente paso: 2-Descargar-Modelos.bat (si aun no tienes los modelos)." -ForegroundColor Cyan
Write-Host "Para usar el editor: doble clic en  $raiz\Abrir-Editor-Qwen.bat" -ForegroundColor Cyan
if ($tipo -eq 'amd-rocm') { Write-Host "(En AMD, Abrir-Editor-Qwen.bat arranca ComfyUI con tu comfyui-user.bat.)" -ForegroundColor Cyan }
Write-Host "Para recibir arreglos y mejoras: doble clic en Actualizar.bat (carpeta principal de ComfyForPanas)." -ForegroundColor Cyan
