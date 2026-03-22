@echo off
title GESTOR DE VM - SERVIDOR HTTP - SSH INTEGRADO
color 0A
setlocal enabledelayedexpansion

:: Variables setear rutas de proyecto y qemu
set PROYECTO=C:\Users\UsuarioPC\Documents\REPOSITORIO\tarea-processor
set QEMU_DIR=C:\Users\UsuarioPC\Documents\REPOSITORIO\Utilitarios\qemu_app
:: Variables globales para rutas (inicializadas con valores por defecto)
set DISCO_IMG=%QEMU_DIR%\alpine-disk.qcow2
set RUN_QEMU=%QEMU_DIR%\qemu-system-x86_64.exe -m 4096 -smp 4 -hda %DISCO_IMG% -vga std -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080,hostfwd=tcp::8086-:8086,hostfwd=tcp::9092-:9092,hostfwd=tcp::8081-:8081 -device e1000,netdev=net0 -display none

:menu
cls
echo =====================================================================
echo    GESTOR DE VM - SERVIDOR HTTP - SSH INTEGRADO (VENTANA UNICA)
echo =====================================================================
echo.
echo.
echo CONFIGURACION ACTUAL:
echo   - Proyecto: %PROYECTO%
echo   - QEMU: %QEMU_DIR%\qemu-system-x86_64.exe
echo   - Disco: %DISCO_IMG%
echo.
echo =====================================================================
echo.
echo  1 INICIAR TODO (HTTP + VM + SSH)
echo  2 CONECTAR SSH A VM
echo  3 SALIR

echo.
echo =====================================================================
echo NOTAS: 
echo   - Kafka-UI: http://localhost:8086
echo.
echo =====================================================================
echo.
set /p opcion="Selecciona una opcion: "

if "%opcion%"=="1" goto iniciar_todo
if "%opcion%"=="2" goto conectar_ssh
if "%opcion%"=="3" goto salir

echo Opcion no valida
pause
goto menu

:: Función para verificar si QEMU está corriendo
:check_qemu
:: Obtener el resultado y guardarlo en variable
tasklist /FI "IMAGENAME eq qemu-system-x86_64.exe" | find "qemu" > nul
if "%ERRORLEVEL%"=="0" (
    set QEMU_RUNNING=1
) else (
    set QEMU_RUNNING=0
)
exit /b

:iniciar_todo
cls
echo ================================================
echo    INICIANDO TODO (HTTP + VM + SSH)
echo ================================================
echo.

:: Verificar que las rutas están configuradas
if "%PROYECTO%"=="" (
    echo ERROR: Ruta de proyecto no configurada
    pause
    goto menu
)

:: Paso 1: Iniciar servidor HTTP
echo  1 Iniciando servidor HTTP en el puerto 8000...
echo Proyecto: %PROYECTO%
cd /d "%PROYECTO%"
start /b python -m http.server 8000 > nul 2>&1
echo   Servidor HTTP iniciado en background (http://localhost:8000)

:: Paso 2: Iniciar VM QEMU
echo  2 Iniciando VM QEMU en background...
call :check_qemu
if %QEMU_RUNNING%==0 (
    start /b %RUN_QEMU% > nul 2>&1
    echo.
    set /a contador=0
    for /l %%i in (1,1,46) do (
        set /a contador+=1
        set /p=">" < nul
        timeout /t 1 /nobreak > nul
    )
    call :check_qemu
    if !QEMU_RUNNING!==1 (
		echo   VM OK - Conectando SSH...
		call :conectar_ssh
	) else (
		echo   VM iniciando, espera unos segundos más...
	)
) else (
    echo   VM ya estaba en ejecución
)

echo ================================================
echo    TODO INICIADO CORRECTAMENTE
echo ================================================
pause
goto menu

:conectar_ssh
cls
echo ================================================
echo    CONECTANDO SSH A VM
echo ================================================
echo.

echo Conectando a root@localhost:2222...
echo Para ejecutar comandos directamente escribe 'exit' para volver al menu
echo.
echo COMANDOS UTILES:
echo   - ./executor_project.sh
echo   - poweroff (para apagar VM)
echo.
ssh -p 2222 root@localhost

echo.
echo Conexion SSH finalizada
pause
goto menu

:salir
cls
echo ================================================
echo    LIMPIANDO Y SALIENDO
echo ================================================
echo.
echo Deteniendo servicios...
:: Detener HTTP
for /f "tokens=5 delims= " %%a in ('netstat -ano ^| findstr :8000 ^| findstr LISTENING') do (
        taskkill /F /PID %%a 2>nul
)
:: Detener QEMU
taskkill /F /IM qemu-system-x86_64.exe 2>nul
echo Servicios detenidos
echo.
echo Saliendo del gestor...
timeout /t 2 /nobreak > nul
exit
