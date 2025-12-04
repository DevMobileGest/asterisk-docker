#!/bin/bash

##############################################################################
# FreePBX Docker Setup Script
# 
# This script guides you through the initial setup of FreePBX Docker
# with automated SSL certificate generation.
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"

# Function to print status messages
print_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

print_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

print_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

print_step() {
    echo -e "${BLUE}[STEP]${NC} $1"
}

# Print banner
print_banner() {
    echo -e "${GREEN}"
    cat << "EOF"
╔══════════════════════════════════════════════════════════╗
║                                                          ║
║       FreePBX Docker Setup & Configuration Tool         ║
║                                                          ║
╚══════════════════════════════════════════════════════════╝
EOF
    echo -e "${NC}"
}

# Check prerequisites
check_prerequisites() {
    print_step "Checking prerequisites..."
    
    local missing_deps=()
    
    # Check if Docker is installed
    if ! command -v docker &> /dev/null; then
        missing_deps+=("docker")
    fi
    
    # Check if Docker Compose is installed
    if ! command -v docker-compose &> /dev/null && ! docker compose version &> /dev/null; then
        missing_deps+=("docker-compose")
    fi
    
    # Check if openssl is installed
    if ! command -v openssl &> /dev/null; then
        missing_deps+=("openssl")
    fi
    
    if [ ${#missing_deps[@]} -ne 0 ]; then
        print_error "Missing required dependencies: ${missing_deps[*]}"
        print_info "Please install the missing dependencies and run this script again."
        exit 1
    fi
    
    print_info "All prerequisites are installed ✓"
}

# Create .env file if it doesn't exist
setup_env_file() {
    print_step "Setting up environment configuration..."
    
    if [ -f "${SCRIPT_DIR}/.env" ]; then
        print_warning ".env file already exists"
        read -p "Do you want to reconfigure it? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing .env file"
            return
        fi
        # Backup existing .env
        cp "${SCRIPT_DIR}/.env" "${SCRIPT_DIR}/.env.backup.$(date +%Y%m%d_%H%M%S)"
        print_info "Backed up existing .env file"
    fi
    
    # Copy example file
    cp "${SCRIPT_DIR}/.env.example" "${SCRIPT_DIR}/.env"
    print_info "Created .env file from template"
    
    # Interactive configuration
    echo ""
    print_info "Let's configure your FreePBX installation"
    print_warning "Press Enter to accept default values shown in [brackets]"
    echo ""
    
    # SSL Configuration
    echo -e "${BLUE}SSL Configuration${NC}"
    echo "─────────────────────────────────────────────────────"
    
    read -p "SSL Mode (selfsigned/letsencrypt) [selfsigned]: " ssl_mode
    ssl_mode=${ssl_mode:-selfsigned}
    sed -i "s/^SSL_MODE=.*/SSL_MODE=${ssl_mode}/" "${SCRIPT_DIR}/.env"
    
    read -p "Domain name [freepbx.ovox.io]: " domain
    domain=${domain:-freepbx.ovox.io}
    sed -i "s/^DOMAIN=.*/DOMAIN=${domain}/" "${SCRIPT_DIR}/.env"
    
    read -p "Email address [asterisk@${domain}]: " email
    email=${email:-asterisk@${domain}}
    sed -i "s/^SSL_EMAIL=.*/SSL_EMAIL=${email}/" "${SCRIPT_DIR}/.env"
    
    if [ "$ssl_mode" = "selfsigned" ]; then
        echo ""
        print_info "Self-signed certificate details (optional - press Enter to skip):"
        
        read -p "Country Code [US]: " country
        country=${country:-US}
        sed -i "s/^SSL_COUNTRY=.*/SSL_COUNTRY=${country}/" "${SCRIPT_DIR}/.env"
        
        read -p "State/Province [Puerto Rico]: " state
        state=${state:-Puerto Rico}
        sed -i "s/^SSL_STATE=.*/SSL_STATE=${state}/" "${SCRIPT_DIR}/.env"
        
        read -p "City [San Juan]: " city
        city=${city:-San Juan}
        sed -i "s/^SSL_CITY=.*/SSL_CITY=${city}/" "${SCRIPT_DIR}/.env"
        
        read -p "Organization [Vidalinux.com Corp.]: " org
        org=${org:-Vidalinux.com Corp.}
        sed -i "s/^SSL_ORG=.*/SSL_ORG=${org}/" "${SCRIPT_DIR}/.env"
    fi
    
    # Database Configuration
    echo ""
    echo -e "${BLUE}Database Configuration${NC}"
    echo "─────────────────────────────────────────────────────"
    
    read -p "MySQL Root Password [asterisk]: " mysql_root_pass
    mysql_root_pass=${mysql_root_pass:-asterisk}
    sed -i "s/^MYSQL_ROOT_PASSWORD=.*/MYSQL_ROOT_PASSWORD=${mysql_root_pass}/" "${SCRIPT_DIR}/.env"
    
    read -p "Asterisk DB User Password [asteriskpass]: " db_pass
    db_pass=${db_pass:-asteriskpass}
    sed -i "s/^DB_PASS=.*/DB_PASS=${db_pass}/" "${SCRIPT_DIR}/.env"
    
    # Timezone
    echo ""
    echo -e "${BLUE}Timezone Configuration${NC}"
    echo "─────────────────────────────────────────────────────"
    
    read -p "Timezone [America/Puerto_Rico]: " tz
    tz=${tz:-America/Puerto_Rico}
    sed -i "s|^TZ=.*|TZ=${tz}|" "${SCRIPT_DIR}/.env"
    
    echo ""
    print_info "Configuration saved to .env file ✓"
}

# Create necessary directories
create_directories() {
    print_step "Creating necessary directories..."
    
    # Create certs directory if it doesn't exist
    mkdir -p "${SCRIPT_DIR}/certs"
    
    # Create sql directory if it doesn't exist
    mkdir -p "${SCRIPT_DIR}/sql"
    
    # Create datadb directory for MySQL data
    mkdir -p "${SCRIPT_DIR}/datadb"
    
    # Set proper permissions
    chmod 755 "${SCRIPT_DIR}/sql"
    
    print_info "Directories created ✓"
}

# Generate SSL certificates
generate_ssl_certificates() {
    print_step "Generating SSL certificates..."
    
    # Make init-ssl.sh executable
    chmod +x "${SCRIPT_DIR}/init-ssl.sh"
    
    # Run the SSL initialization script
    bash "${SCRIPT_DIR}/init-ssl.sh"
}

# Display next steps
display_next_steps() {
    echo ""
    echo -e "${GREEN}╔══════════════════════════════════════════════════════════╗${NC}"
    echo -e "${GREEN}║                                                          ║${NC}"
    echo -e "${GREEN}║              Setup Completed Successfully! 🎉            ║${NC}"
    echo -e "${GREEN}║                                                          ║${NC}"
    echo -e "${GREEN}╚══════════════════════════════════════════════════════════╝${NC}"
    echo ""
    print_info "Next steps:"
    echo ""
    echo "  1. Review your configuration in .env file:"
    echo "     ${YELLOW}nano .env${NC}"
    echo ""
    echo "  2. Start the FreePBX container:"
    echo "     ${YELLOW}docker-compose up -d${NC}"
    echo ""
    echo "  3. View container logs:"
    echo "     ${YELLOW}docker-compose logs -f${NC}"
    echo ""
    echo "  4. Access FreePBX web interface:"
    echo "     ${YELLOW}https://$(grep DOMAIN .env | cut -d'=' -f2)/admin${NC}"
    echo ""
    echo "  5. First-time setup credentials:"
    echo "     - Username: ${YELLOW}admin${NC}"
    echo "     - Password: Will be set on first login"
    echo ""
    
    # Check SSL mode
    ssl_mode=$(grep "^SSL_MODE=" "${SCRIPT_DIR}/.env" | cut -d'=' -f2)
    if [ "$ssl_mode" = "letsencrypt" ]; then
        echo ""
        print_warning "Let's Encrypt Certificate Renewal:"
        echo "  - Certificates expire in 90 days"
        echo "  - Set up automatic renewal with cron:"
        echo "    ${YELLOW}0 0 * * * certbot renew --quiet${NC}"
    fi
    
    echo ""
    print_info "For more information, see README.md"
    echo ""
}

# Main execution
main() {
    print_banner
    
    check_prerequisites
    setup_env_file
    create_directories
    generate_ssl_certificates
    display_next_steps
}

# Run main function
main
