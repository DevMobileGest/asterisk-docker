#!/bin/bash
# Script para generar certificados SSL automáticamente dentro del contenedor

CERTS_DIR="/etc/apache2/certs"

# Crear directorio si no existe
mkdir -p "$CERTS_DIR"

# Si ya existen los certificados, salir
if [ -f "$CERTS_DIR/server.crt" ] && [ -f "$CERTS_DIR/server.key" ]; then
    echo "Certificados SSL ya existen"
    exit 0
fi

echo "Generando certificados SSL automáticamente..."

# Valores por defecto
DOMAIN="${DOMAIN:-freepbx.local}"
SSL_COUNTRY="${SSL_COUNTRY:-US}"
SSL_STATE="${SSL_STATE:-State}"
SSL_CITY="${SSL_CITY:-City}"
SSL_ORG="${SSL_ORG:-Organization}"
SSL_OU="${SSL_OU:-Unit}"
SSL_EMAIL="${SSL_EMAIL:-admin@${DOMAIN}}"

# Generar clave privada
openssl genrsa -out "$CERTS_DIR/server.key" 3072 2>/dev/null

# Generar certificado autofirmado
openssl req -new -x509 -key "$CERTS_DIR/server.key" -out "$CERTS_DIR/server.crt" -days 365 \
    -subj "/C=$SSL_COUNTRY/ST=$SSL_STATE/L=$SSL_CITY/O=$SSL_ORG/OU=$SSL_OU/CN=$DOMAIN/emailAddress=$SSL_EMAIL" \
    2>/dev/null

# Permisos
chmod 644 "$CERTS_DIR/server.crt"
chmod 600 "$CERTS_DIR/server.key"

echo "Certificados SSL generados exitosamente en $CERTS_DIR"
