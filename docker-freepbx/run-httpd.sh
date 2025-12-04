#!/bin/bash
# Note: Not using 'set -e' to prevent container crashes during installation
# We handle errors explicitly where needed

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
    # Preparar directorios necesarios para Asterisk
    echo "Preparando directorios de Asterisk..."
    mkdir -p /var/run/asterisk
    mkdir -p /var/log/asterisk
    chown -R asterisk:asterisk /var/run/asterisk
    chown -R asterisk:asterisk /var/log/asterisk
    chmod 755 /var/run/asterisk
    
    cd ${WORKDIR}
    echo "Iniciando Asterisk..."
    ./start_asterisk start
    
    # Esperar a que Asterisk esté realmente listo
    echo "Esperando a que Asterisk esté completamente operativo..."
    
    # Dar tiempo inicial para que Asterisk inicie
    sleep 3
    
    for i in {1..20}; do
        # Verificar si el proceso está corriendo
        if pgrep -x asterisk > /dev/null; then
            echo "Proceso Asterisk encontrado"
            
            # Verificar si el socket existe
            if [ -S /var/run/asterisk/asterisk.ctl ]; then
                echo "Socket de Asterisk encontrado"
                
                # Intentar comunicarse con Asterisk
                if su - asterisk -c "asterisk -rx 'core show version'" &>/dev/null; then
                    echo "✓ Asterisk está listo y respondiendo!"
                    return 0
                fi
            else
                echo "Socket no encontrado aún, verificando logs..."
                if [ -f /var/log/asterisk/full ]; then
                    tail -5 /var/log/asterisk/full | grep -i error || true
                fi
            fi
        fi
        
        echo "Esperando... ($i/20)"
        sleep 3
    done
    
    echo "⚠ Advertencia: Asterisk puede no estar completamente listo"
    echo "Continuando de todas formas..."
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
