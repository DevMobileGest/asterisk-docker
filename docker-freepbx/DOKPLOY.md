# Despliegue de FreePBX en Dokploy

Esta guía explica cómo desplegar FreePBX usando Dokploy, una plataforma de despliegue moderna para aplicaciones Docker.

## 📋 Requisitos Previos

1. **Servidor Dokploy instalado** (puedes instalarlo con un solo comando)
2. **Dominio configurado** apuntando a tu servidor Dokploy
3. **Acceso SSH** al servidor (para configuración inicial de certificados)

## 🚀 Método 1: Despliegue desde GitHub (Recomendado)

### Paso 1: Preparar el Repositorio

1. **Push tu código a GitHub** (si aún no lo has hecho):
   ```bash
   cd /home/cristian/Documentos/Projects/ASTERISK/asterisk-docker/docker-freepbx
   git add .
   git commit -m "FreePBX con SSL automático"
   git push origin main
   ```

### Paso 2: Crear Aplicación en Dokploy

1. Accede a tu panel de Dokploy: `https://dokploy.tu-dominio.com`
2. Clic en **"Create Application"**
3. Selecciona **"Compose"** (no Docker simple)

### Paso 3: Configurar la Aplicación

**Configuración General:**
- **Name**: `freepbx-production`
- **Source Type**: `GitHub`
- **Repository**: `vidalinux/docker` (o tu fork)
- **Branch**: `main`
- **Compose Path**: `docker-freepbx/docker-compose.yml`

**Variables de Entorno:**

Dokploy te permite configurar variables de entorno en su interfaz. Agrega estas:

```env
# SSL Configuration
SSL_MODE=letsencrypt
DOMAIN=freepbx.ovox.io
SSL_EMAIL=asterisk@ovox.io

# Database Configuration
MYSQL_ROOT_PASSWORD=tu_password_seguro_aqui
DB_USER=asterisk
DB_PASS=tu_password_db_seguro
DBENGINE=mysql
DBNAME=asterisk
CDRDBNAME=asteriskcdrdb
DBHOST=172.18.0.2
DBPORT=3306

# FreePBX Configuration
USER=asterisk
GROUP=asterisk
WEBROOT=/var/www/html
ASTETCDIR=/etc/asterisk
ASTMODDIR=/usr/lib64/asterisk/modules
ASTVARLIBDIR=/var/lib/asterisk
ASTAGIDIR=/var/lib/asterisk/agi-bin
ASTSPOOLDIR=/var/spool/asterisk
ASTRUNDIR=/var/run/asterisk
ASTLOGDIR=/var/log/asterisk
AMPBIN=/var/lib/asterisk/bin
AMPSBIN=/usr/sbin
AMPCGIBIN=/var/www/cgi-bin
AMPPLAYBACK=/var/lib/asterisk/playback

# Timezone
TZ=America/Puerto_Rico

# Network Configuration
NETWORK_SUBNET=172.18.0.0/24
NETWORK_GATEWAY=172.18.0.1
MARIADB_IP=172.18.0.2
FREEPBX_IP=172.18.0.3

# Port Configuration
HTTPS_PORT=443
HTTP_PORT=80
IAX2_PORT=4569
AMI_PORT=4445
SIP_PORT=5060
SIP_TLS_PORT=5061
PJSIP_PORT=5160
RTP_START=18000
RTP_END=18100

# Container Configuration
FREEPBX_IMAGE=docker.io/ovox/freepbx:17.0
MARIADB_IMAGE=mariadb:latest
FREEPBX_CONTAINER_NAME=freepbx_server
MARIADB_CONTAINER_NAME=freepbx_mariadb
RESTART_POLICY=always
```

### Paso 4: Configurar Puertos

En la sección **"Ports"** de Dokploy, mapea los siguientes puertos:

| Container Port | Host Port | Protocol | Descripción |
|----------------|-----------|----------|-------------|
| 443 | 443 | TCP | HTTPS |
| 4445 | 4445 | TCP | Asterisk Manager |
| 4569 | 4569 | UDP | IAX2 |
| 5060 | 5060 | TCP/UDP | SIP |
| 5160 | 5160 | UDP | PJSIP |
| 18000-18100 | 18000-18100 | UDP | RTP |

### Paso 5: Configurar Volúmenes Persistentes

Dokploy maneja volúmenes automáticamente, pero asegúrate de que estos estén configurados:

- `./certs:/etc/apache2/certs`
- `./datadb:/var/lib/mysql`
- `./sql:/docker-entrypoint-initdb.d`

### Paso 6: Generar Certificados SSL

**Importante**: Antes del primer despliegue, necesitas SSH al servidor para generar certificados:

```bash
# Conecta al servidor
ssh user@tu-servidor-dokploy.com

# Navega al directorio de la aplicación Dokploy
cd /etc/dokploy/applications/freepbx-production

# Genera certificados (Dokploy creará el .env automáticamente)
bash init-ssl.sh
```

### Paso 7: Desplegar

1. En Dokploy, clic en **"Deploy"**
2. Dokploy hará:
   - Pull del repositorio
   - Leer el `docker-compose.yml`
   - Aplicar variables de entorno
   - Construir/pull imágenes
   - Iniciar contenedores

3. Monitorea los logs en tiempo real desde la interfaz de Dokploy

## 🔧 Método 2: Despliegue Manual en Servidor Dokploy

Si prefieres control total:

### Paso 1: Conecta al Servidor

```bash
ssh user@tu-servidor-dokploy.com
```

### Paso 2: Clona el Repositorio

```bash
cd /opt
git clone https://github.com/vidalinux/docker.git
cd docker/docker-freepbx
```

### Paso 3: Ejecuta el Setup

```bash
# Ejecuta el script de configuración
bash SETUP.sh

# Esto creará el .env y generará certificados SSL
```

### Paso 4: Despliega con Docker Compose

```bash
docker-compose up -d
```

### Paso 5: Configura Reverse Proxy en Dokploy (Opcional)

Si quieres usar el proxy de Dokploy:

1. En Dokploy, crea un **"Application"** tipo **"External"**
2. Apunta a `https://172.18.0.3:443` (IP del contenedor FreePBX)
3. Configura el dominio: `freepbx.ovox.io`

## 🌐 Configuración de Dominio

### Opción A: DNS Directo (Recomendado)

Apunta tu dominio directamente al servidor:

```
A Record: freepbx.ovox.io → IP_SERVIDOR
```

### Opción B: Usando Traefik de Dokploy

Si Dokploy usa Traefik, crea un archivo `traefik-labels.yml`:

```yaml
# Agregar a docker-compose.yml en el servicio server:
labels:
  - "traefik.enable=true"
  - "traefik.http.routers.freepbx.rule=Host(`freepbx.ovox.io`)"
  - "traefik.http.routers.freepbx.entrypoints=websecure"
  - "traefik.http.routers.freepbx.tls=true"
  - "traefik.http.routers.freepbx.tls.certresolver=letsencrypt"
  - "traefik.http.services.freepbx.loadbalancer.server.port=443"
```

## 🔐 SSL con Dokploy

Dokploy puede manejar SSL de dos formas:

### Opción 1: Certificados Propios (init-ssl.sh)

Usa el sistema que ya creamos:

```bash
# En el servidor
cd /ruta/a/freepbx
bash init-ssl.sh
```

### Opción 2: Let's Encrypt vía Dokploy

Dokploy puede generar certificados automáticamente:

1. En la configuración de la aplicación
2. Habilita **"SSL/TLS"**
3. Selecciona **"Let's Encrypt"**
4. Dokploy manejará renovación automática

## 📊 Monitoreo en Dokploy

Dokploy ofrece:

- **Logs en tiempo real** de todos los contenedores
- **Métricas** de CPU, RAM, disco
- **Health checks** automáticos
- **Alertas** configurables

## 🔄 Actualización y Re-despliegue

### Actualizar Código:

1. Push cambios a GitHub
2. En Dokploy → **"Redeploy"**
3. Dokploy hace pull y reinicia servicios

### Actualizar Variables de Entorno:

1. Edita en la interfaz de Dokploy
2. Click **"Restart"** (no necesita rebuild)

## 📝 Archivo de Configuración Dokploy

Crea `dokploy.yml` en la raíz del proyecto para configuración avanzada:

```yaml
version: '1'

project:
  name: freepbx-production
  
services:
  - name: freepbx
    type: compose
    compose_file: docker-compose.yml
    env_file: .env
    
    ports:
      - "443:443"
      - "5060:5060/udp"
      - "4569:4569/udp"
      - "18000-18100:18000-18100/udp"
    
    healthcheck:
      enabled: true
      endpoint: "https://localhost/admin"
      interval: 30s
      timeout: 10s
      retries: 3
    
    volumes:
      - type: bind
        source: ./certs
        target: /etc/apache2/certs
      - type: volume
        source: freepbx_data
        target: /var/lib/asterisk

volumes:
  freepbx_data:
    driver: local
```

## 🛠️ Troubleshooting con Dokploy

### Ver Logs:

En la interfaz de Dokploy:
- **Logs Tab** → Selecciona servicio (`server` o `mariadb`)
- Filtra por timestamp
- Descarga logs si necesitas

### Reiniciar Servicios:

```bash
# Desde la interfaz Dokploy
Click en "Restart" para el servicio específico

# O desde SSH
cd /etc/dokploy/applications/freepbx-production
docker-compose restart
```

### Verificar Health:

```bash
# SSH al servidor
docker ps
docker exec freepbx_server asterisk -rx "core show version"
```

## 💡 Ventajas de Usar Dokploy

1. ✅ **Interfaz gráfica** para gestionar contenedores
2. ✅ **Git integration** - Deploy automático con push
3. ✅ **SSL automático** con Let's Encrypt
4. ✅ **Monitoreo integrado** - Logs, métricas, alertas
5. ✅ **Backup fácil** - Snapshot de volúmenes
6. ✅ **Multi-servidor** - Gestiona varios servidores desde un panel
7. ✅ **Webhooks** - Deploy automático con eventos
8. ✅ **Rollback** - Vuelve a versiones anteriores fácilmente

## 🎯 Recomendaciones Específicas para FreePBX en Dokploy

1. **Usa volúmenes nombrados** para datos críticos:
   ```yaml
   volumes:
     - freepbx_asterisk:/var/lib/asterisk
     - freepbx_etc:/etc/asterisk
     - freepbx_db:/var/lib/mysql
   ```

2. **Configura backups automáticos** en Dokploy:
   - Schedule: Diario a las 2 AM
   - Retention: 7 días
   - Include: Todos los volúmenes

3. **Habilita health checks** para auto-recovery

4. **Usa secrets** de Dokploy para passwords (no .env plano)

5. **Configura alertas** para:
   - Container down
   - Alto uso de CPU (>80%)
   - Disco lleno (>90%)

## 📚 Recursos Adicionales

- **Dokploy Docs**: https://docs.dokploy.com
- **FreePBX Wiki**: https://wiki.freepbx.org
- **Este proyecto**: Ver [README.md](./README.md)

## 🚨 Notas Importantes

1. **Puertos UDP**: Asegúrate que el firewall de Dokploy permita UDP para RTP (18000-18100)

2. **NAT Configuration**: Si Dokploy está detrás de NAT, configura Asterisk con IP externa:
   ```bash
   docker exec freepbx_server fwconsole setting EXTERNAL_IP tu_ip_publica
   ```

3. **Performance**: FreePBX puede requerir recursos significativos. Mínimo recomendado:
   - 2 CPUs
   - 4GB RAM
   - 20GB disco SSD

4. **Seguridad**: Cambia todas las contraseñas por defecto antes del primer despliegue

## ✅ Checklist de Despliegue

- [ ] Servidor Dokploy instalado y accesible
- [ ] Dominio apuntando al servidor
- [ ] Repositorio GitHub configurado
- [ ] Variables de entorno configuradas en Dokploy
- [ ] Puertos mapeados correctamente
- [ ] Firewall configurado para UDP
- [ ] Certificados SSL generados
- [ ] Primera aplicación desplegada
- [ ] Health checks pasando
- [ ] Acceso a FreePBX web interface verificado
- [ ] Asterisk CLI accesible
- [ ] Backups automáticos configurados

---

¿Necesitas ayuda con algún paso específico del despliegue en Dokploy?
