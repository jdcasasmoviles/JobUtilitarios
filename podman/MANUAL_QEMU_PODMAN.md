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
Enter system hostname: Ponle un nombre a tu máquina virtual, por ejemplo: desktop-alpine.
Which one do you want to initialize? (or '?' for list): eth0 (selecciona la interfaz de red).
Ip address for eth0? (or 'dhcp'): Escribe dhcp y presiona Enter para que obtenga una IP automáticamente.
Do you want to do any manual network configuration?: Escribe n.
New password: Establece una contraseña para el usuario root. Escríbela dos veces.
Which timezone are you in?: Especifica tu zona horaria, por ejemplo: America/Lima.
Which HTTP proxy (URL) you want to use?: Déjalo en blanco y presiona Enter.
Which NTP client to run?: Elige chrony (o el que venga por defecto).
Enter mirror number (1-xx) or URL to fetch: Elige un número de servidor mirror cercano a tu ubicación para descargas rápidas (por ejemplo, el de tu país).
Escribe 1 y enter
Setup a user? no (no creamos un usuario normal, solo usaremos root para simplificar)
Which SSH server? ('openssh') Elige openssh.
Allow root ssh login?	prohibit-password (solo por clave SSH)
Enter ssh key or URL for root?	none
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
# Conectamos por ssh ,desde un cmd de windows
ssh-keygen -R [localhost]:2222
ssh -o StrictHostKeyChecking=no -p 2222 root@localhost

# ======= FASE 4: Instalación de Podman y dependencias============================================================================
# Habilitar repositorio community
nano /etc/apk/repositories
Descomenta la línea que termina en community (quita el #). Guarda y sal.
# Instalar paquetes necesarios
apk update
# Instalar Podman (este comando instalará crun, conmon, etc.)
apk add podman

# Configurar y arrancar el servicio de cgroups v2 (esencial para Podman)
rc-update add cgroups boot
rc-service cgroups start

# (Opcional) Eliminar el mensaje de advertencia de Docker
touch /etc/containers/nodocker

# 6. ¡Verificar la instalación!
podman info
podman --version
# ======= FASE 5: Instalacion de compose ============================================================================
# Instalar podman-compose
apk add podman-compose
# Verificar la versión instalada
podman-compose --version
# ======= FASE 6: Probando podman ============================================================================
# arrancar la maquina virtual
qemu-system-x86_64 -m 2048 -smp 2 -hda alpine-disk.qcow2 -vga std -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080 -device e1000,netdev=net0
# Crear proyecto de prueba
mkdir ~/proyectos
cd ~/proyectos
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
wget -O- localhost:8080
# Deberías ver el HTML de bienvenida de nginx.
Acceso desde Windows.Desde el navegador en Windows.
Abre cualquier navegador y ve a:
http://localhost:8080
# DEBERÍAS VER "Welcome to nginx!"
# Borramos los archivos de prueba (forzado)
podman rm -f -a && podman rmi -f -a
rm -rf docker-compose.yml

# ======= FASE 7: Configurar para que cargue un path por defecto ============================================================================
##  Usando getty con autologin nativo (El más limpio)
# Conéctate a tu VM (SSH o consola) .Edita el archivo /etc/inittab:
sed -i 's/^tty1::respawn:\/sbin\/getty.*/tty1::respawn:-\/bin\/sh/' /etc/inittab
# Configurar directorio por defecto
cat >> ~/.profile << 'EOF'
if [ -d ~/proyectos ]; then
    cd ~/proyectos
fi
EOF

# Asegurar que .profile se carga en SSH
echo "source ~/.profile" >> ~/.profile

# Aplicar cambios
kill -HUP 1
reboot

# ======= FASE 8: Verificador de podman-health  ============================================================================
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
                /usr/bin/podman healthcheck run app 2>&1 | logger -t podman-health
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
--------------------------------------------------------------------------------------------------------------------------------------------------------
qemu-system-x86_64.exe -m 4096 -smp 4 -hda alpine-disk.qcow2 -vga std -netdev user,id=net0,hostfwd=tcp::2222-:22,hostfwd=tcp::8080-:8080,hostfwd=tcp::8086-:8086,hostfwd=tcp::9092-:9092,hostfwd=tcp::8081-:8081 -device e1000,netdev=net0

rm -rf /root/proyectos/executor_project.sh && cd /root/proyectos && wget http://10.0.2.2:8000/executor_project.sh
cd /root/proyectos && chmod +x executor_project.sh && ./executor_project.sh

chmod +x create_topic_schema.sh && ./create_topic_schema.sh


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


# Elimina los directorios
rm -rf /root/spring-project/* && mkdir -p /root/spring-project/target
# Descargar archivos a VM
rm -rf /root/spring-project/executor_project.sh && cd /root/spring-project && wget http://10.0.2.2:8000/executor_project.sh
cd /root/spring-project && wget http://10.0.2.2:8000/docker-compose.yml
cd /root/spring-project && wget http://10.0.2.2:8000/Dockerfile

## Ejecutando podman con Dockerfile
podman build -t mi-app .
podman run -d -p 8084:8084 --name mi-app-container mi-app
podman logs -f mi-app-container


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
$env:KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS = "127.0.0.1:9092"
$env:KAFKA_CLUSTERS_0_SCHEMAREGISTRY = "http://127.0.0.1:8081"
$env:SERVER_PORT = 8086
java -jar kafka-ui.jar

java -jar kafka-ui.jar --server.port=8085

java --add-opens java.rmi/javax.rmi.ssl=ALL-UNNAMED -jar kafka-ui.jar --server.port=8086 --KAFKA_CLUSTERS_0_NAME=local --KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=192.168.1.59:9092

java --add-opens java.rmi/javax.rmi.ssl=ALL-UNNAMED -jar kafka-ui.jar --server.port=8086 --KAFKA_CLUSTERS_0_NAME=local --KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=localhost:29092

java --add-opens java.rmi/javax.rmi.ssl=ALL-UNNAMED -jar api-v1.4.2.jar --server.port=8086 --kafka.clusters[0].name=local --kafka.clusters[0].bootstrapServers=192.168.1.59:9092 --kafka.clusters[0].readOnly=false


java -jar kafdrop-4.2.0.jar --kafka.brokerConnect=192.168.1.59:9092 --server.port=8086

java -jar kafka-ui.jar --kafka.brokerConnect=192.168.1.59:9092 --server.port=8086

java -jar kafka-ui.jar --KAFKA_CLUSTERS_0_NAME=vm-cluster --KAFKA_CLUSTERS_0_BOOTSTRAPSERVERS=127.0.0.1:9092 --KAFKA_CLUSTERS_0_SCHEMAREGISTRY=http://127.0.0.1:8081 --SERVER_PORT=8086

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


-------------------------------------------------------------




