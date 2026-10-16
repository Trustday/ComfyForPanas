# Entrena el LoRA de un personaje para Illustrious (SDXL) con kohya sd-scripts, a partir de un "paquete de entrenamiento".
# Solo tarjetas NVIDIA con 8 GB de VRAM o mas.
#
# Uso (PowerShell):
#   .\Entrenar-LoRA.ps1 -Paquete "D:\Descargas\Aiko_paquete.zip"  [-Ruta "D:\ComfyUI_windows_portable"]  [-Carpeta "D:\EntrenarLoRA"]
#   .\Entrenar-LoRA.ps1 -SoloInstalar [-Carpeta "D:\EntrenarLoRA"]      (solo instala kohya; lo usa Preparar-Paquete-LoRA.ps1)
#
# Parametros:
#   -Paquete      el .zip (o la carpeta) que arma 8-Preparar-Paquete-LoRA: img\<repeticiones>_<palabra clave>\ (imagenes + .txt) y un .toml
#   -Ruta         carpeta de tu ComfyUI (si no la das, usa la de mi-instalacion.json). Ahi se busca el modelo base y se dejan los LoRAs.
#   -Carpeta      donde se instala kohya y se guardan los trabajos (por defecto: \EntrenarLoRA en el mismo disco que ComfyUI). Ocupa ~7 GB.
#   -Checkpoint   ruta de Illustrious-XL-v1.1.safetensors, si lo tienes en otra parte
#   -Prueba       entrena solo 20 pasos para comprobar memoria y velocidad (unos minutos); no deja un LoRA util
#   -SinEntrenar  prepara todo y muestra el comando, sin entrenar
#
# Que hace:
#   1. Revisa la tarjeta (nvidia-smi): VRAM y generacion (RTX 30 o mas nueva -> bf16; GTX 10/16 y RTX 20 -> fp16).
#   2. La primera vez instala kohya sd-scripts (version probada) con su propio Python 3.12 y torch 2.8.0, sin tocar ComfyUI.
#   3. Busca Illustrious-XL v1.1 en tu ComfyUI; si no esta, ofrece bajarlo (6.9 GB, desde Hugging Face, sin cuenta).
#   4. Entrena con la configuracion del paquete (guarda una version del LoRA por epoca) y copia las versiones a models\loras\<palabra clave>.
# Si se corta, al volver a ejecutarlo reutiliza lo ya hecho (instalacion, modelo y cache de las imagenes) y parte el entrenamiento de nuevo.

param(
    [string]$Paquete = '',
    [string]$Ruta = '',
    [string]$Carpeta = '',
    [string]$Checkpoint = '',
    [switch]$Prueba,
    [switch]$SoloInstalar,
    [switch]$SinEntrenar
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$KOHYA_COMMIT = '690ea7f'   # kohya-ss/sd-scripts probado (24-sep-2026)
$TORCH = 'torch==2.8.0', 'torchvision==0.23.0'
$ILLUSTRIOUS = 'Illustrious-XL-v1.1.safetensors'
$ILLUSTRIOUS_BYTES = 6938040728
$ILLUSTRIOUS_URL = 'https://huggingface.co/OnomaAIResearch/Illustrious-XL-v1.1/resolve/main/Illustrious-XL-v1.1.safetensors'
$inv = [System.Globalization.CultureInfo]::InvariantCulture

function Ok($t) { Write-Host "[ok] $t" -ForegroundColor Green }
function Falla($t) { Write-Host "[ERROR] $t" -ForegroundColor Red; exit 1 }
function Aviso($t) { Write-Host "[AVISO] $t" -ForegroundColor Yellow }
function Escribir-Utf8($ruta, $lineas) { [System.IO.File]::WriteAllLines($ruta, [string[]]$lineas, (New-Object System.Text.UTF8Encoding $false)) }

# ---------- carpeta de ComfyUI y de kohya ----------
if (-not $Ruta -and (Test-Path "$repo\mi-instalacion.json")) { $Ruta = (Get-Content "$repo\mi-instalacion.json" -Raw | ConvertFrom-Json).Ruta }
if (-not $Ruta -and -not $SoloInstalar) {
    Write-Host ''
    $Ruta = Read-Host 'Arrastra a esta ventana la carpeta de tu ComfyUI (ej. ComfyUI_windows_portable) y presiona Enter'
}
$comfy = $null
if ($Ruta) {
    $Ruta = $Ruta.Trim().Trim('"').TrimEnd('\')
    if (Test-Path "$Ruta\ComfyUI\main.py") { $comfy = "$Ruta\ComfyUI" }
    elseif (Test-Path "$Ruta\main.py") { $comfy = $Ruta }
    elseif (-not $SoloInstalar) { Falla "No reconozco '$Ruta' como ComfyUI (no encuentro main.py)." }
}
if (-not $Carpeta) {
    if ($comfy) { $Carpeta = (Split-Path -Qualifier $comfy) + '\EntrenarLoRA' } else { $Carpeta = "$env:USERPROFILE\EntrenarLoRA" }
}
$Carpeta = $Carpeta.Trim().Trim('"').TrimEnd('\')
New-Item -ItemType Directory -Force $Carpeta | Out-Null
$py = "$Carpeta\venv\Scripts\python.exe"
$sd = "$Carpeta\sd-scripts"
$marca = "$Carpeta\instalado.txt"
$env:PIP_CACHE_DIR = "$Carpeta\pip-cache"   # el cache de pip queda en este disco, no en C:
$env:PYTHONUTF8 = '1'                       # kohya imprime japones; sin esto falla si la salida va a un archivo

# ---------- 1. tarjeta ----------
if (-not (Get-Command nvidia-smi -ErrorAction SilentlyContinue)) { Falla 'No encuentro nvidia-smi: entrenar LoRAs solo funciona con tarjetas NVIDIA (con el driver instalado).' }
$ErrorActionPreference = 'Continue'
$q = & nvidia-smi --query-gpu=name,memory.total,compute_cap --format=csv,noheader,nounits 2>$null | Select-Object -First 1
if ($LASTEXITCODE -ne 0 -or -not $q) { $q = (& nvidia-smi --query-gpu=name,memory.total --format=csv,noheader,nounits 2>$null | Select-Object -First 1) + ', 0' }
$ErrorActionPreference = 'Stop'
$p = $q -split ',\s*'
$gpu = $p[0].Trim(); $vram = [int]$p[1]; $cc = 0.0; [void][double]::TryParse($p[2], [System.Globalization.NumberStyles]::Float, $inv, [ref]$cc)
if ($vram -lt 7500) { Falla "Tu $gpu tiene $vram MB de VRAM: para entrenar un LoRA de Illustrious hacen falta 8 GB." }
$precision = if ($cc -ge 8.0) { 'bf16' } else { 'fp16' }   # bf16 desde RTX 30 (Ampere); en GTX 10/16 y RTX 20 no existe
Ok ("{0}, {1:N1} GB de VRAM -> precision {2}" -f $gpu, ($vram / 1024), $precision)

# ---------- 2. kohya sd-scripts + Python + torch (una sola vez) ----------
function Instalar-Kohya {
    if (-not (Get-Command git -ErrorAction SilentlyContinue)) { Falla 'Falta Git. Instalalo desde https://git-scm.com/download/win y vuelve a ejecutar.' }
    if (-not (Test-Path "$sd\sdxl_train_network.py")) {
        & git clone https://github.com/kohya-ss/sd-scripts "$sd"
        if ($LASTEXITCODE -ne 0) { Falla 'No se pudo clonar kohya-ss/sd-scripts (revisa internet).' }
        & git -C "$sd" -c advice.detachedHead=false checkout -q $KOHYA_COMMIT
        if ($LASTEXITCODE -ne 0) { Falla "No se pudo fijar sd-scripts en la version $KOHYA_COMMIT." }
        Ok "kohya sd-scripts descargado (version $KOHYA_COMMIT)"
    }
    if (-not (Test-Path $py)) {
        $ErrorActionPreference = 'Continue'
        $hayPy312 = (Get-Command py -ErrorAction SilentlyContinue) -and ((& py -3.12 -c "print(1)" 2>$null) -eq '1')
        $ErrorActionPreference = 'Stop'
        if ($hayPy312) {
            & py -3.12 -m venv "$Carpeta\venv"
        } else {
            # sin Python 3.12 instalado: uv (un solo .exe) baja un Python 3.12 portable dentro de esta carpeta
            $uv = "$Carpeta\uv\uv.exe"
            if (-not (Test-Path $uv)) {
                New-Item -ItemType Directory -Force "$Carpeta\uv" | Out-Null
                & curl.exe -L --fail --retry 3 -o "$Carpeta\uv\uv.zip" 'https://github.com/astral-sh/uv/releases/latest/download/uv-x86_64-pc-windows-msvc.zip'
                if ($LASTEXITCODE -ne 0) { Falla 'No se pudo bajar uv (revisa internet).' }
                Expand-Archive -Force "$Carpeta\uv\uv.zip" "$Carpeta\uv"
            }
            $env:UV_PYTHON_INSTALL_DIR = "$Carpeta\python"; $env:UV_CACHE_DIR = "$Carpeta\uv-cache"
            & $uv venv --seed --python 3.12 "$Carpeta\venv"
        }
        if (-not (Test-Path $py)) { Falla 'No se pudo crear el entorno de Python 3.12.' }
        Ok "Python 3.12 en $Carpeta\venv"
    }
    $ErrorActionPreference = 'Continue'
    & $py -c "import torch,sys; sys.exit(0 if torch.__version__.startswith('2.8.0') and torch.cuda.is_available() else 1)" 2>$null
    $tieneTorch = $LASTEXITCODE -eq 0
    $ErrorActionPreference = 'Stop'
    if (-not $tieneTorch) {
        $idx = if ($cc -ge 12.0) { 'cu128' } else { 'cu126' }   # RTX 50 necesita cu128; cu128 ya no trae GTX 10 (Pascal)
        Write-Host "Instalando torch 2.8.0 ($idx, ~3 GB)..." -ForegroundColor White
        & $py -m pip install --disable-pip-version-check @TORCH --index-url "https://download.pytorch.org/whl/$idx"
        if ($LASTEXITCODE -ne 0) { Falla 'No se pudo instalar torch (revisa internet y el espacio en disco).' }
    }
    Ok 'torch 2.8.0 con CUDA'
    Push-Location $sd
    & $py -m pip install --disable-pip-version-check -r requirements.txt
    $res = $LASTEXITCODE
    Pop-Location
    if ($res -ne 0) { Falla 'pip no pudo instalar las dependencias de kohya (ver mensaje arriba).' }
    & $py -c "import torch, accelerate, diffusers, transformers; assert torch.cuda.is_available()"
    if ($LASTEXITCODE -ne 0) { Falla 'kohya quedo instalado pero torch no ve la tarjeta (revisa el driver de NVIDIA).' }
    Escribir-Utf8 $marca @("sd-scripts $KOHYA_COMMIT", ($TORCH -join ' '), (Get-Date -Format 'yyyy-MM-dd HH:mm'))
    Ok "kohya listo en $Carpeta"
}
if (-not (Test-Path $marca) -or -not (Test-Path $py) -or -not (Test-Path "$sd\sdxl_train_network.py")) { Instalar-Kohya } else { Ok "kohya ya instalado en $Carpeta" }
if ($SoloInstalar) { exit 0 }

# ---------- 3. modelo base: Illustrious-XL v1.1 ----------
function Buscar-Checkpoint {
    $cands = @("$comfy\models\checkpoints\$ILLUSTRIOUS")
    $yaml = "$comfy\extra_model_paths.yaml"
    if (Test-Path $yaml) {
        # cada seccion de extra_model_paths.yaml: base_path + checkpoints (una ruta, o varias en un bloque "|")
        $base = $null; $rels = @(); $enLista = $false
        foreach ($l in @(Get-Content $yaml) + 'fin:') {
            if ($l -match '^\S') {
                if ($base) { foreach ($r in $rels) { $cands += Join-Path (Join-Path $base $r) $ILLUSTRIOUS } }
                $base = $null; $rels = @(); $enLista = $false; continue
            }
            if ($l -match '^\s+base_path:\s*(.+?)\s*$') { $base = $Matches[1].Trim('"', "'"); $enLista = $false }
            elseif ($l -match '^\s+checkpoints:\s*\|\s*$') { $enLista = $true }
            elseif ($l -match '^\s+checkpoints:\s*(\S.*?)\s*$') { $rels += $Matches[1].Trim('"', "'"); $enLista = $false }
            elseif ($l -match '^\s+\w+:') { $enLista = $false }
            elseif ($enLista -and $l.Trim()) { $rels += $l.Trim() }
        }
    }
    foreach ($c in $cands) { if ((Test-Path $c) -and ((Get-Item $c).Length -eq $ILLUSTRIOUS_BYTES)) { return $c } }
    return $null
}
if ($Checkpoint) {
    $Checkpoint = $Checkpoint.Trim().Trim('"')
    if (-not (Test-Path $Checkpoint)) { Falla "No existe '$Checkpoint'." }
} else {
    $Checkpoint = Buscar-Checkpoint
    if (-not $Checkpoint) {
        Write-Host ''
        Write-Host "No encuentro $ILLUSTRIOUS en tu ComfyUI. Es el modelo base del LoRA: 6.9 GB desde Hugging Face (sin cuenta)." -ForegroundColor Yellow
        $r = Read-Host 'Lo bajo a models\checkpoints? (S/N)'
        if ($r -notmatch '^[sSyY]') { Falla "Sin el modelo base no se puede entrenar. Si ya lo tienes en otra carpeta, pasa -Checkpoint ""ruta\$ILLUSTRIOUS""." }
        $Checkpoint = "$comfy\models\checkpoints\$ILLUSTRIOUS"
        New-Item -ItemType Directory -Force (Split-Path $Checkpoint) | Out-Null
        & curl.exe -L --fail --retry 5 --retry-delay 5 -C - -o "$Checkpoint.part" $ILLUSTRIOUS_URL
        if (-not (Test-Path "$Checkpoint.part") -or (Get-Item "$Checkpoint.part").Length -ne $ILLUSTRIOUS_BYTES) { Falla 'Descarga incompleta: vuelve a ejecutar, continua donde quedo.' }
        Move-Item -Force "$Checkpoint.part" $Checkpoint
    }
}
Ok "modelo base: $Checkpoint"

# ---------- 4. paquete ----------
if (-not $Paquete) { $Paquete = Read-Host 'Arrastra a esta ventana el paquete de entrenamiento (.zip) y presiona Enter' }
$Paquete = $Paquete.Trim().Trim('"').TrimEnd('\')
if (-not (Test-Path $Paquete)) { Falla "No existe '$Paquete'." }
$item = Get-Item $Paquete
$nombre = $item.BaseName -replace '_paquete$', ''
$trabajo = "$Carpeta\trabajos\$nombre"
New-Item -ItemType Directory -Force $trabajo | Out-Null
# si el paquete cambio desde la ultima vez, se copia de nuevo (y se borra el cache de imagenes viejo)
$firma = '{0}|{1}' -f $item.LastWriteTimeUtc.Ticks, $(if ($item.PSIsContainer) { 0 } else { $item.Length })
$firmaTxt = "$trabajo\paquete.txt"
if (-not (Test-Path $firmaTxt) -or (Get-Content $firmaTxt -Raw).Trim() -ne $firma) {
    Get-ChildItem $trabajo -Exclude 'salida', 'prueba' | Remove-Item -Recurse -Force
    if ($item.PSIsContainer) { Copy-Item "$Paquete\*" $trabajo -Recurse -Force }
    else { Expand-Archive -Force $Paquete $trabajo }
    Escribir-Utf8 $firmaTxt @($firma)
}
# si el zip se armo comprimiendo la carpeta entera, el contenido queda un nivel mas abajo
$base = $trabajo
if (-not (Test-Path "$base\img")) { $sub1 = Get-ChildItem $trabajo -Directory | Where-Object { Test-Path "$($_.FullName)\img" } | Select-Object -First 1; if ($sub1) { $base = $sub1.FullName } }
$dirs = @(Get-ChildItem "$base\img" -Directory -ErrorAction SilentlyContinue | Where-Object { $_.Name -match '^\d+_\S+' })
if ($dirs.Count -eq 0) { Falla 'El paquete no trae la carpeta img\<repeticiones>_<palabra clave> (ej. img\4_aikochan).' }
$toml = Get-ChildItem $base -Filter *.toml | Select-Object -First 1
if (-not $toml) { Falla 'El paquete no trae el archivo .toml de configuracion.' }
$imgs = @(); foreach ($d in $dirs) { $imgs += @(Get-ChildItem $d.FullName -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|webp)$' }) }
$sinTxt = @($imgs | Where-Object { -not (Test-Path ([System.IO.Path]::ChangeExtension($_.FullName, '.txt'))) })
if ($imgs.Count -eq 0) { Falla 'El paquete no trae imagenes.' }
if ($sinTxt.Count) { Aviso ("{0} imagen(es) sin su .txt de etiquetas (ej. {1}): se entrenan solo con la palabra clave de la carpeta." -f $sinTxt.Count, $sinTxt[0].Name) }
$clave = ($dirs[0].Name -split '_', 2)[1]
$pasosEpoca = 0; foreach ($d in $dirs) { $n = @(Get-ChildItem $d.FullName -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|webp)$' }).Count; $pasosEpoca += $n * [int](($d.Name -split '_', 2)[0]) }
Ok ("paquete '{0}': {1} imagenes, palabra clave '{2}'" -f $nombre, $imgs.Count, $clave)

# ---------- 5. configuracion final ----------
$propias = 'pretrained_model_name_or_path', 'train_data_dir', 'output_dir', 'logging_dir', 'mixed_precision'
if ($Prueba) { $propias += 'max_train_epochs', 'max_train_steps', 'save_every_n_epochs', 'output_name' }
$lineas = @(Get-Content $toml.FullName -Encoding UTF8 | Where-Object { $l = $_; -not ($propias | Where-Object { $l -match "^\s*$_\s*=" }) })
$epocas = 10; foreach ($l in $lineas) { if ($l -match '^\s*max_train_epochs\s*=\s*(\d+)') { $epocas = [int]$Matches[1] } }
$salida = if ($Prueba) { "$trabajo\prueba" } else { "$trabajo\salida" }
$lineas += '', '# agregado por Entrenar-LoRA.ps1 (rutas de este PC y precision de esta tarjeta)'
$lineas += ('pretrained_model_name_or_path = "{0}"' -f ($Checkpoint -replace '\\', '/'))
$lineas += ('train_data_dir = "{0}"' -f ("$base\img" -replace '\\', '/'))
$lineas += ('output_dir = "{0}"' -f ($salida -replace '\\', '/'))
$lineas += ('logging_dir = "{0}"' -f ("$trabajo\logs" -replace '\\', '/'))
$lineas += ('mixed_precision = "{0}"' -f $precision)
if ($Prueba) { $lineas += 'max_train_steps = 20', 'save_every_n_epochs = 1000', 'output_name = "prueba"' }
$final = "$trabajo\config_final.toml"
Escribir-Utf8 $final $lineas
$pasos = if ($Prueba) { 20 } else { $pasosEpoca * $epocas }
Ok ("configuracion: $final  ({0} pasos)" -f $pasos)

$log = "$trabajo\entrenamiento.log"
if ($SinEntrenar) {
    Write-Host ''
    Write-Host "Comando (desde $sd):" -ForegroundColor Cyan
    Write-Host "  `"$py`" sdxl_train_network.py --config_file `"$final`" --console_log_file `"$log`""
    exit 0
}

# ---------- 6. entrenar ----------
$ErrorActionPreference = 'Continue'
$usada = [int](& nvidia-smi --query-gpu=memory.used --format=csv,noheader,nounits 2>$null | Select-Object -First 1)
$ErrorActionPreference = 'Stop'
if ($usada -gt 1500) {
    Aviso "La tarjeta ya tiene $usada MB ocupados. Cierra ComfyUI, juegos y lo que use la tarjeta: si no, puede quedarse sin memoria o ir muchisimo mas lento."
    [void](Read-Host 'Presiona Enter cuando lo hayas cerrado (o para seguir igual)')
}
Write-Host ''
Write-Host ("Entrenando {0} pasos. Referencia: una GTX 1070 tarda ~7 s por paso (1400 pasos = ~2 h 45 min); una RTX 30/40, cerca de 1 s." -f $pasos) -ForegroundColor Cyan
Write-Host 'Primero prepara el cache de las imagenes (unos minutos). No cierres esta ventana; el PC no se suspendera mientras entrena.' -ForegroundColor Cyan
Write-Host ''
Add-Type -Name Energia -Namespace EntrenarLoRA -MemberDefinition '[DllImport("kernel32.dll")] public static extern uint SetThreadExecutionState(uint f);'
# ES_CONTINUOUS | ES_SYSTEM_REQUIRED (0x80000001): sin suspension por inactividad. En decimal: PowerShell 5.1 lee 0x80000001 como negativo
[void][EntrenarLoRA.Energia]::SetThreadExecutionState([uint32]2147483649)
Push-Location $sd
& $py sdxl_train_network.py --config_file "$final" --console_log_file "$log"
$res = $LASTEXITCODE
Pop-Location
[void][EntrenarLoRA.Energia]::SetThreadExecutionState([uint32]2147483648)   # ES_CONTINUOUS: vuelve a lo normal
if ($res -ne 0) { Falla "El entrenamiento se detuvo con error (codigo $res). El detalle queda en $log." }

# ---------- 7. resultado ----------
$lorasOut = @(Get-ChildItem $salida -Filter *.safetensors -ErrorAction SilentlyContinue | Sort-Object Name)
if ($lorasOut.Count -eq 0) { Falla "No quedo ningun LoRA en $salida." }
if ($Prueba) {
    Ok 'Prueba terminada sin errores: la tarjeta aguanta. Ejecutalo sin -Prueba para entrenar de verdad.'
    exit 0
}
$destino = $salida
if ($comfy) {
    $destino = "$comfy\models\loras\$clave"
    New-Item -ItemType Directory -Force $destino | Out-Null
    Copy-Item ($lorasOut | ForEach-Object { $_.FullName }) $destino -Force
}
Write-Host ''
Ok ("{0} versiones del LoRA en {1}" -f $lorasOut.Count, $destino)
Write-Host 'Cada archivo es una epoca (el numero del nombre); el que no tiene numero es la ultima.' -ForegroundColor Cyan
Write-Host "Pruebalos con la palabra clave '$clave' al inicio del prompt y quedate con el que se parezca mas sin verse 'pegado'" -ForegroundColor Cyan
Write-Host '(siempre la misma pose o el mismo fondo = paso de largo). Si entrenaste para otra persona, mandale ese archivo.' -ForegroundColor Cyan
