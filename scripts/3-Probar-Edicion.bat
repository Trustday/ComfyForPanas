@echo off
setlocal
title Prueba del Editor Qwen

REM Uso:  3-Probar-Edicion.bat "D:\ComfyUI_windows_portable"  [puerto]  ["D:\imagen.png"]
REM Con ComfyUI YA ABIERTO (Abrir-Editor-Qwen.bat), hace una edicion de prueba ("pelo rojo", resolucion 512)
REM sobre una imagen tuya, mide el tiempo y dice si funciono. El resultado queda en referencia\resultado_prueba.png.

set "COMFY=%~1"
if "%COMFY%"=="" set /p "COMFY=Ruta de tu ComfyUI (ej. D:\ComfyUI_windows_portable o D:\comfyui-rocm): "
set "COMFY=%COMFY:"=%"
set "PUERTO=%~2"
if "%PUERTO%"=="" set "PUERTO=8188"
set "IMG=%~3"
if not "%IMG%"=="" goto tengo_img
echo.
echo  Arrastra a esta ventana una imagen de una persona o personaje (con el pelo visible) y presiona Enter.
set /p "IMG=Imagen: "
:tengo_img
if defined IMG set "IMG=%IMG:"=%"

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
"%PY%" -s "%~dp0probar_edicion.py" --server http://127.0.0.1:%PUERTO% --imagen "%IMG%"
echo.
pause
