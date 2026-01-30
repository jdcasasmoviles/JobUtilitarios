@echo off
title Gestor Interactivo de Apache Kafka v6
color 0A
setlocal ENABLEDELAYEDEXPANSION

:: === CONFIGURACION ===
set KAFKA_HOME=C:\kafka
set ZK_CONFIG=%KAFKA_HOME%\config\zookeeper.properties
set KF_CONFIG=%KAFKA_HOME%\config\server.properties
set BOOTSTRAP=localhost:9092
set LOGFILE=%KAFKA_HOME%\kafka_manager.log

:: === VALIDAR ENTORNO ===
if not exist "%KAFKA_HOME%\bin\windows\kafka-server-start.bat" (
    color 0C
    echo ❌ ERROR: No se encontro Apache Kafka en %KAFKA_HOME%.
    echo Corrige la ruta antes de continuar.
    pause
    exit /b
)

:MENU
cls
color 0A
echo ================================================
echo       === Apache Kafka Manager v6 ===
echo ================================================
echo Hora actual: %time%
echo.
echo [1] Iniciar Zookeeper y Kafka
echo [2] Gestionar Topicos
echo [3] Consumir mensajes
echo [4] Producir mensajes
echo [5] Ver ultimos N mensajes
echo [6] Detener servicios
echo [7] Salir
echo ================================================
set /p opcion=Selecciona una opcion: 
echo [%date% %time%] Opcion %opcion% ejecutada >> "%LOGFILE%"

if "%opcion%"=="1" goto INICIAR
if "%opcion%"=="2" goto TOPICOS
if "%opcion%"=="3" goto CONSUMIR
if "%opcion%"=="4" goto PRODUCIR
if "%opcion%"=="5" goto VER_MENSAJES
if "%opcion%"=="6" goto DETENER
if "%opcion%"=="7" exit
goto MENU

:INICIAR
cls
echo === Iniciando servicios ===
tasklist /FI "IMAGENAME eq java.exe" | find /I "java.exe" >nul
if %errorlevel%==0 (
    color 0E
    echo ⚠️ Kafka o Zookeeper ya estan ejecutandose.
    pause
    goto MENU
)
echo.
echo 🚀 Iniciando Zookeeper...
start "Zookeeper" cmd /c "cd /d %KAFKA_HOME% && bin\windows\zookeeper-server-start.bat %ZK_CONFIG%"
timeout /t 5 >nul
echo 🧩 Iniciando Kafka Broker...
start "Kafka Broker" cmd /c "cd /d %KAFKA_HOME% && bin\windows\kafka-server-start.bat %KF_CONFIG%"
echo ✅ Servicios iniciados correctamente.
pause
goto MENU

:TOPICOS
cls
color 0B
echo === Gestion de Topicos ===
echo [1] Listar topicos
echo [2] Crear un topico
echo [3] Describir un topico
echo [4] Eliminar un topico
echo [5] Volver al menu principal
echo ================================================
set /p toptask=Selecciona una opcion: 
if "%toptask%"=="1" goto LISTAR
if "%toptask%"=="2" goto CREAR
if "%toptask%"=="3" goto DESCRIBIR
if "%toptask%"=="4" goto ELIMINAR
if "%toptask%"=="5" goto MENU
goto TOPICOS

:LISTAR
cls
echo === Topicos existentes ===
cd /d %KAFKA_HOME%
set count=0
for /f "tokens=*" %%A in ('bin\windows\kafka-topics.bat --list --bootstrap-server %BOOTSTRAP%') do (
    echo   %%A
    set /a count+=1
)
echo.
echo Total de topicos: !count!
echo.
echo (Presiona una tecla para volver al menu...)
pause >nul
goto TOPICOS

:CREAR
cls
echo === Crear un nuevo topico ===
set /p topico=Nombre del topico: 
if "%topico%"=="" goto TOPICOS
set /p particiones=Numero de particiones [1]: 
if "%particiones%"=="" set particiones=1
set /p replicas=Factor de replicacion [1]: 
if "%replicas%"=="" set replicas=1
cd /d %KAFKA_HOME%
echo Creando topico "%topico%" ...
bin\windows\kafka-topics.bat --create --topic %topico% --partitions %particiones% --replication-factor %replicas% --bootstrap-server %BOOTSTRAP%
echo [%date% %time%] Topico creado: %topico% >> "%LOGFILE%"
pause
goto TOPICOS

:DESCRIBIR
cls
echo === Describir un topico ===
set /p topico=Nombre del topico: 
if "%topico%"=="" goto TOPICOS
cd /d %KAFKA_HOME%
bin\windows\kafka-topics.bat --describe --topic %topico% --bootstrap-server %BOOTSTRAP%
pause
goto TOPICOS

:ELIMINAR
cls
echo === Eliminar un topico ===
set /p topico=Nombre del topico a eliminar: 
if "%topico%"=="" goto TOPICOS
echo ⚠️ Estas seguro que deseas eliminar el topico "%topico%"? (S/N)
set /p confirm=
if /I "%confirm%"=="S" (
    cd /d %KAFKA_HOME%
    bin\windows\kafka-topics.bat --delete --topic %topico% --bootstrap-server %BOOTSTRAP%
    echo [%date% %time%] Topico eliminado: %topico% >> "%LOGFILE%"
    echo ✅ Topico eliminado.
) else (
    echo Operacion cancelada.
)
pause
goto TOPICOS

:CONSUMIR
cls
color 0A
echo === Topicos disponibles ===
cd /d %KAFKA_HOME%
for /f "tokens=*" %%A in ('bin\windows\kafka-topics.bat --list --bootstrap-server %BOOTSTRAP%') do echo   %%A
echo.
set /p topico=Topico a consumir: 
if "%topico%"=="" goto MENU
cls
echo === Consumiendo mensajes de "%topico%" (Ctrl+C para volver) ===
cd /d %KAFKA_HOME%
bin\windows\kafka-console-consumer.bat --topic %topico% --from-beginning --bootstrap-server %BOOTSTRAP%
echo === Fin de mensajes ===
pause
goto MENU

:PRODUCIR
cls
color 0A
echo === Topicos disponibles ===
cd /d %KAFKA_HOME%
for /f "tokens=*" %%A in ('bin\windows\kafka-topics.bat --list --bootstrap-server %BOOTSTRAP%') do echo   %%A
echo.
set /p topico=Topico a producir: 
if "%topico%"=="" goto MENU
cls
echo === Escribe mensajes para "%topico%" (Ctrl+C para volver) ===
cd /d %KAFKA_HOME%
bin\windows\kafka-console-producer.bat --topic %topico% --broker-list %BOOTSTRAP%
goto MENU

:VER_MENSAJES
cls
echo === Ver ultimos N mensajes ===
set /p topico=Nombre del topico: 
if "%topico%"=="" goto MENU
set /p cantidad=Numero de mensajes [10]: 
if "%cantidad%"=="" set cantidad=10
cls
echo === Mostrando los ultimos %cantidad% mensajes de "%topico%" ===
cd /d %KAFKA_HOME%
bin\windows\kafka-console-consumer.bat --topic %topico% --bootstrap-server %BOOTSTRAP% --from-beginning --max-messages %cantidad%
echo === Fin de los mensajes ===
pause
goto MENU

:DETENER
cls
echo === Deteniendo servicios ===
taskkill /IM java.exe /F >nul 2>&1
echo ✅ Todos los servicios han sido detenidos.
echo [%date% %time%] Servicios detenidos >> "%LOGFILE%"
pause
goto MENU
