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

# Función para reconstruir solo la app con JAR actualizado
rebuild_app() {
    clean_directories
    download_compose
    download_jars
    
    echo ""
    echo "=========================================="
    echo -e "${PURPLE}    RECONSTRUIR SOLO LA APLICACIÓN (SIN CACHE)${NC}"
    echo "=========================================="
    
    cd "$PROYECTO_DIR" || exit 1
    
    # Verificar que hay JARs actualizados
    print_info "Verificando JARs disponibles en target/..."
    JAR_COUNT=$(ls -1 target/*.jar 2>/dev/null | wc -l)
    
    if [ "$JAR_COUNT" -eq 0 ]; then
        print_warning "No hay archivos .jar en target/"
        print_info "Intentando descargar JARs actualizados..."
        download_jars
        JAR_COUNT=$(ls -1 target/*.jar 2>/dev/null | wc -l)
        if [ "$JAR_COUNT" -eq 0 ]; then
            print_error "No se pudo obtener ningún JAR"
            return 1
        fi
    fi
    
    # Mostrar JARs encontrados con fecha de modificación
    echo -e "${CYAN}JARs disponibles (verificar fecha):${NC}"
    ls -la target/*.jar 2>/dev/null | sed 's/^/   /'
    
    echo ""
    print_info "Paso 1: Deteniendo y eliminando contenedor app..."
    podman-compose down app 2>/dev/null
    podman rm -f app 2>/dev/null
    sleep 2
    
    print_info "Paso 2: Eliminando imagen antigua de la app..."
    # Buscar y eliminar la imagen específica de la app
    APP_IMAGE=$(podman images | grep -i "app" | awk '{print $3}')
    if [ ! -z "$APP_IMAGE" ]; then
        podman rmi -f $APP_IMAGE 2>/dev/null
        print_success "Imagen antigua eliminada"
    fi
    
    print_info "Paso 3: Reconstruyendo imagen de la app SIN CACHE..."
    # Forzar rebuild sin cache
    podman-compose build --no-cache app
    
    if [ $? -ne 0 ]; then
        print_error "Error al reconstruir la imagen"
        return 1
    fi
    
    print_info "Paso 4: Levantando app actualizada..."
    podman-compose up -d app
    
    if [ $? -eq 0 ]; then
        print_success "✅ App reconstruida y desplegada correctamente"
        
        # Verificar que el JAR nuevo esté en el contenedor
        echo ""
        print_info "Verificando JAR dentro del contenedor:"
        sleep 5
        podman exec app ls -la /app/ 2>/dev/null || echo "   No se pudo verificar (el contenedor puede estar iniciando)"
        
        # Mostrar logs recientes
        echo ""
        print_info "Últimos logs de la app:"
        podman-compose logs --tail=20 app
    else
        print_error "Error al levantar la app"
        return 1
    fi
}

# Función para ver estado rápido
quick_status() {
    echo ""
    print_info "ESTADO ACTUAL DE LOS CONTENEDORES:"
    echo "----------------------------------------"
    podman-compose ps
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
	echo -e "${YELLOW}📋 COMANDOS ÚTILES PARA PODMAN Y PODMAN-COMPOSE:${NC}"
	echo ""
	echo -e "${CYAN}🔹 CONTENEDORES:${NC}"
	echo "   Ver logs en tiempo real:              podman logs -f <nombre_contenedor>"
	echo "   Ver todos los contenedores:           podman ps -a"
	echo "   Eliminar contenedor forzosamente:     podman rm -f <nombre_contenedor>"
	echo "   Ver todas las imágenes:               podman images -a"
	echo ""
	echo -e "${CYAN}🔹 PODMAN-COMPOSE (trabajando con el stack):${NC}"
	echo "   Levantar todos los servicios:         podman-compose up -d"
	echo "   Detener todos los servicios:          podman-compose down"
	echo "   Ver logs de un servicio específico:   podman-compose logs -f <servicio>"
	echo "   Reconstruir y levantar:               podman-compose up -d --build"
	echo "   Ver puertos expuestos:                podman port <id_contenedor>"
	echo "   Ver IP de un contenedor:              podman inspect <nombre_contenedor> | grep IPAddress"
    echo ""
}

run_completo() {
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
    
    # Tiempo total
    FECHA_FIN=$(date +"%Y-%m-%d %H:%M:%S")
    echo -e "${BLUE}Tiempo total: $FECHA_INICIO - $FECHA_FIN${NC}"
    echo "=========================================="
}

# Función para mostrar menú interactivo
show_menu() {
    clear
    echo "=============================================================="
    echo -e "${PURPLE}    MENÚ DE OPERACIONES - PROYECTO SPRING BOOT${NC}"
    echo "=============================================================="
    echo -e "${CYAN}Directorio actual:${NC} $PROYECTO_DIR"
    echo -e "${CYAN}Última ejecución:${NC} $FECHA_INICIO"
    echo ""
    echo -e "${YELLOW}OPCIONES DISPONIBLES:${NC}"
    echo ""
    echo "	1	DESPLEGAR COMPLETO (limpiar todo y desplegar desde cero)"
    echo "	2	RECONSTRUIR SOLO APP (rápido, con JAR actualizado)"
    echo "	3	VER ESTADO DE CONTENEDORES"
    echo "	4	ÚLTIMOS LOGS DE LA APP"
    echo "	5	SALIR"
    show_summary
    echo "=============================================================="
}

main_with_menu() {
    while true; do
        show_menu
        read -p "Selecciona una opción : " option
        
        case $option in
            1)
                echo ""
                print_info "Ejecutando despliegue completo..."
                run_completo  # Llamar a la función main original
                ;;
            2)
                echo ""
                rebuild_app
                ;;
            3)
                quick_status
                ;;
            4)
                echo ""
                cd "$PROYECTO_DIR" && podman-compose logs --tail=10 app
                ;;
            5)
                echo -e "${GREEN}¡Hasta luego!${NC}"
                exit 0
                ;;
            *)
                print_error "Opción no válida. Por favor selecciona 1-9"
                sleep 2
                ;;
        esac
        
        echo ""
        read -p "Presiona ENTER para continuar..." pause
    done
}

# Ejecutar función principal
main_with_menu
