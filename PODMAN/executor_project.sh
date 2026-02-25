#!/bin/sh
# ============================================
# SCRIPT AUTOMATIZADO PARA PROYECTO SPRING BOOT
# ============================================

# Configuración de colores para mejor visualización
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
PURPLE='\033[0;35m'
CYAN='\033[0;36m'
NC='\033[0m' # No Color

# Configuración
URL_BASE="http://10.0.2.2:8000"
PROYECTO_DIR="/root/spring-project"
FECHA_INICIO=$(date +"%Y-%m-%d %H:%M:%S")

# Función para mostrar mensajes
print_msg() {
    echo -e "${BLUE}[$(date +'%H:%M:%S')]${NC} $1"
}

print_success() {
    echo -e "${GREEN}✅${NC} $1"
}

print_error() {
    echo -e "${RED}❌${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}⚠️${NC} $1"
}

print_info() {
    echo -e "${CYAN}ℹ️${NC} $1"
}

# Función para verificar si el servidor HTTP está disponible
check_http_server() {
    print_info "Verificando conexión con servidor HTTP en Windows..."
    if wget -q --spider "$URL_BASE" 2>/dev/null; then
        print_success "Servidor HTTP accesible"
        return 0
    else
        print_error "No se puede conectar a $URL_BASE"
        print_warning "Asegúrate de que en Windows esté corriendo en:"
        echo "   cd C:\Users\UsuarioPC\Documents\REPOSITORIO\name_proyecto"
        echo "   python -m http.server 8000"
        return 1
    fi
}

# Función para limpiar contenedores
clean_containers() {
    print_info "Limpiando contenedores existentes..."
    
    # Verificar si hay contenedores antes de eliminar
    CONTADOR=$(podman ps -aq | wc -l)
    if [ "$CONTADOR" -gt 0 ]; then
        print_warning "Eliminando $CONTADOR contenedores..."
        podman rm -f -a > /dev/null 2>&1
        print_success "Contenedores eliminados"
    else
        print_info "No hay contenedores para eliminar"
    fi
}

# Función para limpiar directorios
clean_directories() {
    print_info "Limpiando directorio del proyecto..."
    
    if [ -d "$PROYECTO_DIR" ]; then
        rm -rf rm -f /root/spring-project/Dockerfile && rm -rf rm -f /root/spring-project/docker-compose.yml && rm -rf /root/spring-project/target
        print_success "Contenido de $PROYECTO_DIR eliminado"
    else
        print_info "Creando directorio $PROYECTO_DIR"
    fi
    
    mkdir -p "$PROYECTO_DIR/target"
    print_success "Estructura de directorios creada"
}

# Función para descargar docker-compose.yml
download_compose() {
    print_info "Descargando docker-compose.yml..."
    
    cd "$PROYECTO_DIR" || exit 1
    
    if wget -q "$URL_BASE/docker-compose.yml" -O docker-compose.yml && wget -q "$URL_BASE/Dockerfile" -O Dockerfile; then
        print_success "docker-compose.yml descargado"
        # Mostrar contenido relevante
        echo "   📄 Versión: $(grep -E '^version:' docker-compose.yml | cut -d'"' -f2)"
        echo "   🐳 Servicios: $(grep -E '^  [a-zA-Z]' docker-compose.yml | tr '\n' ' ')"
    else
        print_error "No se pudo descargar docker-compose.yml"
        return 1
    fi
}

# Función para descargar JARs
download_jars() {
    print_info "Buscando archivos JAR en target/..."
    
    cd "$PROYECTO_DIR" || exit 1
    
    # Obtener lista de JARs
    JARS=$(wget -q -O- "$URL_BASE/target/" | grep -o 'href="[^"]*SNAPSHOT[^"]*\.jar"' | sed 's/href="//;s/"//')
    
    if wget -q -O- http://10.0.2.2:8000/target/ | grep -o 'href="[^"]*SNAPSHOT[^"]*\.jar"' | sed 's/href="//;s/"//' | while read jarfile; do
    echo "Descargando: $jarfile"
    wget "http://10.0.2.2:8000/target/$jarfile" -P target/
done; then
        print_success "JAR ejecutable descargado en target"
    else
        print_error "No se pudo descargar JAR"
        return 1
    fi
}

# Función para ejecutar podman-compose
run_compose() {
    print_info "Ejecutando podman-compose..."
    
    cd "$PROYECTO_DIR" || exit 1
    
    if [ ! -f "docker-compose.yml" ]; then
        print_error "No existe docker-compose.yml"
        return 1
    fi
    
    # Verificar que hay JARs
    JAR_COUNT=$(ls -1 target/*.jar 2>/dev/null | wc -l)
    if [ "$JAR_COUNT" -eq 0 ]; then
        print_warning "No hay archivos .jar en target/"
        print_warning "El build podría fallar si la imagen lo requiere"
    fi
    
    # Ejecutar compose
    print_info "Construyendo y levantando contenedores..."
    podman-compose up -d
    
    if [ $? -eq 0 ]; then
        print_success "Contenedores iniciados correctamente"
        
        # Esperar un momento y mostrar estado
        sleep 3
        echo ""
        print_info "Estado de los contenedores:"
        podman-compose ps
        
        # Mostrar información de puertos
        echo ""
        print_info "Puertos expuestos:"
        podman ps --format "table {{.Names}}\t{{.Ports}}" | grep -v "NAMES"
        
        # Probar conectividad local
        sleep 2
        if curl -s -o /dev/null -w "%{http_code}" http://localhost:8084/ | grep -q "200\|405"; then
            print_success "API respondiendo localmente en VM"
        else
            print_warning "La API aún no responde, puede estar iniciando..."
        fi
    else
        print_error "Error al iniciar contenedores"
        return 1
    fi
}

# Función para mostrar resumen
show_summary() {
    echo ""
    echo "=========================================="
    echo -e "${GREEN}           RESUMEN FINAL${NC}"
    echo "=========================================="
    echo -e "${CYAN}📁 Proyecto:${NC} $PROYECTO_DIR"
    echo -e "${CYAN}📦 docker-compose:${NC} $( [ -f $PROYECTO_DIR/docker-compose.yml ] && echo '✅' || echo '❌' )"
    echo -e "${CYAN}📚 JARs en target/:${NC} $(ls -1 $PROYECTO_DIR/target/*.jar 2>/dev/null | wc -l) archivo(s)"
    echo -e "${CYAN}🐳 Contenedores activos:${NC} $(podman ps -q | wc -l)"
    echo ""
    echo ""
	echo -e "${YELLOW}📋 COMANDOS ÚTILES PARA PODMAN Y PODMAN-COMPOSE:${NC}"
	echo ""
	echo -e "${CYAN}🔹 CONTENEDORES:${NC}"
	echo "   Ver logs en tiempo real:              podman logs -f <nombre_contenedor>"
	echo "   Ver todos los contenedores:           podman ps -a"
	echo "   Detener un contenedor:                podman stop <nombre_contenedor>"
	echo "   Eliminar contenedor forzosamente:      podman rm -f <nombre_contenedor>"
	echo ""
	echo -e "${CYAN}🔹 IMÁGENES:${NC}"
	echo "   Ver todas las imágenes:               podman images -a"
	echo "   Eliminar imagen forzosamente:          podman rmi -f <nombre_imagen>"
	echo "   Limpiar imágenes no usadas:            podman image prune -f"
	echo ""
	echo -e "${CYAN}🔹 PODMAN-COMPOSE (trabajando con el stack):${NC}"
	echo "   Levantar todos los servicios:         podman-compose up -d"
	echo "   Detener todos los servicios:          podman-compose down"
	echo "   Ver logs de un servicio específico:   podman-compose logs -f <servicio>"
	echo "   Ver estado de los servicios:          podman-compose ps"
	echo "   Reconstruir y levantar:               podman-compose up -d --build"
	echo "   Detener y eliminar todo (contenedores, redes): podman-compose down"
	echo ""
	echo -e "${CYAN}🔹 INFORMACIÓN Y DIAGNÓSTICO:${NC}"
	echo "   Ver puertos expuestos:                podman port <nombre_contenedor>"
	echo "   Ver IP de un contenedor:              podman inspect <nombre_contenedor> | grep IPAddress"
	echo "   Ver healthcheck de un contenedor:     podman healthcheck <nombre_contenedor>"
    echo ""
}

# Función principal
main() {
    clear
    echo "=============================================================="
    echo -e "${PURPLE}    SCRIPT AUTOMATIZADO - DEPLOY EN PODMAN${NC}"
    echo "=============================================================="
    echo "Inicio: $FECHA_INICIO"
    echo ""
    
    # Paso 1: Verificar servidor HTTP
    check_http_server || exit 1
    echo ""
    
    # Paso 2: Limpiar contenedores
    clean_containers
    echo ""
    
    # Paso 3: Limpiar directorios
    clean_directories
    echo ""
    
    # Paso 4: Descargar docker-compose
    download_compose || exit 1
    echo ""
    
    # Paso 5: Descargar JARs
    download_jars
    echo ""
    
    # Paso 6: Ejecutar podman-compose
    run_compose
    echo ""
    
    # Paso 7: Mostrar resumen
    show_summary
    
    # Tiempo total
    FECHA_FIN=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${BLUE}Tiempo total: $FECHA_INICIO - $FECHA_FIN${NC}"
    echo "=========================================="
}

# Ejecutar función principal
main

# Preguntar si quiere ver logs
echo ""
read -p "¿Quieres ver los logs en tiempo real? (s/n): " ver_logs
if [ "$ver_logs" = "s" ] || [ "$ver_logs" = "S" ]; then
    cd "$PROYECTO_DIR" && podman-compose logs -f
fi
