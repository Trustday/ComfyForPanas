# Actualiza ComfyForPanas desde GitHub y vuelve a instalar el editor en tu ComfyUI (sirve igual para NVIDIA y AMD).
#
# Uso: doble clic en Actualizar.bat (en la carpeta principal de ComfyForPanas)
#   o: .\Actualizar.ps1 [-Ruta "D:\ComfyUI_windows_portable"] [-VramGB 12]
#
# Que hace:
#   1. Baja los cambios nuevos con git y muestra la lista. Si bajaste el zip en vez de clonar,
#      la primera vez convierte la carpeta en un clon (tus resultados y mi-instalacion.json no se tocan).
#   2. Vuelve a correr Instalar-Nodos.ps1 con la carpeta de ComfyUI guardada en mi-instalacion.json.
#      Ese script detecta solo si es NVIDIA o AMD; en AMD vuelve a ajustar comfyui-user.bat.
# No toca los modelos: si un cambio necesita un modelo nuevo, la lista de cambios lo dice.

param(
    [string]$Ruta = '',
    [string]$VramGB = '',
    [string]$RepoUrl = 'https://github.com/Trustday/ComfyForPanas',   # solo se usa si la carpeta vino en zip (sin .git)
    [switch]$SinDescargar   # solo reinstala; lo usa este mismo script cuando la actualizacion lo cambio a el
)
$ErrorActionPreference = 'Stop'
$RAMA = 'main'
$repo = Split-Path -Parent $PSScriptRoot
$configArchivo = "$repo\mi-instalacion.json"
[Console]::OutputEncoding = [System.Text.Encoding]::UTF8   # los mensajes de los cambios traen tildes

function Ok($t) { Write-Host "[ok] $t" -ForegroundColor Green }
function Falla($t) { Write-Host "[ERROR] $t" -ForegroundColor Red; exit 1 }
function Aviso($t) { Write-Host "[AVISO] $t" -ForegroundColor Yellow }

if (-not (Get-Command git -ErrorAction SilentlyContinue)) {
    Falla "Falta Git. Instalalo desde https://git-scm.com/download/win (opciones por defecto) y vuelve a ejecutar."
}

# ---------- 1. bajar la version nueva ----------
if (-not $SinDescargar) {
    $actualizador = "$PSScriptRoot\Actualizar.ps1"
    $hashAntes = (Get-FileHash $actualizador).Hash
    $ErrorActionPreference = 'Continue'   # git escribe avisos normales en stderr
    if (-not (Test-Path "$repo\.git")) {
        Write-Host "Esta carpeta vino en un zip: la convierto en una copia de GitHub para poder actualizarla..." -ForegroundColor Cyan
        & git -C $repo init -q
        & git -C $repo remote add origin $RepoUrl
        & git -C $repo fetch -q origin $RAMA
        if ($LASTEXITCODE -ne 0) {
            Remove-Item "$repo\.git" -Recurse -Force
            Falla "No pude conectarme a $RepoUrl (revisa internet) y vuelve a intentar."
        }
        & git -C $repo checkout -q -f -B $RAMA "origin/$RAMA"
        if ($LASTEXITCODE -ne 0) { Falla "No pude dejar la carpeta en la version de GitHub (mira el mensaje de arriba)." }
        Ok "Listo: la carpeta quedo con la ultima version y desde ahora se actualiza con este mismo archivo."
    } else {
        $cambiados = @(& git -C $repo status --porcelain --untracked-files=no)
        if ($cambiados.Count) {
            Aviso "Estos archivos de ComfyForPanas se modificaron en este PC:"
            $cambiados | ForEach-Object { Write-Host "    $_" }
            $r = Read-Host "Escribe S para borrar esos cambios y bajar la version nueva (Enter = cancelar)"
            if ($r -notmatch '^\s*[sS]') { Falla "Cancelado. No se cambio nada." }
            & git -C $repo reset -q --hard
        }
        $antes = (& git -C $repo rev-parse HEAD) -join ''
        Write-Host "Buscando cambios nuevos..." -ForegroundColor Cyan
        & git -C $repo pull -q --ff-only origin $RAMA
        if ($LASTEXITCODE -ne 0) {
            Falla "No pude bajar los cambios (revisa internet). Si sigue fallando, borra la carpeta ComfyForPanas y vuelve a clonarla (README, paso 3)."
        }
        $despues = (& git -C $repo rev-parse HEAD) -join ''
        if ($antes -eq $despues) { Ok "Ya tenias la ultima version." }
        else {
            Ok "Version nueva descargada. Cambios:"
            & git -C $repo log --no-merges --format="    - %s" "$antes..$despues" | ForEach-Object { Write-Host $_ }
        }
    }
    $ErrorActionPreference = 'Stop'
    if ((Get-FileHash $actualizador).Hash -ne $hashAntes) {
        # la actualizacion cambio este mismo script: el resto lo hace la version nueva
        $hijo = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', $actualizador, '-SinDescargar')
        if ($Ruta) { $hijo += @('-Ruta', $Ruta.Trim('"').TrimEnd('\')) }
        if ($VramGB) { $hijo += @('-VramGB', $VramGB) }
        & powershell @hijo
        exit $LASTEXITCODE
    }
}

# ---------- 2. instalar en ComfyUI ----------
$cfg = $null
if (Test-Path $configArchivo) {
    try { $cfg = Get-Content $configArchivo -Raw -Encoding UTF8 | ConvertFrom-Json } catch { Aviso "No pude leer mi-instalacion.json; te pregunto la carpeta de nuevo." }
}
if (-not $Ruta -and $cfg) { $Ruta = [string]$cfg.Ruta }
if (-not $VramGB -and $cfg) { $VramGB = [string]$cfg.VramGB }
if (-not $Ruta) {
    Write-Host ""
    Write-Host " Arrastra a esta ventana la carpeta de tu ComfyUI y presiona Enter."
    Write-Host "   NVIDIA: la carpeta ComfyUI_windows_portable"
    Write-Host "   AMD   : la carpeta comfyui-rocm"
    $Ruta = Read-Host "Carpeta"
    if (-not $VramGB) { $VramGB = Read-Host "GB de VRAM de tu tarjeta (Enter si no sabes)" }
}
$Ruta = $Ruta.Trim().Trim('"').TrimEnd('\')
if (-not $Ruta) { Falla "No indicaste la carpeta de ComfyUI." }

Write-Host ""
Write-Host "Actualizando el editor en $Ruta ..." -ForegroundColor Cyan
$inst = @('-NoProfile', '-ExecutionPolicy', 'Bypass', '-File', "$PSScriptRoot\Instalar-Nodos.ps1", '-Ruta', $Ruta)
if ($VramGB) { $inst += @('-VramGB', $VramGB) }
$puerto = 8188
if ($cfg -and $cfg.Puerto) { $puerto = [int]$cfg.Puerto; $inst += @('-Puerto', $puerto) }
if ($cfg -and $null -ne $cfg.ReservaVram) { $inst += @('-ReservaVram', ([double]$cfg.ReservaVram).ToString([System.Globalization.CultureInfo]::InvariantCulture)) }
& powershell @inst
if ($LASTEXITCODE -ne 0) { Falla "La instalacion no termino (mira los mensajes en rojo). Puedes volver a ejecutar Actualizar.bat." }

$abierto = $false
try { $null = Invoke-WebRequest "http://127.0.0.1:$puerto/system_stats" -UseBasicParsing -TimeoutSec 2; $abierto = $true } catch {}
Write-Host ""
if ($abierto) {
    Write-Host "ComfyUI esta abierto: cierra su ventana negra y vuelve a abrir Abrir-Editor-Qwen.bat para usar la version nueva." -ForegroundColor Cyan
} else {
    Write-Host "Listo. Abre el editor con Abrir-Editor-Qwen.bat como siempre." -ForegroundColor Cyan
}
Write-Host "Si el editor estaba abierto en el navegador, recarga la pagina con F5." -ForegroundColor Cyan
