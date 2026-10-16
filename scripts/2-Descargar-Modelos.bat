@echo off
setlocal
title Paso 2 - Descargar los modelos de Qwen-Image-2.1

REM Uso:  doble clic (te pregunta todo)   o   2-Descargar-Modelos.bat "D:\ComfyUI_windows_portable"  ["F:\ModelosIA"]  [-Turbo]
REM   1er dato: carpeta de ComfyUI
REM   2o dato (opcional): otra carpeta para guardar los modelos (ej. en un SSD). "" = dentro de ComfyUI.
REM Opciones avanzadas (ver Descargar-Modelos.ps1): -Turbo  -Codificador bf16^|int8  -Cuantizacion Q8_0^|Q6_K^|Q5_K_M^|Q4_K_M  -SoloComprobar

set "COMFY=%~1"
if not "%COMFY%"=="" goto tengo_ruta
echo.
echo  Arrastra a esta ventana la carpeta de tu ComfyUI y presiona Enter.
echo    NVIDIA: la carpeta ComfyUI_windows_portable
echo    AMD   : la carpeta comfyui-rocm
echo.
set /p "COMFY=Carpeta: "
echo.
echo  Donde guardar los modelos (unos 18 a 34 GB)? Presiona Enter para guardarlos dentro de ComfyUI.
echo  Si tienes un disco SSD con espacio y ComfyUI esta en un disco duro normal, arrastra aqui una carpeta del SSD.
set /p "MODELOS=Carpeta para los modelos (Enter = dentro de ComfyUI): "
echo.
echo  Bajar tambien el modo RAPIDO (Turbo, +7.6 GB)? Edita unas 3 veces mas rapido (8 pasos en vez de 25).
echo  Recomendado, sobre todo con tarjetas AMD o de 8 GB.
set /p "QUIERE_TURBO=Escribe N para no bajarlo, o Enter para bajarlo: "
set "TURBO=-Turbo"
if /i "%QUIERE_TURBO%"=="N" set "TURBO="
goto descargar
:tengo_ruta
set "MODELOS=%~2"
set "TURBO="
:descargar
set "COMFY=%COMFY:"=%"
if defined MODELOS set "MODELOS=%MODELOS:"=%"
set "DEST="
if defined MODELOS set DEST=-CarpetaModelos "%MODELOS%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Descargar-Modelos.ps1" -Ruta "%COMFY%" %DEST% %TURBO% %3 %4 %5 %6
echo.
echo  Si algo quedo en rojo, vuelve a ejecutar este archivo: las descargas continuan donde quedaron.
pause
