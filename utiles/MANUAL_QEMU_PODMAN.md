# GUÍA COMPLETA: Contenedores en Windows sin admin, Hyper-V ni WSL2 usando QEMU + Alpine + Podman
# Usando QEMU Portable + Alpine Linux + Podman + podman-compose
# ======= FASE 1: Preparación en Windows ==========================================================================

Descargar QEMU Portable
Descarga el archivo: qemu-w64-portable-XXXXXX.7z (la versión más reciente)
Ve a: https://github.com/dirkarnez/qemu-portable/releases
El que se uso fue :
qemu-w64-portable-20240822.zip
Extrae el contenido en una carpeta, por ejemplo: C:\QEMU
# valida version de quemu
qemu-system-x86_64.exe --version

Descargar Alpine Linux
Ve a: https://alpinelinux.org/downloads/
Descarga la imagen ISO para x86_64: alpine-standard-3.23.3-x86_64.iso
Guárdala en la misma carpeta C:\QEMU

# ======= FASE 2: Crear la VM ===========================================================================================
Abre Símbolo del sistema (cmd) y ejecuta:
cmd
cd C:\QEMU
# crear disco para VM Linux
qemu-img create -f qcow2 alpine-podman.qcow2 20G
# Arranca la VM con la iso de instalacion
qemu-system-x86_64 -m 2048 -smp 2 -hda alpine-podman.qcow2 -cdrom alpine-standard-3.23.3-x86_64.iso -boot d -vga std -netdev user,id=net0 -device e1000,netdev=net0
# Realizar la Instalación de Alpine:
Se abrirá una nueva ventana con la máquina virtual. Inicia sesión con el usuario root ,pasword enter (no necesitará contraseña).
# En la consola de la MV, ejecuta el comando de instalación:
setup-alpine
# El instalador te guiará con una serie de preguntas. Estas son las opciones más comunes. 
# Presiona Enter para aceptar el valor por defecto (entre corchetes []) cuando no estés seguro.

Select keyboard layout: Elige tu distribución de teclado. Lo más común es escribir us o es y presionar Enter.
Enter system hostname: Ponle un nombre a tu máquina virtual, por ejemplo: alpine-podman.
Which one do you want to initialize? (or '?' for list): Simplemente presiona Enter para inicializar todas las interfaces de red.
Ip address for eth0? (or 'dhcp'): Escribe dhcp y presiona Enter para que obtenga una IP automáticamente.
Do you want to do any manual network configuration?: Escribe no.
New password: Establece una contraseña para el usuario root. Escríbela dos veces.
Which timezone are you in?: Especifica tu zona horaria, por ejemplo: America/Santiago o Europe/Madrid.
Which HTTP proxy (URL) you want to use?: Déjalo en blanco y presiona Enter.
Which NTP client to run?: Elige chrony (o el que venga por defecto).
Enter mirror number (1-xx) or URL to fetch: Elige un número de servidor mirror cercano a tu ubicación para descargas rápidas (por ejemplo, el de tu país).
Which SSH server? ('openssh') Elige openssh.
Which disk(s) you would like to use?: Escribe sda (que es el nombre de tu disco duro virtual) y presiona Enter.
How would you like to use it?: Elige sys (para una instalación completa en el disco).
WARNING: Erase the above disk(s) and continue?: Confirma escribiendo y.
El instalador copiará los archivos. Al finalizar, te preguntará You might run 'setup-bootable'.... La instalación ha terminado. Apaga la máquina virtual ejecutando:
poweroff

# ======= FASE 3: Configuración de Red y SSH para Acceso Cómodo============================================================================
# Ahora que Alpine está instalado en el disco, ya no necesitas arrancar desde la ISO. Usa este comando para iniciar la MV:
qemu-system-x86_64 -m 2048 -smp 2 -hda alpine-podman.qcow2 -vga std -netdev user,id=net0,hostfwd=tcp::2222-:22 -device e1000,netdev=net0

Nota sobre el nuevo parámetro: hostfwd=tcp::2222-:22 es crucial. Redirige el tráfico del puerto 2222 de tu PC (Windows) al puerto 22 (SSH) de la máquina virtual. Así podrás conectarte vía SSH a localhost en el puerto 2222.
Inicia sesión en la MV como root con la contraseña que configuraste.
# Instalar y Configurar un Editor de Texto: vi puede ser complejo. Instalaremos nano, que es más amigable.
apk add nano
# Configurar el Servidor SSH:
Edita el archivo de configuración de SSH para permitir el acceso como root (solo para facilitar este tutorial, en un entorno real sería más seguro crear un usuario normal).
nano /etc/ssh/sshd_config
# Busca la línea que dice #PermitRootLogin prohibit-password o similar. Cámbiala por:
PermitRootLogin yes
# Guarda el archivo (Ctrl+O, Enter) y sal de nano (Ctrl+X).
# Asegúrate de que el servidor SSH se inicie automáculinamente al arrancar el sistema.
rc-update add sshd default
# Inicia el servicio SSH ahora mismo.
/etc/init.d/sshd start
# Verifica la dirección IP de la MV con el comando
 ip a. 
 Normalmente será algo como 10.0.2.15, pero como usaremos el reenvío de puertos, nos conectaremos a localhost.
# reiniciar la MV
reboot

# ======= FASE 4: Instalación de Podman y dependencias============================================================================
# Habilitar repositorio community
nano /etc/apk/repositories
Descomenta la línea que termina en community (quita el #). Guarda y sal.
# Instalar paquetes necesarios
apk update
apk add podman podman-compose iptables iptables-openrc netavark aardvark-dns cni-plugins
# Configurar iptables y red
# Habilitar forwarding
echo "net.ipv4.ip_forward=1" >> /etc/sysctl.conf
sysctl -w net.ipv4.ip_forward=1
# Configurar iptables
rc-update add iptables default
rc-service iptables start
iptables -P FORWARD ACCEPT
iptables -t nat -F
iptables -F
rc-service iptables save
# Configurar Podman para usar netavark
mkdir -p /etc/containers
cat > /etc/containers/containers.conf << EOF
[network]
network_backend = "netavark"
EOF
# Crear enlaces para netavark
bash
ln -s /usr/libexec/podman/netavark /usr/local/bin/netavark
ln -s /usr/libexec/podman/aardvark-dns /usr/local/bin/aardvark-dns
# Iniciar el servicio de Podman
mkdir -p /run/podman
pkill podman
rm -f /run/podman/podman.sock
podman system service --time=0 unix:///run/podman/podman.sock &
# Probar Podman y crear primer docker-compose.yml
Verificar instalación
podman version
podman info | grep -A5 network
netavark --version

# ======= FASE 5: Instalacion de compose ============================================================================
# Instalación de Podman y Herramientas de Compose
# Conectamos por ssh ,desde un cmd de windows
ssh -p 2222 root@localhost
# Podman necesita el servicio cgroups para funcionar correctamente 
# Añadir cgroups al arranque
rc-update add cgroups default
# Iniciar el servicio ahora
rc-service cgroups start
# Verificar la instalación
podman --version
podman info
# Verificar que estás conectado a internet
ping -c 4 github.com
# Instalar curl (si no lo tienes)
apk add curl
# Crear el directorio si no existe
mkdir -p /usr/local/bin
# Descargar la última versión estable de docker-compose
# (Nota: usa v2.24.5 que es una versión estable reciente)
curl -SL https://github.com/docker/compose/releases/download/v2.24.5/docker-compose-linux-x86_64 -o /usr/local/bin/docker-compose
# Dar permisos de ejecución
chmod +x /usr/local/bin/docker-compose
# Verificar la versión instalada
docker-compose --version
# Instalar podman-compose
apk add podman-compose
# Activar el módulo de iptables en el kernel
modprobe iptables
modprobe ip6tables


# ======= FASE 6: Probando podman ============================================================================
# Crear proyecto de prueba
mkdir ~/test-compose
cd ~/test-compose
# Crear docker-compose.yml
cat > docker-compose.yml << EOF
services:
  web:
    image: docker.io/nginx:alpine
    ports:
      - "8080:80"
EOF
# Levantar el contenedor
podman-compose up -d
# Verificar dentro de la VM
podman ps
curl localhost:8080
# Deberías ver el HTML de bienvenida de nginx.
Acceso desde Windows.Desde el navegador en Windows.
Abre cualquier navegador y ve a:
http://localhost:8080
# DEBERÍAS VER "Welcome to nginx!"

# ======= FASE 7: Comandos utiles ============================================================================
# En Windows (para iniciar la VM):
cd C:\QEMU
qemu-system-x86_64 -m 2048 -smp 2 -hda alpine-podman.qcow2 -vga std -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8084-:8084 -device e1000,netdev=net0
# Para conectar por SSH:
ssh -p 2222 root@localhost
# Dentro de la VM (gestión de contenedores):
podman-compose up -d        # Levantar servicios
podman-compose down         # Detener servicios
podman-compose ps           # Ver estado
podman-compose logs         # Ver logs
podman ps                   # Ver contenedores
podman images               # Ver imágenes
# Posibles errores y soluciones rápidas
Error	                                                Solución
cannot connect to localhost:8080	                    Verificar que QEMU se inició con hostfwd=tcp::8080-:8080
network not found	                                    Ejecutar podman network create test-compose_default
iptables: No such file or directory	                  Instalar iptables: apk add iptables iptables-openrc
cni support is not enabled	                          Configurar netavark en /etc/containers/containers.conf
bind: no such file or directory	                      Crear directorio: mkdir -p /run/podman

# ======= FASE 8: CONCLUSIÓN ==============================================================================================
Has construido un sistema completo de contenedores portable, sin necesidad de privilegios de administrador, y completamente funcional en Windows.
¡Felicidades! Este conocimiento te permite ahora:
Desarrollar con contenedores en cualquier PC Windows
Usar docker-compose.yml sin modificar nada
Tener un entorno reproducible y portable (puedes copiar la carpeta QEMU y el disco .qcow2 a un USB y llevarlo a cualquier PC


#  =======DIAGNOSTICO ==============================================================================================
## Inicia servicios manualmente
podman start kafka
podman logs -f kafka

podman start schema-registry
podman logs -f schema-registry

podman start topic-jdc-processor
podman logs -f topic-jdc-processor

podman logs -f zookeeper
podman logs app

------------------------------------------------------------------------------------
# Ver logs de Zookeeper (debería estar completamente iniciado)
podman logs zookeeper --tail 20

# Ver logs de Kafka (el más importante)
podman logs kafka --tail 30

# Ver logs de Schema Registry
podman logs schema-registry --tail 20

# Ver logs de tu app
podman logs topic-jdc-processor --tail 20
---------------------------------------------------------------------------------------
# Ver logs completos de kafka
podman logs kafka --tail 50
# erificar que kafka está realmente funcionando
podman exec kafka kafka-topics --bootstrap-server localhost:9092 --list
# Ver el estado actual de todos los contenedores
podman ps -a

## Verificar conectividad entre servicios:
# Desde kafka, probar conexión a zookeeper
podman exec kafka nc -zv zookeeper 2181
# Probar que kafka puede crear un tópico
podman exec kafka kafka-topics --bootstrap-server localhost:9092 --create --topic test-topic --partitions 1 --replication-factor 1
# Listar tópicos
podman exec kafka kafka-topics --bootstrap-server localhost:9092 --list

## Prueba rapida de servicios OK
# Probar Kafka (listar tópicos)
podman exec kafka kafka-topics --bootstrap-server localhost:9092 --list
# Probar Schema Registry
curl http://localhost:8081/subjects
# Probar tu API
curl http://localhost:8080/api/v1/task


-----------------------------------------------------------------------------------------------

-------------------------------------------------------------------------------------------------
----------------------------------------------------------------------------------------------------------------
------------------------------BONUS------------------------------------------------------------------------------------
------------------------------------------------------------------
# Ruta del proyecto
C:\Users\UsuarioPC\Documents\REPOSITORIO\api-tipocambio-moneda
# Levantar HTTP SERVER PYTHON
python -m http.server 8000
# conectar mediante ssh
ssh -p 2222 root@localhost
# Eliminar todos los contenedores (forzado)
podman rm -f -a && podman rmi -f -a

# Elimina contenedores 
for /f %i in ('docker ps -aq') do docker rm -f %i
# Elimina imagenes
for /f %i in ('docker images -q') do docker rmi -f %i
# Elimina los directorios
rm -rf /root/spring-project/* && mkdir -p /root/spring-project/target
# Descargar archivos a VM
rm -rf /root/spring-project/executor_project.sh && cd /root/spring-project && wget http://10.0.2.2:8000/executor_project.sh
cd /root/spring-project && wget http://10.0.2.2:8000/docker-compose.yml
cd /root/spring-project && wget http://10.0.2.2:8000/executor_clean.sh
cd /root/spring-project && wget http://10.0.2.2:8000/Dockerfile
cd /root/spring-project && wget http://10.0.2.2:8000/target/quarkus-app/quarkus-run.jar
cd /root/spring-project/target/quarkus-app && wget http://10.0.2.2:8000/target/quarkus-app/quarkus-run.jar
## Ejecutando podman con Dockerfile
podman build -t mi-app .
podman run -d -p 8084:8084 --name mi-app-container mi-app
podman logs -f mi-app-container
## Ejecutando docker con Dockerfile
docker build -t mi-app .
docker run -d -p 8084:8084 --name mi-app-container mi-app
docker logs -f mi-app-container
##  Entrar al contenedor
# Ejecuta un shell interactivo en el contenedor (aunque haya fallado)
podman run -it --entrypoint /bin/sh mi-app
# Ver el directorio actual
pwd
# Listar archivos
ls -la
# Ver si existe quarkus-run.jar
find / -name "quarkus-run.jar" 2>/dev/null
# Salir del contenedor
exit

# Descargar el JAR con SNAPSHOT en el nombre.Primero, obtén la lista de archivos en target
wget -q -O- http://10.0.2.2:8000/target/ | grep -o 'href="[^"]*SNAPSHOT[^"]*\.jar"' | sed 's/href="//;s/"//' | while read jarfile; do
    echo "Descargando: $jarfile"
    wget "http://10.0.2.2:8000/target/$jarfile" -P target/
done
# Descargar el JAR con qurkus-run en el nombre.Primero, obtén la lista de archivos en target/quarkus-app/
wget -q -O- http://10.0.2.2:8000/target/quarkus-app/ | grep -o 'href="[^"]*quarkus-run\.jar"' | sed 's/href="//;s/"//' | while read jarfile; do
    echo "Descargando: $jarfile"
    wget "http://10.0.2.2:8000/target/quarkus-app/$jarfile" -O "target/quarkus-app/$jarfile"
done
# Ejecuta podman-composese,se observa procesos en segundo plano
podman-compose up
# Ejecuta podman-compose
podman-compose up -d

# =======================================================================================================================================================================
# ===========================ELIMINAR ==================================================================================================================================
# ======================================================================================================================================================================
---------------------------------------------------------------------------------------------------------------------------------------------------------------
Elemento	     Qué es	                                              Comando para eliminar	      Cuándo eliminarlo
---------------------------------------------------------------------------------------------------------------------------------------------------------------
Contenedor	  Instancia en ejecución de una imagen	                podman rm <nombre>	        Cuando quieres reiniciar un servicio con nueva configuración
Imagen	      Plantilla/plantilla base para crear contenedores	    podman rmi <imagen>	        Cuando quieres liberar espacio en disco
---------------------------------------------------------------------------------------------------------------------------------------------------------------
# Ejecuta script para eliminar contenedores
podman rm -f -a 
# IMPORTANTE: Solo para liberar espacio en disco
# Ejecuta script para eliminar imagenes
podman rmi -f -a
cd /root/spring-project && chmod +x executor_project.sh && ./executor_project.sh
chmod +x executor_clean.sh && ./executor_clean.sh

chmod +x monitor-alpine.sh && ./monitor-alpine.sh
## Limpiar volumnes y contenedores
# Detener servicios
podman-compose down
# Detener y eliminar volúmenes (para empezar limpio)
podman-compose down -v

## Descarga de kafka-ui
https://github.com/provectus/kafka-ui/releases/tag/v0.7.2
# Ejecutar jar
java -jar kafka-ui.jar --kafka.clusters.0.name=vm-cluster --kafka.clusters.0.bootstrapServers=172.25.21.48:29092 --kafka.clusters.0.schemaRegistry=http://172.25.21.48:8081 --server.port=8085


java -jar kafka-ui.jar --kafka.clusters.0.name=vm-cluster --kafka.clusters.0.bootstrapServers=172.25.21.48:29092 --kafka.clusters.0.schemaRegistry=http://172.25.21.48:8081 --server.port=8085
-----------------------------------------------------------------------------------

$env:KAFKA_CLUSTERS_0_NAME = "vm-cluster"
$env:KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS = "172.25.21.48:29092"
$env:KAFKA_CLUSTERS_0_SCHEMAREGISTRY = "http://172.25.21.48:8081"
$env:KAFKA_CLUSTERS_0_PROPERTIES_SECURITY_PROTOCOL = "PLAINTEXT"
$env:KAFKA_CLUSTERS_0_PROPERTIES_BOOTSTRAP_SERVERS = "172.25.21.48:29092"
$env:SERVER_PORT = 8085
java -jar kafka-ui.jar
------------------------------------------------------------------------------------------------
podman exec -it kafka kafka-console-consumer --bootstrap-server localhost:9092 --topic topic-jdc --from-beginning --max-messages 10

# 1. Reconstruir la imagen de la app
docker-compose build app


# 2. Reiniciar solo el contenedor de la app (sin detener Kafka y demás)
docker-compose up -d app
# 3. Ver los logs para confirmar que funciona
docker-compose logs -f app
---------------------------------------------------------------------------------
----------------------------------------------------------------------------
-------------------------------------------------------------------
##  Usando getty con autologin nativo (El más limpio)
# Conéctate a tu VM (SSH o consola) .Edita el archivo /etc/inittab:
sed -i 's/^tty1::respawn:\/sbin\/getty.*/tty1::respawn:-\/bin\/sh/' /etc/inittab && kill -HUP 1
reinicia

## Para que al iniciar sesión en Alpine aparezcas directamente en /root/spring-project
nano /root/.profile
cd /root/spring-project
source /root/.profile

-------------------------------------------------------------
nano /etc/init.d/podman-health

#!/sbin/openrc-run

name="podman-health"
description="Daemon para ejecutar healthchecks de Podman en Alpine"

depend() {
    need net
    after podman
}

start() {
    ebegin "Iniciando ${name}"
    start-stop-daemon --start --background --make-pidfile --pidfile /run/${name}.pid \
        --exec /bin/sh -- -c "
            while true; do
                # Ejecutar healthcheck para los contenedores que nos interesen
                /usr/bin/podman healthcheck run zookeeper 2>&1 | logger -t podman-health
                /usr/bin/podman healthcheck run kafka 2>&1 | logger -t podman-health
                /usr/bin/podman healthcheck run schema-registry 2>&1 | logger -t podman-health
                /usr/bin/podman healthcheck run kafbat-ui 2>&1 | logger -t podman-health
                # Esperar segundos antes del siguiente ciclo
                sleep 8
            done
        "
    eend $?
}

stop() {
    ebegin "Deteniendo ${name}"
    start-stop-daemon --stop --pidfile /run/${name}.pid
    eend $?
}
---------------------------------------------------------------------------------------------------
# Haz el script ejecutable:
chmod +x /etc/init.d/podman-health && rc-service podman-health stop
# Iniciar el servicio ahora
# Añadirlo al runlevel por defecto para que inicie con el sistema
rc-service podman-health start && rc-update add podman-health && rc-service podman-health status
# Verifica que el servicio esté corriendo:
ps aux | grep podman-health



