## Descargar prometheus
https://github.com/prometheus/prometheus/releases/tag/v2.35.0
prometheus-2.35.0.windows-amd64.zip

## conigurar prometheus.yml
scrape_configs:
  # The job name is added as a label `job=<job_name>` to any timeseries scraped from this config.
  - job_name: "jdc_microservicio"

    # metrics_path defaults to '/metrics'
    # scheme defaults to 'http'.

    # Intervalo con el que Prometheus preguntará por las métricas
    scrape_interval: 10s
    # Ruta donde tu app Quarkus expone las métricas
    metrics_path: /q/metrics
    static_configs:
      # La dirección y puerto donde corre tu microservicio
      - targets: ['localhost:8084']

## ejecutar
cd C:\Users\UsuarioPC\Downloads\prometheus-2.35.0.windows-amd64
.\prometheus.exe --config.file=prometheus.yml
http://localhost:9090/graph

 ## Grafana
 https://grafana.com/grafana/download/8.5.0?platform=windows
 grafana-enterprise-8.5.0.windows-amd64.zip

## ejecutar
 cd C:\Users\UsuarioPC\Downloads\grafana-enterprise-8.5.0.windows-amd64\grafana-8.5.0\bin
.\grafana-server.exe
http://localhost:3000/
credenciales
admin
admin
## datasource
Selecciona en el sidebar :
- Configuración
- Datasources
- Add datasource
- Selecciona Prometheus
- Name = Prometheus
- Url = http://localhost:9090
dar click save&test
## Importa un Dashboard para Quarkus

Lo más rápido es importar un dashboard ya hecho por la comunidad. Uno excelente para aplicaciones 
Quarkus con Micrometer es el de la comunidad de Grafana Labs .
En Grafana, ve a Dashboards -> Import.
En el campo "Import via grafana.com", introduce el ID del dashboard. Un ID muy popular y completo para JVM 
y Quarkus es el 14370 (JVM Quarkus - Micrometer Metrics) .
Haz clic en "Load".
En el desplegable que aparece abajo, selecciona la fuente de datos Prometheus que acabas de crear.
Haz clic en "Import".
---------------------------------------------------------------------------------------------------------------

## Jmeter
https://jmeter.apache.org/download_jmeter.cgi
descargar
apache-jmeter-5.6.3.zip
jmeter.bat

