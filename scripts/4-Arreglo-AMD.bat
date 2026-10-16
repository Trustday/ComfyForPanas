@echo off
setlocal
title Arreglo AMD - Editor Qwen mas rapido en Radeon

REM Para quien YA tiene el Editor Qwen en una tarjeta AMD Radeon (comfyui-rocm) y le va muy lento
REM o le salio alguna imagen negra o con ruido. Hace todo de una vez:
REM   1. Actualiza el editor (trae el modo Rapido) y el nodo de proteccion.
REM   2. Ajusta comfyui-user.bat: VAE en precision completa (sin imagenes negras) y quita --cache-lru,
REM      que deja los modelos ocupando la RAM y con 16 GB obliga a leer el modelo del disco en cada paso.
REM   3. Baja el modo Rapido (Turbo) en un tamano que quepa entero en la tarjeta y el codificador de texto liviano (int8).
REM Uso: doble clic (pregunta todo)  o  4-Arreglo-AMD.bat "C:\comfyui-rocm" 8 ["F:\ModelosIA"]

set "COMFY=%~1"
if not "%COMFY%"=="" goto tengo_ruta
echo.
echo  Arrastra a esta ventana tu carpeta comfyui-rocm y presiona Enter.
echo.
set /p "COMFY=Carpeta: "
:tengo_ruta
set "COMFY=%COMFY:"=%"

set "VRAM=%~2"
if not "%VRAM%"=="" goto tengo_vram
echo.
echo  Cuantos GB de VRAM tiene tu tarjeta? (RX 6600 / 6600 XT = 8, RX 6700 XT = 12, RX 6800 / 7800 XT = 16)
set /p "VRAM=GB de VRAM: "
:tengo_vram
set /a VGB=%VRAM% 2>nul
if "%VGB%"=="" set "VGB=0"

set "MODELOS=%~3"
if not "%~1"=="" goto tengo_modelos
echo.
echo  Si guardaste los modelos en otra carpeta (no dentro de comfyui-rocm), arrastrala aqui. Si no, presiona Enter.
set /p "MODELOS=Carpeta de los modelos (Enter = dentro de comfyui-rocm): "
:tengo_modelos
if defined MODELOS set "MODELOS=%MODELOS:"=%"
set "DEST="
if defined MODELOS set DEST=-CarpetaModelos "%MODELOS%"

REM Turbo que quepa entero en la VRAM: Q4_K_M (4.2 GB) hasta 12 GB, Q8_0 (7.6 GB) con 16 GB o mas
set "QT=Q4_K_M"
if %VGB% GEQ 16 set "QT=Q8_0"

echo.
echo ===== 1 de 2: actualizar el editor y comfyui-user.bat =====
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Instalar-Nodos.ps1" -Ruta "%COMFY%" -VramGB "%VRAM%"
if errorlevel 1 goto error
echo.
echo ===== 2 de 2: bajar el modo Rapido (Turbo %QT%) y el codificador liviano =====
powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Descargar-Modelos.ps1" -Ruta "%COMFY%" %DEST% -Turbo -CuantizacionTurbo %QT% -Codificador int8 %4 %5
if errorlevel 1 goto error

echo.
echo  ================================ LISTO ================================
echo  1. Cierra la ventana negra de ComfyUI si estaba abierta y abre Abrir-Editor-Qwen.bat.
echo  2. En el editor deja marcado "Rapido" (junto a Enviar). La primera vez queda en
echo     resolucion 768; la puedes cambiar en Opciones.
echo  3. Haz una edicion y busca en la ventana negra la linea que empieza con "loaded":
echo       "loaded completely"  = el modelo cupo entero en la tarjeta (asi va rapido)
echo       "loaded partially"   = no cupo; mandale esa linea y la de los segundos por paso
echo                              ("s/it") a quien te ayuda.
echo  =======================================================================
pause
exit /b 0

:error
echo.
echo  [ERROR] Algo fallo (mira los mensajes en rojo arriba). Puedes volver a ejecutar este archivo:
echo          lo que ya quedo hecho no se repite.
pause
exit /b 1
