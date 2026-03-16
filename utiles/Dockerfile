FROM eclipse-temurin:21-jre
# IMPORTANTE: Usar ARG para forzar rebuild cuando cambia el JAR
ARG CACHEBUST=1
WORKDIR /app
# Copiar el JAR (usar wildcard para evitar problemas de nombre)
COPY target/*.jar app.jar
# Exponer puerto
EXPOSE 8084
# Comando de ejecución
CMD ["java", "-jar", "app.jar"]
