@echo off
title GESTOR DE VM - SERVIDOR HTTP
color 0A
setlocal enabledelayedexpansion

:: Variables globales para rutas (inicializadas con valores por defecto)
set PROYECTO=C:\Users\UsuarioPC\Documents\REPOSITORIO\topic-jdc-processor
set QEMU_DIR=C:\Users\UsuarioPC\Documents\REPOSITORIO\Utilitarios\qemu_app
set DISCO_IMG=%QEMU_DIR%\alpine-podman.qcow2
set RUN_QEMU="%QEMU_DIR%\qemu-system-x86_64.exe" -m 4096 -smp 4 -hda "%DISCO_IMG%" -vga std -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080,hostfwd=tcp::8086-:8086,hostfwd=tcp::9092-:9092,hostfwd=tcp::8081-:8081 -device e1000,netdev=net0

:menu
cls
echo ==============================================================
echo    GESTOR DE VM - SERVIDOR HTTP - SSH
echo ==============================================================
echo.
echo CONFIGURACION ACTUAL:
echo   - Proyecto: %PROYECTO%
echo   - QEMU: %QEMU_DIR%\qemu-system-x86_64.exe
echo.
echo ==============================================================
echo.
echo [1] INICIAR SERVIDOR HTTP (Python) + VM QEMU
echo [2] INICIAR SOLO SERVIDOR HTTP
echo [3] INICIAR SOLO VM QEMU
echo [4] DETENER SERVIDOR HTTP
echo [5] SALIR
echo.
echo ==============================================================
echo NOTA: ssh -p 2222 root@localhost
echo 1- Dale enter y has login
echo 2- Ejecuta "cd /root/[nombre-proyecto] && ./executor_project.sh"
echo 3- Antes de salir ejecuta este comando "poweroff"
echo.
echo ==============================================================
echo.
set /p opcion="Selecciona una opcion: "

if "%opcion%"=="1" goto iniciar_http_y_vm
if "%opcion%"=="2" goto iniciar_http
if "%opcion%"=="3" goto iniciar_vm
if "%opcion%"=="4" goto detener_http
if "%opcion%"=="5" goto salir

echo Opcion no valida
pause
goto menu

:iniciar_http_y_vm
cls
echo ================================================
echo    INICIANDO SERVIDOR HTTP Y VM QEMU
echo ================================================
echo.

:: Verificar que las rutas están configuradas
if "%PROYECTO%"=="" goto configurar_rutas
if "%QEMU_DIR%"=="" goto configurar_rutas

:: Iniciar servidor HTTP en una nueva ventana
echo [1/3] Iniciando servidor HTTP en el puerto 8000...
echo Proyecto: %PROYECTO%
echo.
start "Servidor HTTP" cmd /k "cd /d "%PROYECTO%" && echo Proyecto: %PROYECTO% Servidor HTTP corriendo en http://localhost:8000 && python -m http.server 8000"

:: Esperar 3 segundos para que el servidor HTTP inicie
timeout /t 3 /nobreak > nul

:: Iniciar QEMU
echo [2/3] Iniciando VM QEMU...
echo   - RAM: 2048 MB
echo   - CPUs: 2
echo   - Disco: %QEMU_DIR%\alpine-podman.qcow2
echo   - Puertos redirigidos:
echo       * SSH: 2222 -^> 22
echo       * API: 8084 -^> 8084
echo.
start "QEMU - Alpine VM" cmd /k "%RUN_QEMU%"

echo [3/3] Procesos iniciados correctamente
echo.
echo Resumen:
echo   - Servidor HTTP: http://localhost:8000 (ventana aparte)
echo   - VM QEMU: Ventana grafica abierta
echo   - SSH disponible: ssh -p 2222 root@localhost
echo   - Kafka: localhost:9092
echo   - Schema Registry: localhost:8081
echo   - Kafka-UI: localhost:8085 (si lo instalaste en Windows)
echo.
pause
goto menu

:iniciar_http
cls
echo ================================================
echo    INICIANDO SOLO SERVIDOR HTTP
echo ================================================
echo.

if "%PROYECTO%"=="" goto configurar_rutas

echo Iniciando servidor HTTP en el puerto 8000...
echo Proyecto: %PROYECTO%
echo URL: http://localhost:8000
echo.
start "Servidor HTTP" cmd /k "cd /d "%PROYECTO%" && echo Servidor HTTP corriendo en http://localhost:8000 && python -m http.server 8000"
echo Servidor HTTP iniciado en ventana separada
pause
goto menu

:iniciar_vm
cls
echo ================================================
echo    INICIANDO SOLO VM QEMU
echo ================================================
echo.

if "%QEMU_DIR%"=="" goto configurar_rutas

echo Iniciando VM QEMU...
echo   - RAM: 2048 MB
echo   - CPUs: 2
echo   - Disco: %QEMU_DIR%\alpine-podman.qcow2
echo   - Puertos:
echo       * SSH: 2222 -^> 22
echo       * API: 8084 -^> 8084
echo       * Kafka: 9092 -^> 9092
echo       * Schema Registry: 8081 -^> 8081
echo.
start "QEMU - Alpine VM" cmd /k "%RUN_QEMU%"
echo VM iniciada en ventana separada
pause
goto menu

:detener_http
cls
echo ================================================
echo    DETENIENDO SERVIDOR HTTP
echo ================================================
echo.
echo Buscando procesos de Python en el puerto 8000...
for /f "tokens=5 delims= " %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
    set PID=%%a
    echo Encontrado proceso con PID: !PID!
    taskkill /F /PID !PID! 2>nul && echo Proceso detenido
)
echo.
echo Servidor HTTP detenido (si estaba corriendo)
pause
goto menu

:salir
cls
echo Deteniendo servidor HTTP...
for /f "tokens=5 delims= " %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do taskkill /F /PID %%a 2>nul
echo Deteniendo QEMU...
taskkill /F /IM qemu-system-x86_64.exe 2>nul
echo Saliendo...
exit
