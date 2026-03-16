## MANUAL COMPLETO: Podman en Windows usando WSL Ubuntu
Objetivo
Configurar Podman en Windows utilizando WSL (Ubuntu) como motor de contenedores, 
permitiendo usar comandos podman desde PowerShell.

## Instalación de WSL y Ubuntu
# En PowerShell como administrador
wsl --install
# Al finalizar, crear usuario y contraseña
Usuario: uservm (o el que prefieras)
Contraseña: la que desees
# Eliminar Debian (si no la necesitas)
wsl --unregister Debian
# Establecer Ubuntu como default
wsl --set-default Ubuntu
# Verificar
wsl -l -v
# RESULTADO
  NAME      STATE           VERSION
* Ubuntu    Running         2

## Instalación de Podman en Ubuntu
# Entrar a Ubuntu
wsl ~ -d Ubuntu
# Dentro de Ubuntu
sudo apt update
sudo apt install podman -y
podman --version
podman info
# Probar podman
podman run hello-world
# Configurar registros de búsqueda
sudo nano /etc/containers/registries.conf

[registries.search]
registries = ["docker.io"]

Guardar con Ctrl+O, Enter, Ctrl+X.
# salir de ubuntu
exit

## Configuración de SSH
# Entrar a Ubuntu
wsl ~ -d Ubuntu
# Instalar servidor SSH
sudo apt install openssh-server -y

# Habilitar e iniciar SSH
sudo systemctl enable ssh
sudo systemctl start ssh

# Verificar estado
sudo systemctl status ssh
# Configurar SSH para escuchar en todas las interfaces
sudo nano /etc/ssh/sshd_config

Port 22
ListenAddress 0.0.0.0
PasswordAuthentication yes

# Reiniciar SSH:
sudo systemctl restart ssh

# Ver IP de Ubuntu
ip addr show | grep eth0
# Anotar la IP (ej: 172.25.21.48)
exit

## Configuración de llaves SSH
# Generar llave en Windows
# En PowerShell
ssh-keygen -t ed25519 -f "$env:USERPROFILE\.ssh\wsl_ubuntu_key"
# No poner contraseña (Enter dos veces)

# Ver la llave pública
type "$env:USERPROFILE\.ssh\wsl_ubuntu_key.pub"
# Copiar TODO el texto que aparece para que lo uses en ubuntu

# Entrar a Ubuntu
wsl ~ -d Ubuntu
# Crear directorio .ssh si no existe
mkdir -p ~/.ssh

# Editar archivo de claves autorizadas
nano ~/.ssh/authorized_keys
# Pegar la llave pública copiada
# Guardar: Ctrl+O, Enter, Ctrl+X

# Ajustar permisos
chmod 700 ~/.ssh
chmod 600 ~/.ssh/authorized_keys
exit
# en windows .Probar conexión sin contraseña
ssh -i "$env:USERPROFILE\.ssh\wsl_ubuntu_key" uservm@localhost
## Instalación de Podman CLI en Windows.VALIDAR ESTE PASO SI ES NECESARIO
podman --version

## Configuración de la conexión Podman
# Eliminar máquinas virtuales de Podman (si existen)
podman machine rm -f podman-machine-default
# Configurar la conexión a Ubuntu
# Agregar conexión (TODO EN UNA LÍNEA)
podman system connection add ubuntu-wsl --identity "$env:USERPROFILE\.ssh\wsl_ubuntu_key" ssh://uservm@127.0.0.1:22/run/user/1000/podman/podman.sock
# Establecer como predeterminada
podman system connection default ubuntu-wsl
# Verificar
podman system connection list
# Probando conexion
podman ps
podman images
podman run hello-world
# Configurar variables de entorno.Variables permanentes para evitar problemas de resolución de nombres
[System.Environment]::SetEnvironmentVariable('CONTAINER_HOST', 'ssh://uservm@127.0.0.1:22/run/user/1000/podman/podman.sock', 'User')
[System.Environment]::SetEnvironmentVariable('CONTAINER_SSHKEY', "$env:USERPROFILE\.ssh\wsl_ubuntu_key", 'User')
# Configurar archivo hosts (para evitar problemas IPv6) .Editar como administrador.Agregar al final:
notepad C:\Windows\System32\drivers\etc\hosts
127.0.0.1 localhost
# Ejecutar
ipconfig /flushdns

## Configuración de inicio automático
# Habilitar linger en Ubuntu (servicios de usuario)
wsl ~ -d Ubuntu
# En ubuntu
sudo loginctl enable-linger uservm
systemctl --user enable podman.socket
exit
# Crear script para mantener WSL vivo.En windows.
-------------------------power shell-------------------------------------------------------------------------------------
# Crear script
$scriptPath = "$env:USERPROFILE\keep-wsl-alive.ps1"
@"
# keep-wsl-alive.ps1
`$logFile = "`$env:TEMP\wsl-keepalive.log"

function Write-Log {
    param(`$message)
    `"`$(Get-Date -Format 'yyyy-MM-dd HH:mm:ss'): `$message`" | Out-File -FilePath `$logFile -Append
}

Write-Log "Iniciando script de mantenimiento WSL"

# Iniciar Ubuntu
try {
    wsl -d Ubuntu -- echo "Iniciado" 2>&1 | Out-Null
    Write-Log "WSL iniciado correctamente"
} catch {
    Write-Log "ERROR al iniciar WSL: `$_"
}

# Mantener vivo
while(`$true) {
    try {
        wsl -d Ubuntu -- echo "keepalive" 2>&1 | Out-Null
        Write-Log "Keepalive enviado"
    } catch {
        Write-Log "Error en keepalive: `$_"
        # Intentar reiniciar WSL
        wsl -d Ubuntu -- echo "reiniciar" 2>&1 | Out-Null
    }
    Start-Sleep -Seconds 30
}
"@ | Out-File -FilePath $scriptPath -Encoding UTF8
------------------------------------------------------------------------------------------------------------
# Crear tarea programada (PowerShell como administrador)
# Eliminar tarea anterior si existe
Unregister-ScheduledTask -TaskName "IniciarWSL" -Confirm:$false -ErrorAction SilentlyContinue

# Crear nueva tarea
$action = New-ScheduledTaskAction -Execute "powershell.exe" -Argument "-WindowStyle Hidden -ExecutionPolicy Bypass -File C:\Users\UsuarioPC\keep-wsl-alive.ps1"
$trigger = New-ScheduledTaskTrigger -AtLogOn -User $env:USERNAME
$settings = New-ScheduledTaskSettingsSet -AllowStartIfOnBatteries -DontStopIfGoingOnBatteries -StartWhenAvailable -MultipleInstances IgnoreNew
$principal = New-ScheduledTaskPrincipal -UserId $env:USERNAME -LogonType Interactive -RunLevel Highest

Register-ScheduledTask -TaskName "IniciarWSL" -Action $action -Trigger $trigger -Settings $settings -Principal $principal -Force

Write-Host "Tarea creada exitosamente" -ForegroundColor Green

## Verificación final
 Reiniciar Windows
# Después del reinicio, verificar
# Abrir PowerShell y ejecutar:
wsl -l -v
# Debe mostrar: Ubuntu    Running

podman ps
# Debe mostrar lista vacía (sin errores)

podman run hello-world
# Debe mostrar el mensaje de bienvenida

# Probar con nginx
podman run -d --name test-nginx -p 8080:80 docker.io/library/nginx:alpine
podman ps
# Abrir navegador: http://localhost:8080
# Debe verse la página de bienvenida de nginx

## Solución de problemas comunes
# Error: "ssh: connect to host localhost port 22: Connection refused"   
# Solucion
 wsl ~ -d Ubuntu
sudo systemctl restart ssh
exit

# Podman no encuentra el socket
# Solucion
wsl ~ -d Ubuntu
systemctl --user start podman.socket
ls -la /run/user/1000/podman/
exit

## Comandos útiles
# -----------------------------------------WINDOWS -----------------------------------------------
# Ver contenedores
podman ps
podman ps -a

# Ver imágenes
podman images

# Ejecutar contenedor
podman run -d --name mi-web -p 8080:80 nginx:alpine

# Detener contenedor
podman stop mi-web

# Eliminar contenedor
podman rm mi-web

# Ver logs
podman logs mi-web

# Entrar a contenedor
podman exec -it mi-web sh

# Limpiar todo
podman system prune --all --force --volumes
# -----------------------------------------UBUNTU-----------------------------------------------
# Mismos comandos funcionan
podman ps

# Ver servicios
systemctl --user status podman.socket
sudo systemctl status ssh

# Ver IP
ip addr show | grep eth0


