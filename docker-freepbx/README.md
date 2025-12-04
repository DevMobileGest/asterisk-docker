# FreePBX Docker with Automated SSL

A comprehensive Docker setup for FreePBX with automated SSL certificate generation using either self-signed certificates or Let's Encrypt.

## Features

- 🔒 **Automated SSL certificate generation** - Choose between self-signed or Let's Encrypt
- ⚙️ **Environment-based configuration** - All settings configurable via `.env` file
- 🚀 **One-command setup** - Interactive setup script guides you through configuration
- 🔄 **Automatic certificate renewal** - Built-in support for Let's Encrypt renewal
- 📦 **Docker Compose** - Easy deployment and management
- 🏥 **Health checks** - Ensures services are ready before starting dependent containers

## Quick Start

### Prerequisites

- Docker and Docker Compose installed
- OpenSSL (for self-signed certificates)
- Certbot (for Let's Encrypt - installed automatically if needed)
- For Let's Encrypt: Valid domain name pointing to your server

### Installation

1. **Clone the repository** (if not already cloned):
   ```bash
   git clone https://github.com/vidalinux/docker.git
   cd docker/docker-freepbx
   ```

2. **Run the setup script**:
   ```bash
   bash SETUP.sh
   ```
   
   The setup script will:
   - Check prerequisites
   - Create and configure `.env` file interactively
   - Generate SSL certificates based on your chosen mode
   - Set up necessary directories and permissions

3. **Start the containers**:
   ```bash
   docker-compose up -d
   ```

4. **Access FreePBX**:
   - Open your browser and navigate to: `https://your-domain.com/admin`
   - Follow the first-time setup wizard
   - Default username: `admin`
   - Password will be set during first login

## Configuration

### Environment Variables

All configuration is managed through the `.env` file. Copy `.env.example` to `.env` and customize:

```bash
cp .env.example .env
nano .env
```

#### Key Configuration Options

| Variable | Description | Default |
|----------|-------------|---------|
| `SSL_MODE` | SSL certificate mode (`selfsigned` or `letsencrypt`) | `selfsigned` |
| `DOMAIN` | Your FreePBX domain name | `freepbx.ovox.io` |
| `SSL_EMAIL` | Email for SSL notifications (required for Let's Encrypt) | `asterisk@ovox.io` |
| `MYSQL_ROOT_PASSWORD` | MariaDB root password | `asterisk` |
| `DB_PASS` | Asterisk database user password | `asteriskpass` |
| `TZ` | Timezone | `America/Puerto_Rico` |

See `.env.example` for all available configuration options.

### SSL Certificate Modes

#### Self-Signed Certificates (Development/Testing)

Best for:
- Development environments
- Internal networks
- Testing purposes

Configuration:
```bash
SSL_MODE=selfsigned
DOMAIN=freepbx.local
SSL_EMAIL=admin@example.com
```

Generate certificates:
```bash
bash init-ssl.sh
```

The script will create a self-signed certificate valid for 365 days.

#### Let's Encrypt Certificates (Production)

Best for:
- Production deployments
- Public-facing servers
- Valid SSL certificates trusted by browsers

**Requirements:**
- Valid domain name pointing to your server
- Ports 80 and 443 accessible from the internet
- Email address for certificate notifications

Configuration:
```bash
SSL_MODE=letsencrypt
DOMAIN=freepbx.example.com
SSL_EMAIL=admin@example.com
```

Generate certificates:
```bash
bash init-ssl.sh
```

**Certificate Renewal:**

Let's Encrypt certificates expire after 90 days. Set up automatic renewal:

```bash
# Add to crontab (run daily at midnight)
0 0 * * * certbot renew --quiet && docker-compose restart server
```

Or use the certbot service in docker-compose (uncomment the certbot service).

## Manual SSL Certificate Setup

If you prefer to use existing certificates:

1. Create the `certs` directory:
   ```bash
   mkdir -p certs
   ```

2. Copy your certificate and key:
   ```bash
   cp your-certificate.crt certs/server.crt
   cp your-private-key.key certs/server.key
   ```

3. Set proper permissions:
   ```bash
   chmod 644 certs/server.crt
   chmod 600 certs/server.key
   ```

## Usage

### Common Commands

Using the provided Makefile:

```bash
# Run initial setup
make setup

# Start containers
make start

# Stop containers
make stop

# View logs
make logs

# Restart containers
make restart

# Renew SSL certificates (Let's Encrypt)
make renew-ssl

# Clean up (removes containers and volumes)
make clean
```

Using docker-compose directly:

```bash
# Start containers
docker-compose up -d

# Stop containers
docker-compose down

# View logs
docker-compose logs -f

# Restart a specific service
docker-compose restart server

# Rebuild and start
docker-compose up -d --build
```

## Directory Structure

```
docker-freepbx/
├── .env                  # Your configuration (git-ignored)
├── .env.example          # Configuration template
├── certs/                # SSL certificates (created by init-ssl.sh)
│   ├── server.crt
│   └── server.key
├── datadb/               # MariaDB data (persistent)
├── sql/                  # SQL initialization scripts
├── docker-compose.yml    # Docker Compose configuration
├── Dockerfile            # FreePBX Docker image
├── default-ssl.conf      # Apache SSL configuration
├── init-ssl.sh           # SSL certificate generation script
├── SETUP.sh              # Interactive setup script
├── Makefile              # Convenience commands
└── README.md             # This file
```

## Networking

The containers use a custom bridge network with static IP addresses:

| Service | IP Address | Ports |
|---------|------------|-------|
| MariaDB | 172.18.0.2 | 3306 (internal only) |
| FreePBX | 172.18.0.3 | 443 (HTTPS), 5060 (SIP), 4569 (IAX2), etc. |

### Port Mapping

| Port | Protocol | Service | Description |
|------|----------|---------|-------------|
| 443 | TCP | HTTPS | Web interface |
| 4445 | TCP | AMI | Asterisk Manager Interface |
| 4569 | UDP | IAX2 | Inter-Asterisk eXchange |
| 5060 | TCP/UDP | SIP | Session Initiation Protocol |
| 5160 | UDP | PJSIP | PJSIP Protocol |
| 18000-18100 | UDP | RTP | Real-time Transport Protocol (audio/video) |

## Troubleshooting

### Certificate Issues

**Problem:** "SSL certificate already exists"  
**Solution:** The script detects existing certificates. Choose to regenerate or keep existing ones.

**Problem:** Let's Encrypt validation fails  
**Solution:**
1. Verify domain points to your server: `dig +short your-domain.com`
2. Check ports 80 and 443 are open: `sudo netstat -tuln | grep -E ':(80|443)'`
3. Ensure no other service is using port 80
4. Temporarily stop FreePBX: `docker-compose down`

### Container Issues

**Problem:** MariaDB container won't start  
**Solution:**
1. Check logs: `docker-compose logs mariadb`
2. Verify datadb directory permissions: `ls -la datadb/`
3. Try removing and recreating: `rm -rf datadb/ && mkdir datadb`

**Problem:** FreePBX container fails to start  
**Solution:**
1. Check if MariaDB is healthy: `docker-compose ps`
2. Verify environment variables: `docker-compose config`
3. Check logs: `docker-compose logs server`

### Network Issues

**Problem:** Cannot access web interface  
**Solution:**
1. Verify container is running: `docker-compose ps`
2. Check firewall allows port 443: `sudo ufw status`
3. Verify SSL certificates exist: `ls -la certs/`
4. Check Apache logs: `docker-compose logs server | grep apache`

**Problem:** SIP/RTP not working  
**Solution:**
1. Ensure UDP ports are open in firewall
2. Configure Asterisk with your external IP
3. Check NAT settings if behind router

### Permission Issues

**Problem:** Permission denied on sql directory  
**Solution:**
```bash
chmod 755 -R sql/
```

**Problem:** Cannot write to volumes  
**Solution:**
```bash
# Fix ownership
sudo chown -R $(whoami):$(whoami) datadb/ certs/
```

## Upgrading

### Upgrading FreePBX

1. Update the image version in `.env`:
   ```bash
   FREEPBX_IMAGE=docker.io/ovox/freepbx:18.0
   ```

2. Pull the new image and restart:
   ```bash
   docker-compose pull
   docker-compose up -d
   ```

### Migrating from Manual Setup

If you have an existing FreePBX setup with manual certificates:

1. Backup your current certificates:
   ```bash
   cp -r certs certs.backup
   ```

2. Run the setup script:
   ```bash
   bash SETUP.sh
   ```

3. The script will detect existing certificates and ask if you want to regenerate them

## Security Considerations

- **Change default passwords** in `.env` file before deployment
- **Use Let's Encrypt** for production deployments
- **Restrict access** to the `.env` file: `chmod 600 .env`
- **Enable firewall** and only open necessary ports
- **Regular updates** - Keep Docker images and host system updated
- **Backup regularly** - Backup `datadb/`, `certs/`, and volumes

## Backup and Restore

### Backup

```bash
# Backup all data
tar -czf freepbx-backup-$(date +%Y%m%d).tar.gz \
  datadb/ certs/ .env

# Backup Docker volumes
docker run --rm -v freepbx_varvol:/data -v $(pwd):/backup \
  alpine tar -czf /backup/volumes-backup.tar.gz /data
```

### Restore

```bash
# Restore data
tar -xzf freepbx-backup-YYYYMMDD.tar.gz

# Restart containers
docker-compose up -d
```

## Support

For issues and questions:

- GitHub Issues: [vidalinux/docker](https://github.com/vidalinux/docker/issues)
- FreePBX Forums: [FreePBX Community](https://community.freepbx.org/)
- Email: acvelez@vidalinux.com

## License

This project is provided as-is for use with FreePBX Docker deployments.

## Credits

- Maintained by: acvelez@vidalinux.com
- FreePBX: [FreePBX Project](https://www.freepbx.org/)
- Asterisk: [Asterisk Project](https://www.asterisk.org/)

## Changelog

### Version 2.0 (Current)
- ✨ Added automated SSL certificate generation
- ✨ Added environment-based configuration
- ✨ Added interactive setup script
- ✨ Added Let's Encrypt support
- ✨ Added health checks for MariaDB
- ✨ Improved docker-compose with service dependencies
- 📝 Comprehensive documentation

### Version 1.0
- Initial Docker setup
- Manual SSL certificate configuration
- Basic docker-compose setup
