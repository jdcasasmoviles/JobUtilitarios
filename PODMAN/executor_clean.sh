#!/bin/sh
echo "=== LIMPIEZA COMPLETA DE ALPINE LINUX ==="

# Mostrar espacio antes
echo "📊 Espacio en disco ANTES de limpiar:"
df -h /

# 1. Limpiar caché de paquetes
echo -e "\n🧹 Limpiando caché de APK..."
apk cache clean 2>/dev/null
rm -rf /var/cache/apk/*
echo "   ✅ Caché de APK limpiado"

# 2. Limpiar logs
echo -e "\n🧹 Limpiando logs del sistema..."
> /var/log/messages 2>/dev/null
> /var/log/syslog 2>/dev/null
rm -f /var/log/*.log.* 2>/dev/null
rm -f /var/log/*.gz 2>/dev/null
echo "   ✅ Logs limpiados"

# 3. Limpiar temporales
echo -e "\n🧹 Limpiando archivos temporales..."
rm -rf /tmp/* 2>/dev/null
rm -rf /var/tmp/* 2>/dev/null
echo "   ✅ Temporales limpiados"

# 4. Limpiar Podman
echo -e "\n🧹 Limpiando Podman..."
podman container prune -f > /dev/null 2>&1
podman image prune -a -f > /dev/null 2>&1
podman volume prune -f > /dev/null 2>&1
podman network prune -f > /dev/null 2>&1
podman system prune -a -f > /dev/null 2>&1
echo "   ✅ Podman limpiado"

# 5. Limpiar proyecto Spring
echo -e "\n🧹 Limpiando proyecto Spring..."
if [ -d "/root/spring-project" ]; then
    rm -rf /root/spring-project/target/* 2>/dev/null
    rm -f /root/spring-project/*.log 2>/dev/null
    rm -f /root/spring-project/*.tmp 2>/dev/null
    echo "   ✅ Proyecto Spring limpiado"
else
    echo "   ⚠️  No existe /root/spring-project"
fi

# Mostrar espacio después
echo -e "\n📊 Espacio en disco DESPUÉS de limpiar:"
df -h /

echo -e "\n✅ Limpieza completada"
