@echo off
setlocal
title Editor Qwen
REM Abre el Editor Qwen (edicion de imagenes por instrucciones) en el navegador.
REM Si ComfyUI no esta corriendo, lo arranca en otra ventana (no la cierres mientras uses el editor).
REM Instalar-Nodos.ps1 copia este archivo a la carpeta de ComfyUI con estos dos valores ajustados:
set "PUERTO=8188"
set "RESERVA=1.0"

cd /d "%~dp0"
set "URL=http://127.0.0.1:%PUERTO%"
curl -s -o nul -f %URL%/system_stats
if not errorlevel 1 goto listo

set "FLAGS=--port %PUERTO% --preview-method auto --reserve-vram %RESERVA%"
if exist "python_embeded\python.exe" (
  start "ComfyUI - Editor Qwen (no cerrar)" cmd /k python_embeded\python.exe -s ComfyUI\main.py --windows-standalone-build %FLAGS%
) else if exist "comfyui-user.bat" (
  start "ComfyUI - Editor Qwen (no cerrar)" cmd /k comfyui-user.bat
) else if exist "venv\Scripts\python.exe" (
  start "ComfyUI - Editor Qwen (no cerrar)" cmd /k venv\Scripts\python.exe main.py %FLAGS%
) else if exist ".venv\Scripts\python.exe" (
  start "ComfyUI - Editor Qwen (no cerrar)" cmd /k .venv\Scripts\python.exe main.py %FLAGS%
) else (
  echo [ERROR] No reconozco esta carpeta de ComfyUI.
  echo         Este archivo debe estar junto a run_nvidia_gpu.bat ^(NVIDIA^), comfyui-user.bat ^(AMD^) o main.py ^(manual^).
  pause
  exit /b 1
)
echo Arrancando ComfyUI en otra ventana... La primera vez puede tardar un par de minutos.
set /a N=0
:esperar
timeout /t 3 /nobreak >nul
curl -s -o nul -f %URL%/system_stats
if not errorlevel 1 goto listo
set /a N+=1
if %N% lss 200 goto esperar
echo [ERROR] ComfyUI no respondio en 10 minutos. Mira los mensajes en la ventana "ComfyUI - Editor Qwen".
pause
exit /b 1

:listo
curl -s -o nul -f %URL%/editor-qwen
if errorlevel 1 (
  echo [ERROR] ComfyUI esta corriendo pero no tiene el editor. Ejecuta 1-Instalar-Nodos.bat del paquete
  echo         y reinicia ComfyUI ^(cierra su ventana y vuelve a abrir este archivo^).
  pause
  exit /b 1
)
start "" %URL%/editor-qwen
