#!/bin/bash
echo "Creando topicos"
kafka-topics --bootstrap-server localhost:9092 --create --if-not-exists --topic messages-topic --partitions 3 --replication-factor 1
echo "Tópicos creados exitosamente"
kafka-topics --bootstrap-server localhost:9092 --list