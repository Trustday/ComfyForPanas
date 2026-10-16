@echo off
setlocal
title Entrenar el LoRA de un personaje (Illustrious, solo NVIDIA)

REM Entrena el LoRA a partir del paquete (.zip) que arma 8-Preparar-Paquete-LoRA. Necesita NVIDIA con 8 GB de VRAM o mas.
REM La primera vez instala kohya sd-scripts (~7 GB) en \EntrenarLoRA del disco de ComfyUI y, si falta, ofrece bajar Illustrious-XL v1.1.
REM Uso: doble clic (te pide el paquete)   o   7-Entrenar-LoRA.bat "D:\Descargas\Aiko_paquete.zip" ["D:\ComfyUI_windows_portable"]
REM Opciones avanzadas (en PowerShell, ver Entrenar-LoRA.ps1): -Carpeta, -Checkpoint, -Prueba (20 pasos para medir memoria y velocidad)

set "PAQ=%~1"
if not "%PAQ%"=="" goto tengo_paquete
echo.
echo  Arrastra a esta ventana el paquete de entrenamiento (el .zip) y presiona Enter.
echo.
set /p "PAQ=Paquete: "
:tengo_paquete
set "PAQ=%PAQ:"=%"

set "ARGS="
if not "%~2"=="" set ARGS=-Ruta "%~2"

echo.
echo  Antes de seguir, cierra ComfyUI: el entrenamiento necesita toda la memoria de la tarjeta.
echo.
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Entrenar-LoRA.ps1" -Paquete "%PAQ%" %ARGS%
echo.
pause
