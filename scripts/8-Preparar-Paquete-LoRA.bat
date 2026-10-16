@echo off
setlocal
title Preparar el paquete de entrenamiento de un LoRA

REM Etiqueta las imagenes elegidas de un personaje y arma el .zip para 7-Entrenar-LoRA (este PC o el de un amigo con NVIDIA).
REM Antes: junta 20 a 35 imagenes buenas en una carpeta y llena referencia\Plantilla-Personaje-LoRA.md (ver la guia).
REM Uso: doble clic (te pregunta todo)
REM   o  8-Preparar-Paquete-LoRA.bat "D:\lora\Aiko" aikochan "long hair, black hair, red eyes"

set "IMGS=%~1"
if not "%IMGS%"=="" goto tengo_imgs
echo.
echo  Arrastra a esta ventana la carpeta con las imagenes elegidas del personaje y presiona Enter.
echo.
set /p "IMGS=Carpeta: "
:tengo_imgs
set "IMGS=%IMGS:"=%"

set "CLAVE=%~2"
if not "%CLAVE%"=="" goto tengo_clave
echo.
echo  Palabra clave del personaje: en minusculas, sin espacios ni tildes, que no sea una palabra real (ej. aikochan).
echo.
set /p "CLAVE=Palabra clave: "
:tengo_clave

set "QUITAR=%~3"
if not "%QUITAR%"=="" goto tengo_quitar
echo.
echo  Rasgos que el personaje SIEMPRE tiene, en ingles y separados por coma (estan en tu plantilla).
echo  Ej.: long hair, black hair, red eyes, dark skin, large breasts
echo  Lo que cambia (ropa, peinados, pose, fondo) NO va aqui. Si no sabes, presiona Enter y revisa el resumen del final.
echo.
set /p "QUITAR=Rasgos fijos: "
:tengo_quitar
set "ARGS="
if not "%QUITAR%"=="" set ARGS=-Quitar "%QUITAR%"

powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0Preparar-Paquete-LoRA.ps1" -Imagenes "%IMGS%" -PalabraClave "%CLAVE%" %ARGS%
echo.
pause
