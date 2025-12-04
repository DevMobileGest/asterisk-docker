#!/bin/bash
set -e

WORKDIR=/usr/local/src/freepbx

# Generar certificados SSL si no existen
echo "Verificando certificados SSL..."
/usr/local/bin/auto-ssl-gen.sh

# Variables de conexión a MariaDB
DB_HOST=${DBHOST:-172.32.0.2}
DB_PORT=${DBPORT:-3306}

echo "Esperando a que MariaDB esté lista en $DB_HOST:$DB_PORT ..."
/usr/local/bin/wait-for-it.sh $DB_HOST:$DB_PORT --timeout=300 --strict -- echo "MariaDB está lista!"

# Función para iniciar Asterisk y esperar a que esté listo
start_asterisk() {
    cd ${WORKDIR}
    echo "Iniciando Asterisk..."
    ./start_asterisk start
    
    # Esperar a que Asterisk esté realmente listo
    echo "Esperando a que Asterisk esté completamente operativo..."
    for i in {1..30}; do
        if asterisk -rx "core show version" &>/dev/null; then
            echo "Asterisk está listo!"
            return 0
        fi
        echo "Esperando... ($i/30)"
        sleep 2
    done
    
    echo "Advertencia: Asterisk puede no estar completamente listo"
    return 1
}

# Instalación inicial de FreePBX
# Verificar si fwconsole existe (mejor indicador de instalación completa)
if [ ! -f /var/lib/asterisk/bin/fwconsole ] && [ ! -f /usr/sbin/fwconsole ]; then
    echo "Instalando FreePBX por primera vez..."
    start_asterisk

    echo "Iniciando instalador de FreePBX..."

    ./install --dbengine=${DBENGINE} --dbname=${DBNAME} --dbhost=${DBHOST} --dbport=${DBPORT} \
    --cdrdbname=${CDRDBNAME} --dbuser=${DBUSER} --dbpass=${DBPASS} --user=${USER} --group=${GROUP} \
    --webroot=${WEBROOT} --astetcdir=${ASTETCDIR} --astmoddir=${ASTMODDIR} --astvarlibdir=${ASTVARLIBDIR} \
    --astagidir=${ASTAGIDIR} --astspooldir=${ASTSPOOLDIR} --astrundir=${ASTRUNDIR} --astlogdir=${ASTLOGDIR} \
    --ampbin=${AMPBIN} --ampsbin=${AMPSBIN} --ampcgibin=${AMPCGIBIN} --ampplayback=${AMPPLAYBACK} -n

    # Ejecutar fwconsole solo si existe (debería existir después de la instalación)
    if command -v fwconsole &> /dev/null; then
        echo "Configurando módulos de FreePBX..."
        fwconsole ma installall
        fwconsole reload
        fwconsole restart
    else
        echo "Advertencia: fwconsole no encontrado después de la instalación"
    fi

    touch /var/www/html/.pbx

    mkdir -p /var/lib/asterisk/etc
    cp /etc/freepbx.conf /var/lib/asterisk/etc/
    chown -R asterisk:asterisk /var/lib/asterisk/etc

else
    echo "FreePBX ya instalado. Iniciando servicios..."
    start_asterisk

    # Reparar symlinks
    ln -sf /var/lib/asterisk/etc/freepbx.conf /etc/freepbx.conf
    ln -sf /var/lib/asterisk/bin/fwconsole /usr/sbin/fwconsole

    # Ejecutar fwconsole solo si existe
    if command -v fwconsole &> /dev/null; then
        echo "Recargando configuración de FreePBX..."
        fwconsole reload
        fwconsole restart
    else
        echo "Advertencia: fwconsole no encontrado. Es posible que FreePBX no esté instalado correctamente."
    fi
fi

# Arrancar Apache en primer plano
echo "Iniciando Apache..."
/usr/sbin/apachectl -DFOREGROUND
