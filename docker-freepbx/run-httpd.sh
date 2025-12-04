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

# Función para iniciar Asterisk
start_asterisk() {
    cd ${WORKDIR}
    ./start_asterisk start
}

# Instalación inicial de FreePBX
if [ ! -f /var/www/html/.pbx ]; then
    echo "Instalando FreePBX por primera vez..."
    start_asterisk
    sleep 5

    ./install --dbengine=${DBENGINE} --dbname=${DBNAME} --dbhost=${DBHOST} --dbport=${DBPORT} \
    --cdrdbname=${CDRDBNAME} --dbuser=${DBUSER} --dbpass=${DBPASS} --user=${USER} --group=${GROUP} \
    --webroot=${WEBROOT} --astetcdir=${ASTETCDIR} --astmoddir=${ASTMODDIR} --astvarlibdir=${ASTVARLIBDIR} \
    --astagidir=${ASTAGIDIR} --astspooldir=${ASTSPOOLDIR} --astrundir=${ASTRUNDIR} --astlogdir=${ASTLOGDIR} \
    --ampbin=${AMPBIN} --ampsbin=${AMPSBIN} --ampcgibin=${AMPCGIBIN} --ampplayback=${AMPPLAYBACK} -n

    fwconsole ma installall
    fwconsole reload
    fwconsole restart

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

    fwconsole reload
    fwconsole restart
fi

# Arrancar Apache en primer plano
echo "Iniciando Apache..."
/usr/sbin/apachectl -DFOREGROUND
