@echo off
title Ejecutor de 10 Pruebas JMeter para 200 TPS
chcp 65001 >nul
:: --- CONFIGURACIÓN: ¡CAMBIAR ESTAS RUTAS! ---
set "JMETER_HOME=C:\ruta\a\apache-jmeter-5.6.3"
set "RUTA_JMX=C:\ruta\a\tu\archivo.jmx"
set "RUTA_BASE_RESULTADOS=C:\ruta\a\resultados_pruebas"
:: ---------------------------------------------

set "EJECUCIONES=10"
set "CONTADOR=1"

echo =========================================
echo Iniciando %EJECUCIONES% ejecuciones de JMeter
echo Script JMX: %RUTA_JMX%
echo Resultados en: %RUTA_BASE_RESULTADOS%
echo =========================================

:loop
if %CONTADOR% gtr %EJECUCIONES% goto fin

echo.
echo --- Iniciando Ejecución %CONTADOR% de %EJECUCIONES% ---

:: Definir nombres de archivo/carpeta únicos para esta ejecución
set "NOMBRE_UNICO=ejecucion_%CONTADOR%_%date:~-4,4%%date:~-10,2%%date:~-7,2%_%time:~0,2%%time:~3,2%%time:~6,2%"
:: Limpiar posibles espacios en la hora (cuando la hora es de 1 dígito, ej: " 9:30:00")
set "NOMBRE_UNICO=%NOMBRE_UNICO: =0%"

set "ARCHIVO_JTL=%RUTA_BASE_RESULTADOS%\%NOMBRE_UNICO%\resultados.jtl"
set "CARPETA_REPORTE=%RUTA_BASE_RESULTADOS%\%NOMBRE_UNICO%\reporte_html"

:: Crear la carpeta para esta ejecución
mkdir "%RUTA_BASE_RESULTADOS%\%NOMBRE_UNICO%" 2>nul

echo Ejecutando: %JMETER_HOME%\bin\jmeter -n -t "%RUTA_JMX%" -l "%ARCHIVO_JTL%" -e -o "%CARPETA_REPORTE%"

:: Ejecutar JMeter en modo no-GUI
"%JMETER_HOME%\bin\jmeter" -n -t "%RUTA_JMX%" -l "%ARCHIVO_JTL%" -e -o "%CARPETA_REPORTE%"

:: Verificar si la ejecución fue exitosa
if %errorlevel% equ 0 (
    echo [OK] Ejecución %CONTADOR% completada. Reporte HTML generado en: %CARPETA_REPORTE%
) else (
    echo [ERROR] Falló la ejecución %CONTADOR%. Revisa los logs.
)

:: Incrementar el contador y pausar brevemente antes de la siguiente ejecución (opcional)
set /a CONTADOR+=1
timeout /t 5 /nobreak >nul

goto loop

:fin
echo.
echo =========================================
echo Proceso completado. Se realizaron %EJECUCIONES% ejecuciones.
echo =========================================
pause