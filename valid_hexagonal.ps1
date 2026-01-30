# hexagonal-validator.ps1
# Script PowerShell para validar arquitectura hexagonal en Windows

param(
    [string]$ProjectRoot = ".",
    [string]$ValidationLevel = "moderate"
)

# Configuración de colores
$ErrorActionPreference = "Continue"
$host.UI.RawUI.ForegroundColor = "White"

# Función para colorear salida
function Write-Color {
    param(
        [string]$Text,
        [string]$Color = "White"
    )
    $host.UI.RawUI.ForegroundColor = $Color
    Write-Output $Text
    $host.UI.RawUI.ForegroundColor = "White"
}

# Contadores
$global:PassCount = 0
$global:WarnCount = 0
$global:FailCount = 0
$global:TotalChecks = 0

# Funciones de log
function Log-Pass {
    param([string]$Message)
    Write-Color "✓ PASS: $Message" "Green"
    $global:PassCount++
    $global:TotalChecks++
}

function Log-Warn {
    param([string]$Message)
    Write-Color "⚠ WARN: $Message" "Yellow"
    $global:WarnCount++
    $global:TotalChecks++
}

function Log-Fail {
    param([string]$Message)
    Write-Color "✗ FAIL: $Message" "Red"
    $global:FailCount++
    $global:TotalChecks++
}

function Log-Info {
    param([string]$Message)
    Write-Color "ℹ INFO: $Message" "Cyan"
}

# Validaciones principales
function Validate-ProjectStructure {
    Log-Info "Validando estructura del proyecto..."
    
    $requiredDirs = @(
        "src/main/java",
        "src/test/java", 
        "src/main/resources"
    )
    
    foreach ($dir in $requiredDirs) {
        $fullPath = Join-Path $ProjectRoot $dir
        if (Test-Path $fullPath -PathType Container) {
            Log-Pass "Directorio $dir existe"
        } else {
            Log-Fail "Directorio $dir no encontrado"
        }
    }
    
    # Buscar capas hexagonales
    $hexLayers = @("domain", "application", "infrastructure")
    
    foreach ($layer in $hexLayers) {
        $found = Get-ChildItem -Path "$ProjectRoot/src/main/java" -Recurse -Directory | 
                 Where-Object { $_.Name -eq $layer } | Select-Object -First 1
        if ($found) {
            Log-Pass "Capa $layer detectada"
        } else {
            Log-Fail "Capa $layer no encontrada"
        }
    }
}

function Validate-DomainLayer {
    Log-Info "Validando capa de dominio..."
    
    $domainPath = Get-ChildItem -Path "$ProjectRoot/src/main/java" -Recurse -Directory |
                  Where-Object { $_.Name -eq "domain" } | 
                  Select-Object -First 1 -ExpandProperty FullName
    
    if (-not $domainPath) {
        Log-Fail "Capa domain no existe"
        return
    }
    
    # Verificar que domain NO tenga imports de infraestructura
    $javaFiles = Get-ChildItem -Path $domainPath -Recurse -Filter "*.java" -File
    $hasInfraImports = $false
    
    foreach ($file in $javaFiles) {
        $content = Get-Content $file.FullName -Raw
        if ($content -match 'import.*jakarta|import.*javax|import.*spring|@Entity|@Table') {
            $hasInfraImports = $true
            break
        }
    }
    
    if ($hasInfraImports) {
        Log-Fail "Capa domain contiene imports de infraestructura"
    } else {
        Log-Pass "Capa domain está aislada de infraestructura"
    }
}

function Validate-DependencyDirection {
    Log-Info "Validando dirección de dependencias..."
    
    $domainPath = Get-ChildItem -Path "$ProjectRoot/src/main/java" -Recurse -Directory |
                  Where-Object { $_.Name -eq "domain" } | 
                  Select-Object -First 1 -ExpandProperty FullName
    
    $infraPath = Get-ChildItem -Path "$ProjectRoot/src/main/java" -Recurse -Directory |
                 Where-Object { $_.Name -eq "infrastructure" } | 
                 Select-Object -First 1 -ExpandProperty FullName
    
    if ($domainPath -and $infraPath) {
        $javaFiles = Get-ChildItem -Path $domainPath -Recurse -Filter "*.java" -File
        $importsInfra = $false
        
        foreach ($file in $javaFiles) {
            $content = Get-Content $file.FullName -Raw
            if ($content -match 'import.*infrastructure') {
                $importsInfra = $true
                Log-Fail "$($file.Name) importa infrastructure (viola regla de dependencia)"
            }
        }
        
        if (-not $importsInfra) {
            Log-Pass "Domain no depende de infrastructure"
        }
    }
}

function Generate-Report {
    Write-Output ""
    Write-Output "========================================="
    Write-Output "         INFORME DE VALIDACIÓN"
    Write-Output "========================================="
    Write-Output "Proyecto analizado: $(Resolve-Path $ProjectRoot)"
    Write-Output "Nivel de validación: $ValidationLevel"
    Write-Output ""
    Write-Output "RESULTADOS:"
    Write-Output "  Total de verificaciones: $global:TotalChecks"
    Write-Output "  ✓ Aprobadas: $global:PassCount"
    Write-Output "  ⚠ Advertencias: $global:WarnCount"
    Write-Output "  ✗ Fallos: $global:FailCount"
    Write-Output ""
    
    # Calcular puntuación
    if ($global:TotalChecks -gt 0) {
        $score = [math]::Round(($global:PassCount * 100) / $global:TotalChecks)
        Write-Output "PUNTUACIÓN HEXAGONAL: ${score}%"
        Write-Output ""
        
        if ($score -ge 90) {
            Write-Color "✅ EXCELENTE: Arquitectura hexagonal bien implementada" "Green"
        } elseif ($score -ge 70) {
            Write-Color "✅ BUENO: Arquitectura hexagonal implementada con algunas mejoras posibles" "Green"
        } elseif ($score -ge 50) {
            Write-Color "⚠ ACEPTABLE: Se detecta estructura hexagonal pero necesita refactorización" "Yellow"
        } else {
            Write-Color "✗ INSUFICIENTE: La arquitectura hexagonal no está correctamente implementada" "Red"
        }
    }
    
    # Generar archivo de reporte
    $reportFile = Join-Path $ProjectRoot "hexagonal-validation-report.md"
    $reportContent = @"
# Reporte de Validación Hexagonal
**Fecha**: $(Get-Date -Format "yyyy-MM-dd HH:mm:ss")
**Proyecto**: $(Split-Path $ProjectRoot -Leaf)
**Puntuación**: ${score}%

## Resumen
- ✅ Aprobadas: $global:PassCount
- ⚠ Advertencias: $global:WarnCount  
- ✗ Fallos: $global:FailCount

## Estructura del Proyecto
\`\`\`
$(Get-ChildItem -Path "$ProjectRoot/src/main/java" -Recurse -Directory | 
  ForEach-Object { $_.FullName.Replace($ProjectRoot, "") } | Sort-Object)
\`\`\`

## Recomendaciones
$(if ($global:FailCount -gt 0) {
    "1. Corregir los $global:FailCount fallos críticos"
})
$(if ($global:WarnCount -gt 0) {
    "2. Revisar las $global:WarnCount advertencias"
})
"@
    
    $reportContent | Out-File -FilePath $reportFile -Encoding UTF8
    Log-Info "Reporte generado: $reportFile"
}

# Función principal
function Main {
    Write-Output "========================================="
    Write-Output "  VALIDADOR DE ARQUITECTURA HEXAGONAL"
    Write-Output "========================================="
    Write-Output "Analizando proyecto: $ProjectRoot"
    Write-Output ""
    
    # Ejecutar validaciones
    Validate-ProjectStructure
    Validate-DomainLayer
    Validate-DependencyDirection
    
    # Generar reporte
    Generate-Report
    
    # Exit code basado en resultados
    if ($global:FailCount -gt 0) {
        exit 1
    } elseif ($global:WarnCount -gt 0 -and $ValidationLevel -eq "strict") {
        exit 2
    } else {
        exit 0
    }
}

# Ejecutar
Main