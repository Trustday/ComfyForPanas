# Arma el "paquete de entrenamiento" del LoRA de un personaje: copia las imagenes elegidas, las etiqueta con WD14
# (en la CPU, sirve con NVIDIA o AMD), pone la palabra clave al inicio y deja un .zip listo para 7-Entrenar-LoRA.
#
# Uso (PowerShell):
#   .\Preparar-Paquete-LoRA.ps1 -Imagenes "D:\lora\Aiko" -PalabraClave aikochan -Quitar "long hair, black hair, red eyes"
#
# Parametros:
#   -Imagenes      carpeta con las imagenes elegidas del personaje (incluye subcarpetas)
#   -PalabraClave  palabra unica que activa al personaje: minusculas, sin espacios, que no sea una palabra real (ej. aikochan)
#   -Quitar        etiquetas de los rasgos que el personaje SIEMPRE tiene, en ingles como en Danbooru, separadas por coma
#                  (color y largo de pelo, ojos, piel, marcas, cuerpo). Se quitan para que los aprenda la palabra clave.
#                  Lo que cambia (ropa, pose, fondo, peinados, expresion) se deja: asi despues se puede pedir en el prompt.
#   -Ruta          carpeta de tu ComfyUI (si no la das, usa la de mi-instalacion.json): se usa su Python y ahi queda el modelo WD14
#   -Umbral        confianza minima para poner una etiqueta (0.35 por defecto)
#   -Reetiquetar   vuelve a etiquetar todas las imagenes (pierde lo corregido a mano en los .txt)
#
# Resultado, junto a la carpeta de imagenes:
#   <Nombre>_paquete\       para revisar: img\<repeticiones>_<palabra clave>\ (imagenes + .txt), el .toml y etiquetas_frecuentes.txt
#   <Nombre>_paquete.zip    para entrenar (aqui o mandandoselo a un amigo con NVIDIA)
# Se puede repetir: agrega las imagenes nuevas, saca las que borraste, etiqueta solo lo nuevo y rehace el zip.

param(
    [Parameter(Mandatory = $true)] [string]$Imagenes,
    [Parameter(Mandatory = $true)] [string]$PalabraClave,
    [string]$Quitar = '',
    [string]$Ruta = '',
    [double]$Umbral = 0.35,
    [switch]$Reetiquetar
)
$ErrorActionPreference = 'Stop'
$repo = Split-Path -Parent $PSScriptRoot
$WD14 = 'wd-v1-4-moat-tagger-v2'
$WD14_ARCHIVOS = @{ 'model.onnx' = 326197340; 'selected_tags.csv' = 253906 }
$PASOS_EPOCA = 140   # con 10 epocas = ~1400 pasos, lo probado para un personaje

function Ok($t) { Write-Host "[ok] $t" -ForegroundColor Green }
function Falla($t) { Write-Host "[ERROR] $t" -ForegroundColor Red; exit 1 }
function Aviso($t) { Write-Host "[AVISO] $t" -ForegroundColor Yellow }

$Imagenes = $Imagenes.Trim().Trim('"').TrimEnd('\')
if (-not (Test-Path $Imagenes -PathType Container)) { Falla "No existe la carpeta '$Imagenes'." }
$PalabraClave = $PalabraClave.Trim()
if ($PalabraClave -notmatch '^[a-z0-9_]{4,30}$') { Falla 'La palabra clave va en minusculas, sin espacios ni tildes, de 4 a 30 letras o numeros (ej. aikochan).' }

# ---------- Python de ComfyUI ----------
if (-not $Ruta -and (Test-Path "$repo\mi-instalacion.json")) { $Ruta = (Get-Content "$repo\mi-instalacion.json" -Raw | ConvertFrom-Json).Ruta }
if (-not $Ruta) { $Ruta = Read-Host 'Arrastra a esta ventana la carpeta de tu ComfyUI y presiona Enter' }
$Ruta = $Ruta.Trim().Trim('"').TrimEnd('\')
$py = $null
if ((Test-Path "$Ruta\python_embeded\python.exe") -and (Test-Path "$Ruta\ComfyUI\main.py")) { $comfy = "$Ruta\ComfyUI"; $py = "$Ruta\python_embeded\python.exe" }
elseif ((Test-Path "$Ruta\main.py") -and (Test-Path "$Ruta\..\python_embeded\python.exe")) { $comfy = $Ruta; $py = (Resolve-Path "$Ruta\..\python_embeded\python.exe").Path }
elseif ((Test-Path "$Ruta\main.py") -and (Test-Path "$Ruta\python_env\python.exe")) { $comfy = $Ruta; $py = "$Ruta\python_env\python.exe" }
elseif ((Test-Path "$Ruta\main.py") -and (Test-Path "$Ruta\venv\Scripts\python.exe")) { $comfy = $Ruta; $py = "$Ruta\venv\Scripts\python.exe" }
elseif ((Test-Path "$Ruta\main.py") -and (Test-Path "$Ruta\.venv\Scripts\python.exe")) { $comfy = $Ruta; $py = "$Ruta\.venv\Scripts\python.exe" }
if (-not $py) { Falla "No reconozco '$Ruta' como ComfyUI (NVIDIA portable, AMD comfyui-rocm o carpeta con main.py y venv)." }

# onnxruntime (CPU) para el etiquetador, sin tocar torch ni numpy de ComfyUI
$ErrorActionPreference = 'Continue'
& $py -c "import onnxruntime" 2>$null
$tiene = $LASTEXITCODE -eq 0
if (-not $tiene) {
    $cons = Join-Path $env:TEMP 'preparar_lora_constraints.txt'
    $fijos = @(& $py -m pip list --format=freeze --disable-pip-version-check 2>$null | Where-Object { $_ -match '^(torch|torchvision|torchaudio|numpy|rocm[^=]*)==' })
    [System.IO.File]::WriteAllLines($cons, [string[]]$fijos)
    & $py -m pip install -q onnxruntime -c $cons --no-warn-script-location --disable-pip-version-check
    $tiene = $LASTEXITCODE -eq 0
}
$ErrorActionPreference = 'Stop'
if (-not $tiene) { Falla 'No se pudo instalar onnxruntime en el Python de ComfyUI (ver mensaje arriba).' }

# modelo WD14 (326 MB, Hugging Face, sin cuenta)
$wd = "$comfy\models\wd14_tagger\$WD14"
New-Item -ItemType Directory -Force $wd | Out-Null
foreach ($f in $WD14_ARCHIVOS.Keys) {
    $dest = "$wd\$f"
    if ((Test-Path $dest) -and (Get-Item $dest).Length -eq $WD14_ARCHIVOS[$f]) { continue }
    Write-Host "Descargando el etiquetador WD14: $f ..." -ForegroundColor White
    & curl.exe -L --fail --retry 5 --retry-delay 5 -C - -o "$dest.part" "https://huggingface.co/SmilingWolf/$WD14/resolve/main/$f"
    if (-not (Test-Path "$dest.part") -or (Get-Item "$dest.part").Length -ne $WD14_ARCHIVOS[$f]) { Falla "Descarga incompleta de $f`: vuelve a ejecutar, continua donde quedo." }
    Move-Item -Force "$dest.part" $dest
}
Ok "etiquetador $WD14 listo"

# ---------- imagenes ----------
$origen = Get-Item $Imagenes
$nombre = $origen.Name
$out = Join-Path $origen.Parent.FullName "${nombre}_paquete"
$fotos = @(Get-ChildItem $Imagenes -Recurse -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|webp)$' })
if ($fotos.Count -eq 0) { Falla "No hay imagenes (png, jpg o webp) en '$Imagenes'." }
if ($fotos.Count -lt 15) { Aviso ("Solo {0} imagenes: con menos de 15 el LoRA cuesta que generalice. Lo ideal son 20 a 35." -f $fotos.Count) }
$rep = [int][Math]::Max(1, [Math]::Min(20, [Math]::Round($PASOS_EPOCA / $fotos.Count)))
$img = "$out\img\${rep}_$PalabraClave"
New-Item -ItemType Directory -Force "$out\img" | Out-Null
# si cambio la cantidad de imagenes cambian las repeticiones: se renombra la carpeta (los .txt corregidos se conservan)
Get-ChildItem "$out\img" -Directory | Where-Object { $_.FullName -ne $img } | ForEach-Object {
    if (-not (Test-Path $img)) { Rename-Item $_.FullName (Split-Path $img -Leaf) } else { Remove-Item $_.FullName -Recurse -Force }
}
New-Item -ItemType Directory -Force $img | Out-Null
# las imagenes de subcarpetas se copian con el nombre de la subcarpeta adelante (ej. coleta_01.png), para que no choquen
$nombres = @{}
foreach ($f in $fotos) {
    $rel = $f.DirectoryName.Substring($origen.FullName.Length).Trim('\') -replace '\\', '_'
    $plano = if ($rel) { "${rel}_$($f.Name)" } else { $f.Name }
    $nombres[$plano.ToLower()] = $true
    $dest = "$img\$plano"
    if (-not (Test-Path $dest) -or (Get-Item $dest).LastWriteTimeUtc -lt $f.LastWriteTimeUtc) {
        Copy-Item $f.FullName $dest -Force
        Remove-Item ([System.IO.Path]::ChangeExtension($dest, '.txt')) -ErrorAction SilentlyContinue   # imagen nueva o cambiada: se reetiqueta
    }
}
foreach ($f in @(Get-ChildItem $img -File | Where-Object { $_.Extension -match '^\.(png|jpe?g|webp)$' })) {
    if (-not $nombres.ContainsKey($f.Name.ToLower())) {
        Remove-Item $f.FullName, ([System.IO.Path]::ChangeExtension($f.FullName, '.txt')) -Force -ErrorAction SilentlyContinue
    }
}
Ok ("{0} imagenes x {1} repeticiones = {2} pasos por epoca" -f $fotos.Count, $rep, ($fotos.Count * $rep))

# ---------- etiquetas ----------
$extra = @('--umbral', $Umbral.ToString([System.Globalization.CultureInfo]::InvariantCulture))
if ($Quitar.Trim()) { $extra += '--quitar', $Quitar }   # PowerShell 5.1 no pasa argumentos vacios
if ($Reetiquetar) { $extra += '--todas' }
& $py "$PSScriptRoot\etiquetar_wd14.py" $img $wd $PalabraClave @extra
if ($LASTEXITCODE -ne 0) { Falla 'El etiquetador fallo (ver mensaje arriba).' }

# ---------- configuracion, instrucciones y zip ----------
$toml = "$out\$PalabraClave.toml"
Get-ChildItem $out -Filter *.toml | Where-Object { $_.FullName -ne $toml } | Remove-Item -Force   # si cambio la palabra clave
if (-not (Test-Path $toml)) {
    $plantilla = (Get-Content "$repo\referencia\LoRA-Personaje.toml" -Raw) -replace 'PALABRA_CLAVE', $PalabraClave
    [System.IO.File]::WriteAllText($toml, $plantilla, (New-Object System.Text.UTF8Encoding $false))
}
$leeme = @(
    "Paquete de entrenamiento del LoRA '$PalabraClave' para Illustrious-XL v1.1 ($($fotos.Count) imagenes).",
    '',
    'Para entrenarlo (tarjeta NVIDIA con 8 GB de VRAM o mas, ComfyForPanas instalado):',
    '  1. Cierra ComfyUI.',
    '  2. Doble clic en ComfyForPanas\scripts\7-Entrenar-LoRA.bat y arrastra este .zip a la ventana.',
    '     La primera vez instala lo necesario (~7 GB) y, si falta, ofrece bajar Illustrious-XL v1.1 (6.9 GB).',
    "  3. Al terminar, las versiones quedan en ComfyUI\models\loras\$PalabraClave\ (una por epoca).",
    '     Manda de vuelta la elegida, o todas si no sabes cual.',
    '',
    'Tiempo aproximado: ~1400 pasos. GTX 1070: ~2 h 45 min. RTX 30/40: alrededor de 30 min.')
[System.IO.File]::WriteAllLines("$out\LEEME.txt", [string[]]$leeme)
$zip = "$out.zip"
Remove-Item $zip -Force -ErrorAction SilentlyContinue
Compress-Archive -Path "$out\img", $toml, "$out\LEEME.txt" -DestinationPath $zip
Ok ("paquete listo: {0} ({1:N0} MB)" -f $zip, ((Get-Item $zip).Length / 1MB))
Write-Host ''
Write-Host "Revisa los .txt en $img si quieres (cada uno = palabra clave + etiquetas de esa imagen)." -ForegroundColor Cyan
Write-Host 'Si corriges alguno o agregas imagenes, vuelve a ejecutar: solo etiqueta lo nuevo y rehace el zip.' -ForegroundColor Cyan
Write-Host 'Para entrenar: 7-Entrenar-LoRA.bat con el zip (aqui, o mandaselo a un amigo con NVIDIA).' -ForegroundColor Cyan
