# Troubleshooting: MariaDB Unhealthy en Dokploy

## Problema
```
Container freepbx_mariadb  Waiting
Container freepbx_mariadb  Error
dependency failed to start: container freepbx_mariadb is unhealthy
```

## Causas Comunes y Soluciones

### 1. ✅ Variable DBHOST Incorrecta

**Problema**: En tu `.env` tienes:
```bash
DBHOST=172.18.0.2  # ❌ IP antigua
```

**Solución**: Debe coincidir con `MARIADB_IP`:
```bash
DBHOST=172.32.0.2  # ✅ Correcto
MARIADB_IP=172.32.0.2
```

**Cómo arreglarlo en Dokploy**:
1. Ve a tu aplicación en Dokploy
2. Click en "Environment Variables"
3. Encuentra `DBHOST`
4. Cambia a `172.32.0.2`
5. Click "Save" y "Redeploy"

---

### 2. ⏱️ MariaDB Necesita Más Tiempo para Inicializar

Cuando despliegas por primera vez, MariaDB debe:
- Inicializar la base de datos
- Crear usuarios y permisos
- Ejecutar scripts SQL en `/docker-entrypoint-initdb.d`
- Esto puede tomar 30-90 segundos

**Solución**: Ya actualicé el `docker-compose.yml` con health check más tolerante:

```yaml
healthcheck:
  test: ["CMD", "mysqladmin", "ping", "-h", "localhost", "-p${MYSQL_ROOT_PASSWORD}"]
  interval: 30s        # Aumentado de 10s
  timeout: 10s         # Aumentado de 5s
  retries: 10          # Aumentado de 5
  start_period: 60s    # Nuevo: espera inicial
```

**Haz push de este cambio**:
```bash
git add docker-compose.yml
git commit -m "Increased MariaDB health check timeouts"
git push origin master
```

Dokploy auto-desplegará con los nuevos tiempos.

---

### 3. 🗄️ Volumen Corrupto o con Permisos Incorrectos

Si ya habías desplegado antes, los datos anteriores pueden estar corruptos.

**Solución en Dokploy**:

1. **Opción A: Limpiar volúmenes (DESTRUCTIVO - borra datos)**
   - En Dokploy, ve a tu aplicación
   - Click en "Volumes"
   - Delete el volumen `datadb`
   - Redeploy

2. **Opción B: Revisar logs en Dokploy**
   - Ve a "Logs" → Selecciona `mariadb` service
   - Busca errores como:
     ```
     [ERROR] InnoDB: Operating system error
     [ERROR] Can't start server
     [ERROR] Aborting
     ```

---

### 4. 🔐 Password Vacío o Inválido

**Verifica** que en Dokploy tengas:

```bash
MYSQL_ROOT_PASSWORD=tu_password_seguro_aqui  # NO DEBE ESTAR VACÍO
```

**Si está vacío o tiene caracteres especiales**, cámbialo:

```bash
# Usa un password simple sin caracteres especiales (', ", $, \, `)
MYSQL_ROOT_PASSWORD=FreePBX2024Secure
```

---

### 5. 🐳 Recursos Insuficientes en Dokploy

MariaDB requiere:
- **Mínimo**: 1GB RAM
- **Recomendado**: 2GB RAM

**Verifica en Dokploy**:
1. Ve a Server → Resources
2. Chequea RAM disponible
3. Si está muy alto (>90%), aumenta los recursos del servidor

---

## 🎯 Procedimiento Completo de Troubleshooting

### Paso 1: Actualizar Variables en Dokploy

En **Environment Variables**:

```bash
# Corregir IP
DBHOST=172.32.0.2

# Verificar password
MYSQL_ROOT_PASSWORD=tu_password_seguro_aqui

# Todas las IPs deben ser 172.32.0.x
NETWORK_SUBNET=172.32.0.0/24
NETWORK_GATEWAY=172.32.0.1
MARIADB_IP=172.32.0.2
FREEPBX_IP=172.32.0.3
```

### Paso 2: Push del Health Check Mejorado

```bash
cd /home/cristian/Documentos/Projects/ASTERISK/asterisk-docker/docker-freepbx

# Verificar que docker-compose.yml tiene los nuevos timeouts
git add docker-compose.yml
git commit -m "Fix: Increased MariaDB health check timeouts"
git push origin master
```

### Paso 3: Limpiar y Redesplegar en Dokploy

**Opción A: Redesploy sin limpiar volúmenes**
1. En Dokploy, click "Redeploy"
2. Espera 2-3 minutos
3. Monitorea logs en tiempo real

**Opción B: Limpieza completa (si Opción A falla)**
1. Stop la aplicación
2. Delete volúmenes (datadb, volumes de postgres si existen)
3. Redeploy
4. Espera 3-5 minutos para inicialización completa

### Paso 4: Monitorear Logs

En Dokploy:
1. Logs → Service: `mariadb`
2. Busca:
   ```
   ✅ Éxito:
   "mysqld: ready for connections"
   "Version: '11.x.x-MariaDB'"
   
   ❌ Error:
   "[ERROR]"
   "Aborting"
   "Can't start server"
   ```

### Paso 5: Verificar Conectividad

Una vez MariaDB esté healthy:

1. En Dokploy, abre shell del contenedor MariaDB:
   ```bash
   mysql -uroot -p$MYSQL_ROOT_PASSWORD -e "SELECT VERSION();"
   ```

2. Verifica que FreePBX puede conectar:
   ```bash
   mysql -uasterisk -p$DB_PASS -h 172.32.0.2 -e "SHOW DATABASES;"
   ```

---

## 📋 Checklist de Verificación

- [ ] `DBHOST=172.32.0.2` en variables de Dokploy
- [ ] `MYSQL_ROOT_PASSWORD` no está vacío
- [ ] `MARIADB_IP=172.32.0.2` coincide con DBHOST
- [ ] Health check actualizado (start_period: 60s)
- [ ] Git push del docker-compose.yml actualizado
- [ ] Volúmenes limpios (si es primer despliegue)
- [ ] Recursos suficientes en servidor (>2GB RAM)
- [ ] Logs de MariaDB no muestran [ERROR]

---

## 🚀 Comando Rápido de Verificación

Si tienes acceso SSH al servidor Dokploy:

```bash
# Ver logs en tiempo real
docker logs -f freepbx_mariadb

# Verificar el health check manualmente
docker exec freepbx_mariadb mysqladmin ping -h localhost -ptu_password

# Ver estado del contenedor
docker inspect freepbx_mariadb | grep -A 10 Health
```

---

## 💡 Tips Adicionales

1. **Primera vez siempre toma más tiempo** - Ten paciencia, espera 3-5 minutos
2. **Monitorea RAM** - MariaDB puede consumir bastante en inicialización
3. **Si falla repetidamente** - Elimina volúmenes y empieza limpio
4. **Passwords simples** - Evita caracteres especiales en MYSQL_ROOT_PASSWORD
5. **Check de red** - Asegura que la subnet 172.32.0.0/24 no esté en uso

---

## 🆘 Si Todo Falla

Puede deshabilitar temporalmente el health check:

```yaml
# En docker-compose.yml, comenta el health check de MariaDB
  mariadb:
    container_name: ${MARIADB_CONTAINER_NAME:-freepbx_mariadb}
    image: ${MARIADB_IMAGE:-mariadb:latest}
    restart: ${RESTART_POLICY:-always}
    # healthcheck:  # ← Comentar temporalmente
    #   test: ["CMD", "mysqladmin", "ping", "-h", "localhost"]
    #   ...
```

Y en el servicio FreePBX:

```yaml
  server:
    # ...
    # depends_on:  # ← Comentar temporalmente el health check dependency
    #   mariadb:
    #     condition: service_healthy
    depends_on:
      - mariadb  # Solo espera que inicie, no que esté healthy
```

**⚠️ Solo úsalo temporalmente para debugging!**
