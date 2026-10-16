@echo off
setlocal
title Actualizar ComfyForPanas
REM Baja la ultima version de ComfyForPanas y la instala en tu ComfyUI. Sirve igual para NVIDIA y AMD.
REM Uso: doble clic.   Opcional: Actualizar.bat -Ruta "D:\ComfyUI_windows_portable" -VramGB 12
REM Todo va dentro del parentesis a proposito: la actualizacion puede reemplazar este mismo archivo
REM mientras corre, y cmd lee el bloque completo antes de ejecutarlo.
(
  powershell -NoProfile -ExecutionPolicy Bypass -File "%~dp0scripts\Actualizar.ps1" %*
  echo.
  pause
  exit /b
)
