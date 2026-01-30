@echo off
title Gestor Interactivo de Apache Kafka v4
color 0A

:: === CONFIGURACION ===
set KAFKA_HOME=C:\kafka
set ZK_CONFIG=%KAFKA_HOME%\config\zookeeper.properties
set KF_CONFIG=%KAFKA_HOME%\config\server.properties
set BOOTSTRAP=localhost:9092

:MENU
cls
echo ================================================
echo         === Apache Kafka Manager v5 ===
echo ================================================
echo [1] Iniciar Zookeeper y Kafka
echo [2] Listar topicos
echo [3] Crear un topico
echo [4] Consumir mensajes (desde inicio)
echo [5] Producir mensajes
echo [6] Ver ultimos 10 mensajes
echo [7] Detener todos los servicios
echo [8] Salir
echo ================================================
set /p opcion=Selecciona una opcion: 

if "%opcion%"=="1" goto INICIAR
if "%opcion%"=="2" goto LISTAR
if "%opcion%"=="3" goto CREAR
if "%opcion%"=="4" goto CONSUMIR
if "%opcion%"=="5" goto PRODUCIR
if "%opcion%"=="6" goto VER_MENSAJES
if "%opcion%"=="7" goto DETENER
if "%opcion%"=="8" exit
goto MENU

:INICIAR
cls
echo === Iniciando Zookeeper ===
start "Zookeeper" cmd /c "cd /d %KAFKA_HOME% && bin\windows\zookeeper-server-start.bat %ZK_CONFIG%"
timeout /t 5 >nul
echo === Iniciando Kafka Broker ===
start "Kafka Broker" cmd /c "cd /d %KAFKA_HOME% && bin\windows\kafka-server-start.bat %KF_CONFIG%"
echo ✅ Servicios iniciados correctamente
pause
goto MENU

:LISTAR
cls
echo === Topicos existentes ===
cd /d %KAFKA_HOME%
for /f "tokens=*" %%A in ('bin\windows\kafka-topics.bat --list --bootstrap-server %BOOTSTRAP%') do echo   %%A
echo.
echo ================================================
echo (Presiona una tecla para volver al menu...)
pause >nul
goto MENU

:CREAR
cls
echo === Crear un nuevo topico ===
set /p topico=Nombre del topico: 
if "%topico%"=="" (
  echo ⚠️  No se ingreso nombre, regresando al menu...
  timeout /t 2 >nul
  goto MENU
)
set /p particiones=Numero de particiones [1]: 
if "%particiones%"=="" set particiones=1
set /p replicas=Factor de replicacion [1]: 
if "%replicas%"=="" set replicas=1
cd /d %KAFKA_HOME%
echo Creando topico "%topico%" ...
for /f "tokens=*" %%A in ('bin\windows\kafka-topics.bat --create --topic %topico% --partitions %particiones% --replication-factor %replicas% --bootstrap-server %BOOTSTRAP%') do echo   %%A
echo.
echo ================================================
echo (Presiona una tecla para volver al menu...)
pause >nul
goto MENU

:CONSUMIR
cls
echo === Topicos disponibles ===
cd /d %KAFKA_HOME%
for /f "tokens=*" %%A in ('bin\windows\kafka-topics.bat --list --bootstrap-server %BOOTSTRAP%') do echo   %%A
echo.
set /p topico=Nombre del topico a CONSUMIR: 
if "%topico%"=="" goto MENU
cls
echo === Consumiendo mensajes del topico "%topico%" (Ctrl+C para detener) ===
echo.
cd /d %KAFKA_HOME%
bin\windows\kafka-console-consumer.bat --topic %topico% --from-beginning --bootstrap-server %BOOTSTRAP% --property print.value=true --property print.key=false --property value.deserializer=org.apache.kafka.common.serialization.StringDeserializer
goto MENU

:PRODUCIR
cls
echo === Topicos disponibles ===
cd /d %KAFKA_HOME%
for /f "tokens=*" %%A in ('bin\windows\kafka-topics.bat --list --bootstrap-server %BOOTSTRAP%') do echo   %%A
echo.
set /p topico=Nombre del topico a PRODUCIR: 
if "%topico%"=="" goto MENU
cls
echo === Escribe mensajes para el topico "%topico%" (Ctrl+C para salir) ===
echo.
cd /d %KAFKA_HOME%
bin\windows\kafka-console-producer.bat --topic %topico% --broker-list %BOOTSTRAP% --property parse.key=false --property key.separator=:
goto MENU

:VER_MENSAJES
cls
echo === Topicos disponibles ===
cd /d %KAFKA_HOME%
for /f "tokens=*" %%A in ('bin\windows\kafka-topics.bat --list --bootstrap-server %BOOTSTRAP%') do echo   %%A
echo.
echo === Ver ultimos 10 mensajes de un topico ===
set /p topico=Nombre del topico: 
if "%topico%"=="" goto MENU
echo.
echo === Ultimos 10 mensajes del topico "%topico%" ===
bin\windows\kafka-console-consumer.bat --bootstrap-server %BOOTSTRAP% --topic %topico% --from-beginning --max-messages 10
echo.
echo === Fin de los mensajes ===
pause
goto MENU

:DETENER
cls
echo === Deteniendo Kafka y Zookeeper ===
taskkill /IM java.exe /F >nul 2>&1
echo ✅ Todos los servicios han sido detenidos.
pause
goto MENU
