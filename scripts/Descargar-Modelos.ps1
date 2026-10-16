# Descarga los modelos de Qwen-Image-2.1 que usa el Editor Qwen: ~18 GB (codificador int8) o ~26 GB (bf16), +7.6 GB con -Turbo.
#
# Uso (PowerShell):
#   .\Descargar-Modelos.ps1 -Ruta "D:\ComfyUI_windows_portable"
#   .\Descargar-Modelos.ps1 -Ruta "D:\comfyui-rocm" -CarpetaModelos "F:\ModelosIA"     (guardarlos en otro disco, idealmente un SSD)
#   .\Descargar-Modelos.ps1 -Ruta "D:\ComfyUI_windows_portable" -SoloComprobar         (solo prueba los enlaces)
#
# Parametros:
#   -Ruta             carpeta de tu ComfyUI (la misma que en 1-Instalar-Nodos)
#   -CarpetaModelos   (opcional) carpeta donde guardar los modelos. Se agrega sola a extra_model_paths.yaml de ComfyUI.
#                     Recomendado si ComfyUI esta en un disco duro lento y tienes un SSD: la carga de modelos es mucho mas rapida.
#   -Codificador      auto (por defecto) | bf16 | int8
#                     bf16 = 17.5 GB, el original (necesita 32 GB de RAM). int8 = 9.4 GB, mismo resultado en las pruebas.
#                     auto elige int8 si tienes menos de 31 GB de RAM o una tarjeta AMD (carga mas rapido), si no bf16.
#   -Cuantizacion     Q8_0 (por defecto, 7.6 GB, casi sin perdida) | Q6_K | Q5_K_M | Q4_K_M (mas chicas, algo menos de calidad)
#   -Turbo            baja tambien el modelo Turbo (+7.6 GB): modo "Rapido" del editor, 8 pasos en vez de 25 (unas 3 veces mas rapido)
#   -CuantizacionTurbo  tamano del Turbo (por defecto el mismo que -Cuantizacion). Q4_K_M = 4.2 GB, para que quepa entero
#                     en tarjetas AMD de 8 a 12 GB (si no cabe, se copia desde la RAM en cada paso y todo va muchisimo mas lento)
#   -SoloComprobar    no descarga nada, solo comprueba que los enlaces respondan
#
# Lo que ya existe (con el tamano correcto) se salta. Las descargas cortadas se reanudan al volver a ejecutar.

param(
    [Parameter(Mandatory = $true)] [string]$Ruta,
    [string]$CarpetaModelos = '',
    [ValidateSet('auto', 'bf16', 'int8')] [string]$Codificador = 'auto',
    [ValidateSet('Q8_0', 'Q6_K', 'Q5_K_M', 'Q4_K_M')] [string]$Cuantizacion = 'Q8_0',
    [switch]$Turbo,
    [ValidateSet('', 'Q8_0', 'Q6_K', 'Q5_K_M', 'Q4_K_M')] [string]$CuantizacionTurbo = '',
    [switch]$SoloComprobar
)
if (-not $CuantizacionTurbo) { $CuantizacionTurbo = $Cuantizacion }
$ErrorActionPreference = 'Continue'

$Ruta = $Ruta.Trim('"').TrimEnd('\')
if (Test-Path "$Ruta\ComfyUI\main.py") { $comfy = "$Ruta\ComfyUI" }
elseif (Test-Path "$Ruta\main.py") { $comfy = $Ruta }
else { Write-Host "No reconozco '$Ruta' como ComfyUI (no encuentro main.py)." -ForegroundColor Red; exit 1 }

if ($Codificador -eq 'auto') {
    $ram = [math]::Round((Get-CimInstance Win32_ComputerSystem).TotalPhysicalMemory / 1GB)
    $gpus = @(Get-CimInstance Win32_VideoController | ForEach-Object { $_.Name })
    $amd = (($gpus -match 'Radeon').Count -gt 0) -and (($gpus -match 'NVIDIA').Count -eq 0)
    if ($ram -ge 31 -and -not $amd) { $Codificador = 'bf16' } else { $Codificador = 'int8' }
    $motivo = if ($amd) { 'tarjeta AMD' } else { "RAM $ram GB" }
    Write-Host ("{0} -> codificador de texto {1}" -f $motivo, $Codificador) -ForegroundColor Cyan
}

$hf = 'https://huggingface.co'
$tamQ = @{ 'Q8_0' = 7640860384; 'Q6_K' = 6271551200; 'Q5_K_M' = 5390223072; 'Q4_K_M' = 4199565024 }
$tamT = @{ 'Q8_0' = 7640860480; 'Q6_K' = 6271551296; 'Q5_K_M' = 5390223168; 'Q4_K_M' = 4199565120 }
$items = @(
    [pscustomobject]@{ Carpeta = 'diffusion_models'; Archivo = "qwen-image-2.1-$Cuantizacion.gguf"; Bytes = $tamQ[$Cuantizacion]
                       Url = "$hf/unsloth/Qwen-Image-2.1-GGUF/resolve/main/qwen-image-2.1-$Cuantizacion.gguf" },
    [pscustomobject]@{ Carpeta = 'vae'; Archivo = 'qwen_image_2.1_vae_bf16.safetensors'; Bytes = 675509688
                       Url = "$hf/Comfy-Org/Qwen-Image-2.1/resolve/main/vae/qwen_image_2.1_vae_bf16.safetensors" }
)
if ($Codificador -eq 'bf16') {
    $items += [pscustomobject]@{ Carpeta = 'text_encoders'; Archivo = 'qwen3vl_8b_bf16.safetensors'; Bytes = 17534334616
                                 Url = "$hf/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_bf16.safetensors" }
} else {
    $items += [pscustomobject]@{ Carpeta = 'text_encoders'; Archivo = 'qwen3vl_8b_int8_convrot.safetensors'; Bytes = 9350798360
                                 Url = "$hf/Comfy-Org/Qwen-Image-2.1/resolve/main/text_encoders/qwen3vl_8b_int8_convrot.safetensors" }
}
if ($Turbo) {
    $items += [pscustomobject]@{ Carpeta = 'diffusion_models'; Archivo = "qwen-image-2.1-turbo-$CuantizacionTurbo.gguf"; Bytes = $tamT[$CuantizacionTurbo]
                                 Url = "$hf/unsloth/Qwen-Image-2.1-Turbo-GGUF/resolve/main/qwen-image-2.1-turbo-$CuantizacionTurbo.gguf" }
}

# destino: models\ de ComfyUI, o la carpeta elegida (agregada a extra_model_paths.yaml)
if ($CarpetaModelos) {
    $base = $CarpetaModelos.Trim('"').TrimEnd('\')
    New-Item -ItemType Directory -Force $base | Out-Null
    $yaml = "$comfy\extra_model_paths.yaml"
    $ya = (Test-Path $yaml) -and ((Get-Content $yaml -Raw) -match '(?m)^editor_qwen:')
    if (-not $ya -and -not $SoloComprobar) {
        $bloque = @('', '# Modelos del Editor Qwen (agregado por Descargar-Modelos.ps1)', 'editor_qwen:',
                    ('    base_path: {0}/' -f ($base -replace '\\', '/')), '    diffusion_models: diffusion_models/',
                    '    text_encoders: text_encoders/', '    vae: vae/', '')
        Add-Content -Path $yaml -Value $bloque -Encoding ascii
        Write-Host "Agregado '$base' a $yaml" -ForegroundColor Yellow
    }
} else { $base = "$comfy\models" }

$total = ($items | Measure-Object -Property Bytes -Sum).Sum / 1GB
Write-Host ("Destino: {0}  |  {1} archivos  |  {2:N1} GB" -f $base, $items.Count, $total) -ForegroundColor Cyan
if ($SoloComprobar) { Write-Host '(modo SoloComprobar: no se descarga nada)' -ForegroundColor Yellow }
Write-Host ''

$fallos = 0
foreach ($it in $items) {
    $dest = Join-Path (Join-Path $base $it.Carpeta) $it.Archivo
    $estado = ''
    if ((Test-Path $dest) -and ((Get-Item $dest).Length -eq $it.Bytes)) { $estado = 'YA EXISTE' }
    elseif ($SoloComprobar) {
        $code = (& curl.exe -sL -m 40 -r 0-99 -o NUL -w '%{http_code}' $it.Url)
        if ($code -eq '200' -or $code -eq '206') { $estado = "OK (HTTP $code)" } else { $estado = "ENLACE ROTO (HTTP $code)"; $fallos++ }
    }
    else {
        Write-Host ("Descargando {0}  ({1:N1} GB) ..." -f $it.Archivo, ($it.Bytes / 1GB)) -ForegroundColor White
        New-Item -ItemType Directory -Force (Split-Path $dest) | Out-Null
        $tmp = "$dest.part"
        & curl.exe -L --fail --retry 5 --retry-delay 5 -C - -o $tmp $it.Url
        if ((Test-Path $tmp) -and ((Get-Item $tmp).Length -eq $it.Bytes)) {
            Move-Item -Force $tmp $dest
            $estado = 'DESCARGADO y verificado'
        } else {
            $estado = 'FALLO (incompleto): vuelve a ejecutar el script, la descarga continua donde quedo'
            $fallos++
        }
    }
    $color = 'Green'; if ($estado -like 'FALLO*' -or $estado -like 'ENLACE*') { $color = 'Red' }
    Write-Host ("  {0}\{1}  ->  {2}" -f $it.Carpeta, $it.Archivo, $estado) -ForegroundColor $color
}
Write-Host ''
if ($fallos -eq 0) {
    if ($SoloComprobar) { Write-Host 'Enlaces OK (no se descargo nada).' -ForegroundColor Green } else { Write-Host 'Listo: modelos completos.' -ForegroundColor Green }
    exit 0
}
Write-Host "$fallos archivo(s) con problemas (ver arriba en rojo)." -ForegroundColor Red
exit 2
