@echo off
setlocal
title Diagnostico de la tarjeta - Editor Qwen

REM Mide en unos segundos la velocidad de calculo de la tarjeta, la copia RAM -> tarjeta, la VRAM y la RAM.
REM Cierra antes la ventana de ComfyUI (para medir con la tarjeta libre).
REM Uso: doble clic  o  5-Diagnostico.bat "C:\comfyui-rocm"
REM El resultado queda en referencia\diagnostico.txt para mandarlo a quien te ayuda.

set "COMFY=%~1"
if not "%COMFY%"=="" goto tengo_ruta
echo.
echo  Cierra la ventana negra de ComfyUI si esta abierta.
echo  Arrastra a esta ventana la carpeta de tu ComfyUI y presiona Enter.
echo    NVIDIA: ComfyUI_windows_portable    AMD: comfyui-rocm
echo.
set /p "COMFY=Carpeta: "
:tengo_ruta
set "COMFY=%COMFY:"=%"

set "PY="
if exist "%COMFY%\python_embeded\python.exe" set "PY=%COMFY%\python_embeded\python.exe"
if exist "%COMFY%\..\python_embeded\python.exe" set "PY=%COMFY%\..\python_embeded\python.exe"
if exist "%COMFY%\python_env\python.exe" set "PY=%COMFY%\python_env\python.exe"
if exist "%COMFY%\venv\Scripts\python.exe" set "PY=%COMFY%\venv\Scripts\python.exe"
if defined PYEXE set "PY=%PYEXE%"
if not defined PY (
  echo [ERROR] No encuentro el python de ComfyUI en "%COMFY%".
  pause
  exit /b 1
)
REM en comfyui-rocm se prepara ROCm igual que lo hace su lanzador
if exist "%COMFY%\python_env\Scripts\rocm-sdk.exe" "%COMFY%\python_env\Scripts\rocm-sdk.exe" init >nul 2>&1
"%PY%" -s "%~dp0diagnostico.py"
echo.
pause
