@echo off
setlocal
title Paso 1 - Instalar el Editor Qwen en ComfyUI

REM Uso:  doble clic (te pregunta todo)   o   1-Instalar-Nodos.bat "D:\ComfyUI_windows_portable" 12
REM   1er dato: carpeta de ComfyUI  (NVIDIA: ComfyUI_windows_portable  |  AMD: comfyui-rocm)
REM   2o dato : GB de VRAM de tu tarjeta de video (para dejar memoria libre a Windows)

set "COMFY=%~1"
if not "%COMFY%"=="" goto tengo_ruta
echo.
echo  Arrastra a esta ventana la carpeta de tu ComfyUI y presiona Enter.
echo    NVIDIA: la carpeta ComfyUI_windows_portable
echo    AMD   : la carpeta comfyui-rocm
echo.
set /p "COMFY=Carpeta: "
:tengo_ruta
set "COMFY=%COMFY:"=%"

set "VRAM=%~2"
if not "%VRAM%"=="" goto tengo_vram
echo.
echo  Cuantos GB de VRAM tiene tu tarjeta de video? (ej. 8, 12, 16, 24)
echo  Lo ves en: Administrador de tareas ^> Rendimiento ^> GPU ^> "Memoria de GPU dedicada".
echo  Si no sabes, presiona Enter.
set /p "VRAM=GB de VRAM: "
:tengo_vram
if "%VRAM%"=="" set "VRAM=0"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-Nodos.ps1" -Ruta "%COMFY%" -VramGB "%VRAM%"
echo.
pause
