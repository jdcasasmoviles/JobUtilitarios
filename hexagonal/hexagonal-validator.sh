#!/bin/bash

# Colores para output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Configuración
PROJECT_ROOT=${1:-.}
VALIDATION_LEVEL=${2:-strict} # strict | moderate | lenient

# Contadores
PASS_COUNT=0
WARN_COUNT=0
FAIL_COUNT=0
TOTAL_CHECKS=0

# Logger
log_pass() {
    echo -e "${GREEN}✓ PASS:${NC} $1"
    ((PASS_COUNT++))
    ((TOTAL_CHECKS++))
}

log_warn() {
    echo -e "${YELLOW}⚠ WARN:${NC} $1"
    ((WARN_COUNT++))
    ((TOTAL_CHECKS++))
}

log_fail() {
    echo -e "${RED}✗ FAIL:${NC} $1"
    ((FAIL_COUNT++))
    ((TOTAL_CHECKS++))
}

log_info() {
    echo -e "${BLUE}ℹ INFO:${NC} $1"
}

# Funciones de validación

validate_project_structure() {
    log_info "Validando estructura del proyecto..."
    
    # Estructura base
    local required_dirs=(
        "src/main/java"
        "src/test/java"
        "src/main/resources"
    )
    
    for dir in "${required_dirs[@]}"; do
        if [ -d "$PROJECT_ROOT/$dir" ]; then
            log_pass "Directorio $dir existe"
        else
            log_fail "Directorio $dir no encontrado"
        fi
    done
    
    # Verificar estructura hexagonal
    local hex_layers=(
        "domain"
        "application" 
        "infrastructure"
    )
    
    for layer in "${hex_layers[@]}"; do
        if find "$PROJECT_ROOT/src/main/java" -type d -name "$layer" | grep -q .; then
            log_pass "Capa $layer detectada"
        else
            log_fail "Capa $layer no encontrada"
        fi
    done
}

validate_domain_layer() {
    log_info "Validando capa de dominio..."
    
    local domain_path=$(find "$PROJECT_ROOT/src/main/java" -type d -name "domain" | head -1)
    
    if [ -z "$domain_path" ]; then
        log_fail "Capa domain no existe"
        return
    fi
    
    # Verificar que domain NO tenga dependencias externas
    if grep -r "import.*jakarta\|import.*javax\|import.*spring\|@Entity\|@Table" "$domain_path" --include="*.java" | grep -v "//.*import" > /dev/null; then
        log_fail "Capa domain contiene imports de infraestructura"
    else
        log_pass "Capa domain está aislada de infraestructura"
    fi
    
    # Verificar modelos y puertos
    local has_models=$(find "$domain_path" -type d -name "models" -o -name "entities" | head -1)
    local has_ports=$(find "$domain_path" -type d -name "ports" -o -name "repositories" | head -1)
    
    [ -n "$has_models" ] && log_pass "Subcapa models/entities encontrada" || log_fail "Subcapa models/entities no encontrada"
    [ -n "$has_ports" ] && log_pass "Subcapa ports/repositories encontrada" || log_fail "Subcapa ports/repositories no encontrada"
}

validate_application_layer() {
    log_info "Validando capa de aplicación..."
    
    local app_path=$(find "$PROJECT_ROOT/src/main/java" -type d -name "application" | head -1)
    
    if [ -z "$app_path" ]; then
        log_fail "Capa application no existe"
        return
    fi
    
    # Verificar que application solo dependa de domain
    if grep -r "import.*infrastructure" "$app_path" --include="*.java" | grep -v "//.*import" > /dev/null; then
        log_fail "Capa application importa infraestructura"
    else
        log_pass "Capa application solo depende de domain"
    fi
    
    # Verificar casos de uso
    local usecases=$(find "$app_path" -type d -name "usecases" -o -name "services")
    [ -n "$usecases" ] && log_pass "Casos de uso encontrados" || log_warn "No se encontraron casos de uso específicos"
    
    # Verificar DTOs
    local has_dtos=$(find "$app_path" -type d -name "dtos")
    [ -n "$has_dtos" ] && log_pass "DTOs encontrados" || log_warn "No se encontró carpeta dtos"
}

validate_infrastructure_layer() {
    log_info "Validando capa de infraestructura..."
    
    local infra_path=$(find "$PROJECT_ROOT/src/main/java" -type d -name "infrastructure" | head -1)
    
    if [ -z "$infra_path" ]; then
        log_fail "Capa infrastructure no existe"
        return
    fi
    
    # Verificar subcapas
    local has_input=$(find "$infra_path" -type d -name "input")
    local has_output=$(find "$infra_path" -type d -name "output")
    
    [ -n "$has_input" ] && log_pass "Subcapa input encontrada" || log_fail "Subcapa input no encontrada"
    [ -n "$has_output" ] && log_pass "Subcapa output encontrada" || log_fail "Subcapa output no encontrada"
    
    # Verificar adaptadores
    local has_rest=$(find "$infra_path" -name "*Resource.java" -o -name "*Controller.java")
    local has_repos=$(find "$infra_path" -name "*Repository.java" -o -name "*Adapter.java")
    
    [ -n "$has_rest" ] && log_pass "Controladores REST encontrados" || log_warn "No se encontraron controladores REST"
    [ -n "$has_repos" ] && log_pass "Repositorios/adaptadores encontrados" || log_warn "No se encontraron repositorios"
}

validate_dependencies() {
    log_info "Validando dependencias en pom.xml..."
    
    local pom_file="$PROJECT_ROOT/pom.xml"
    
    if [ ! -f "$pom_file" ]; then
        log_fail "pom.xml no encontrado"
        return
    fi
    
    # Verificar dependencias de Quarkus
    if grep -q "quarkus" "$pom_file"; then
        log_pass "Dependencias Quarkus encontradas"
    else
        log_warn "No se encontraron dependencias Quarkus"
    fi
    
    # Verificar estructura de módulos (si es multi-módulo)
    if grep -q "<modules>" "$pom_file"; then
        log_info "Proyecto multi-módulo detectado"
        validate_multi_module_structure
    fi
}

validate_dependency_direction() {
    log_info "Validando dirección de dependencias..."
    
    # Buscar imports ilegales entre capas
    local domain_path=$(find "$PROJECT_ROOT/src/main/java" -type d -name "domain" | head -1)
    local app_path=$(find "$PROJECT_ROOT/src/main/java" -type d -name "application" | head -1)
    local infra_path=$(find "$PROJECT_ROOT/src/main/java" -type d -name "infrastructure" | head -1)
    
    if [ -n "$domain_path" ] && [ -n "$infra_path" ]; then
        # Domain NO debe importar infrastructure
        if find "$domain_path" -name "*.java" -exec grep -l "import.*infrastructure" {} \; | grep -q .; then
            log_fail "Domain importa infrastructure (viola regla de dependencia)"
        else
            log_pass "Domain no depende de infrastructure"
        fi
    fi
    
    if [ -n "$app_path" ] && [ -n "$infra_path" ]; then
        # Application NO debe importar infrastructure directamente
        if find "$app_path" -name "*.java" -exec grep -l "import.*infrastructure" {} \; | grep -q .; then
            log_warn "Application importa infrastructure (debería usar ports)"
        else
            log_pass "Application no depende directamente de infrastructure"
        fi
    fi
}

validate_ports_adapters() {
    log_info "Validando puertos y adaptadores..."
    
    local domain_path=$(find "$PROJECT_ROOT/src/main/java" -type d -name "domain" | head -1)
    local infra_path=$(find "$PROJECT_ROOT/src/main/java" -type d -name "infrastructure" | head -1)
    
    if [ -z "$domain_path" ] || [ -z "$infra_path" ]; then
        log_warn "No se pueden validar puertos/adaptadores (capas faltantes)"
        return
    fi
    
    # Buscar interfaces de puerto en domain
    local port_files=$(find "$domain_path" -name "*.java" -exec grep -l "interface.*Port\|interface.*Repository" {} \;)
    
    if [ -n "$port_files" ]; then
        local port_count=$(echo "$port_files" | wc -l)
        log_pass "Encontradas $port_count interfaces de puerto"
        
        # Verificar implementaciones en infrastructure
        for port_file in $port_files; do
            local port_name=$(basename "$port_file" .java)
            local impl_count=$(find "$infra_path" -name "*.java" -exec grep -l "implements.*$port_name\|extends.*$port_name" {} \; | wc -l)
            
            if [ "$impl_count" -gt 0 ]; then
                log_pass "Puerto $port_name tiene implementación"
            else
                log_warn "Puerto $port_name no tiene implementación"
            fi
        done
    else
        log_fail "No se encontraron interfaces de puerto"
    fi
}

validate_test_structure() {
    log_info "Validando estructura de tests..."
    
    local test_path="$PROJECT_ROOT/src/test"
    
    if [ ! -d "$test_path" ]; then
        log_warn "No se encontró directorio de tests"
        return
    fi
    
    # Verificar tests por capa
    local has_domain_tests=$(find "$test_path" -type d -name "*domain*" -o -name "*Domain*")
    local has_app_tests=$(find "$test_path" -type d -name "*application*" -o -name "*Application*")
    local has_infra_tests=$(find "$test_path" -type d -name "*infrastructure*" -o -name "*Infrastructure*")
    
    [ -n "$has_domain_tests" ] && log_pass "Tests de domain encontrados" || log_warn "No hay tests específicos para domain"
    [ -n "$has_app_tests" ] && log_pass "Tests de application encontrados" || log_warn "No hay tests específicos para application"
    [ -n "$has_infra_tests" ] && log_pass "Tests de infrastructure encontrados" || log_warn "No hay tests específicos para infrastructure"
    
    # Verificar tipos de tests
    if find "$test_path" -name "*Test.java" | grep -q .; then
        log_pass "Tests unitarios encontrados"
    fi
    
    if find "$test_path" -name "*IT.java" -o -name "*IntegrationTest.java" | grep -q .; then
        log_pass "Tests de integración encontrados"
    fi
}

validate_multi_module_structure() {
    log_info "Validando estructura multi-módulo..."
    
    local modules_dir="$PROJECT_ROOT"
    
    # Buscar módulos basados en estructura hexagonal
    local expected_modules=("domain" "application" "infrastructure" "api")
    
    for module in "${expected_modules[@]}"; do
        if [ -d "$modules_dir/$module" ] || find "$modules_dir" -maxdepth 2 -type d -name "$module" | grep -q .; then
            log_pass "Módulo $module detectado"
        else
            log_warn "Módulo $module no encontrado"
        fi
    done
}

validate_hexagonal_flow() {
    log_info "Validando flujo hexagonal..."
    
    # Crear diagrama simple de dependencias
    log_info "Diagrama de dependencias detectado:"
    
    local domain_files=$(find "$PROJECT_ROOT/src/main/java" -path "*/domain/*" -name "*.java" | wc -l)
    local app_files=$(find "$PROJECT_ROOT/src/main/java" -path "*/application/*" -name "*.java" | wc -l)
    local infra_files=$(find "$PROJECT_ROOT/src/main/java" -path "*/infrastructure/*" -name "*.java" | wc -l)
    
    echo "    Domain:      $domain_files archivos"
    echo "    Application: $app_files archivos"
    echo "    Infrastructure: $infra_files archivos"
    echo ""
    echo "    Flujo esperado:"
    echo "    Infrastructure → Application → Domain"
    echo ""
    
    # Calcular métricas
    local total_java=$((domain_files + app_files + infra_files))
    if [ "$total_java" -gt 0 ]; then
        local domain_percent=$((domain_files * 100 / total_java))
        local app_percent=$((app_files * 100 / total_java))
        local infra_percent=$((infra_files * 100 / total_java))
        
        echo "    Distribución:"
        echo "    Domain:      $domain_percent%"
        echo "    Application: $app_percent%"
        echo "    Infrastructure: $infra_percent%"
        
        # Regla de oro: domain debería ser la capa más pequeña
        if [ "$domain_files" -lt "$app_files" ] && [ "$domain_files" -lt "$infra_files" ]; then
            log_pass "Distribución de archivos adecuada"
        else
            log_warn "Domain debería ser la capa más pequeña"
        fi
    fi
}

generate_report() {
    echo ""
    echo "========================================="
    echo "         INFORME DE VALIDACIÓN"
    echo "========================================="
    echo "Proyecto analizado: $(realpath "$PROJECT_ROOT")"
    echo "Nivel de validación: $VALIDATION_LEVEL"
    echo ""
    echo "RESULTADOS:"
    echo "  Total de verificaciones: $TOTAL_CHECKS"
    echo "  ${GREEN}Aprobadas: $PASS_COUNT${NC}"
    echo "  ${YELLOW}Advertencias: $WARN_COUNT${NC}"
    echo "  ${RED}Fallos: $FAIL_COUNT${NC}"
    echo ""
    
    # Calcular puntuación
    local score=$((PASS_COUNT * 100 / TOTAL_CHECKS))
    
    echo "PUNTUACIÓN HEXAGONAL: $score%"
    echo ""
    
    if [ "$score" -ge 90 ]; then
        echo "${GREEN}✅ EXCELENTE: Arquitectura hexagonal bien implementada${NC}"
    elif [ "$score" -ge 70 ]; then
        echo "${GREEN}✅ BUENO: Arquitectura hexagonal implementada con algunas mejoras posibles${NC}"
    elif [ "$score" -ge 50 ]; then
        echo "${YELLOW}⚠ ACEPTABLE: Se detecta estructura hexagonal pero necesita refactorización${NC}"
    else
        echo "${RED}✗ INSUFICIENTE: La arquitectura hexagonal no está correctamente implementada${NC}"
    fi
    
    # Recomendaciones
    if [ "$FAIL_COUNT" -gt 0 ]; then
        echo ""
        echo "RECOMENDACIONES CRÍTICAS:"
        [ "$FAIL_COUNT" -ge 3 ] && echo "  • Refactorizar la estructura de capas"
        [ "$(find "$PROJECT_ROOT" -path "*/domain/*" -name "*.java" -exec grep -l "import.*jakarta\|import.*javax" {} \; | wc -l)" -gt 0 ] && \
            echo "  • Eliminar dependencias de infraestructura en la capa domain"
    fi
    
    # Generar archivo de reporte
    local report_file="$PROJECT_ROOT/hexagonal-validation-report.md"
    cat > "$report_file" << EOF
# Reporte de Validación Hexagonal
**Fecha**: $(date)
**Proyecto**: $(basename "$(realpath "$PROJECT_ROOT")")
**Puntuación**: $score%

## Resumen
- ✅ Aprobadas: $PASS_COUNT
- ⚠ Advertencias: $WARN_COUNT
- ✗ Fallos: $FAIL_COUNT

## Estructura del Proyecto
\`\`\`
$(find "$PROJECT_ROOT/src/main/java" -type d | sort | sed "s|$PROJECT_ROOT||")
\`\`\`

## Métricas
- Archivos Domain: $domain_files
- Archivos Application: $app_files  
- Archivos Infrastructure: $infra_files

## Próximos Pasos
$(if [ "$FAIL_COUNT" -gt 0 ]; then
echo "1. Corregir los $FAIL_COUNT fallos críticos"
fi)
$(if [ "$WARN_COUNT" -gt 0 ]; then
echo "2. Revisar las $WARN_COUNT advertencias"
fi)
$(if [ "$score" -lt 80 ]; then
echo "3. Considerar refactorización para mejorar la separación de capas"
fi)
EOF
    
    log_info "Reporte generado: $report_file"
}

# Función principal
main() {
    echo "========================================="
    echo "  VALIDADOR DE ARQUITECTURA HEXAGONAL"
    echo "========================================="
    echo "Analizando proyecto: $PROJECT_ROOT"
    echo ""
    
    # Ejecutar validaciones
    validate_project_structure
    validate_domain_layer
    validate_application_layer
    validate_infrastructure_layer
    validate_dependencies
    validate_dependency_direction
    validate_ports_adapters
    validate_test_structure
    validate_hexagonal_flow
    
    # Generar reporte
    generate_report
    
    # Exit code basado en resultados
    if [ "$FAIL_COUNT" -gt 0 ]; then
        exit 1
    elif [ "$WARN_COUNT" -gt 0 ] && [ "$VALIDATION_LEVEL" = "strict" ]; then
        exit 2
    else
        exit 0
    fi
}

# Ejecutar
main