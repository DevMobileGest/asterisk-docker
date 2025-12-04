#!/bin/bash

##############################################################################
# SSL Certificate Initialization Script for FreePBX Docker
# 
# This script automates SSL certificate generation with support for:
# - Self-signed certificates (for testing/development)
# - Let's Encrypt certificates (for production)
#
# Configuration is read from .env file
##############################################################################

set -e

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Script directory
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CERTS_DIR="${SCRIPT_DIR}/certs"

# Load environment variables from .env file
if [ ! -f "${SCRIPT_DIR}/.env" ]; then
    echo -e "${RED}Error: .env file not found!${NC}"
    echo "Please copy .env.example to .env and configure it."
    exit 1
fi

# Source .env file
set -a
source "${SCRIPT_DIR}/.env"
set +a

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

# Validate required environment variables
validate_env() {
    local required_vars=("SSL_MODE" "DOMAIN")
    
    for var in "${required_vars[@]}"; do
        if [ -z "${!var}" ]; then
            print_error "Required environment variable $var is not set in .env file"
            exit 1
        fi
    done
    
    if [ "$SSL_MODE" != "selfsigned" ] && [ "$SSL_MODE" != "letsencrypt" ]; then
        print_error "SSL_MODE must be either 'selfsigned' or 'letsencrypt'"
        exit 1
    fi
    
    if [ "$SSL_MODE" = "letsencrypt" ] && [ -z "$SSL_EMAIL" ]; then
        print_error "SSL_EMAIL is required when using Let's Encrypt mode"
        exit 1
    fi
}

# Check if certificates already exist
check_existing_certs() {
    if [ -f "${CERTS_DIR}/server.crt" ] && [ -f "${CERTS_DIR}/server.key" ]; then
        print_warning "SSL certificates already exist in ${CERTS_DIR}"
        read -p "Do you want to regenerate them? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            print_info "Using existing certificates"
            exit 0
        fi
        print_info "Removing existing certificates..."
        rm -f "${CERTS_DIR}/server.crt" "${CERTS_DIR}/server.key" "${CERTS_DIR}/server.csr"
    fi
}

# Create certificates directory
create_certs_dir() {
    if [ ! -d "$CERTS_DIR" ]; then
        print_info "Creating certificates directory: ${CERTS_DIR}"
        mkdir -p "$CERTS_DIR"
    fi
}

# Generate self-signed certificate
generate_selfsigned() {
    print_info "Generating self-signed SSL certificate..."
    
    # Set defaults for optional variables
    SSL_COUNTRY="${SSL_COUNTRY:-US}"
    SSL_STATE="${SSL_STATE:-Puerto Rico}"
    SSL_CITY="${SSL_CITY:-San Juan}"
    SSL_ORG="${SSL_ORG:-Vidalinux.com Corp.}"
    SSL_OU="${SSL_OU:-Linux Consulting}"
    SSL_EMAIL="${SSL_EMAIL:-asterisk@${DOMAIN}}"
    
    # Create CSR configuration file
    cat > "${CERTS_DIR}/openssl.cnf" <<EOF
[req]
default_bits = 3072
prompt = no
default_md = sha256
distinguished_name = dn
req_extensions = v3_req

[dn]
C=${SSL_COUNTRY}
ST=${SSL_STATE}
L=${SSL_CITY}
O=${SSL_ORG}
OU=${SSL_OU}
CN=${DOMAIN}
emailAddress=${SSL_EMAIL}

[v3_req]
subjectAltName = @alt_names

[alt_names]
DNS.1 = ${DOMAIN}
DNS.2 = *.${DOMAIN}
EOF
    
    # Generate private key
    print_info "Generating RSA private key (3072 bits)..."
    openssl genrsa -out "${CERTS_DIR}/server.key" 3072 2>/dev/null
    
    # Generate certificate signing request
    print_info "Generating certificate signing request..."
    openssl req -new -key "${CERTS_DIR}/server.key" -out "${CERTS_DIR}/server.csr" \
        -config "${CERTS_DIR}/openssl.cnf" 2>/dev/null
    
    # Generate self-signed certificate (valid for 1 year)
    print_info "Generating self-signed certificate (valid for 365 days)..."
    openssl x509 -req -days 365 -in "${CERTS_DIR}/server.csr" \
        -signkey "${CERTS_DIR}/server.key" -out "${CERTS_DIR}/server.crt" \
        -extensions v3_req -extfile "${CERTS_DIR}/openssl.cnf" 2>/dev/null
    
    # Clean up temporary files
    rm -f "${CERTS_DIR}/openssl.cnf" "${CERTS_DIR}/server.csr"
    
    print_info "Self-signed certificate generated successfully!"
    print_info "Certificate: ${CERTS_DIR}/server.crt"
    print_info "Private key: ${CERTS_DIR}/server.key"
    
    # Display certificate info
    echo ""
    print_info "Certificate details:"
    openssl x509 -in "${CERTS_DIR}/server.crt" -text -noout | grep -E "Subject:|Issuer:|Not Before|Not After|DNS:"
}

# Generate Let's Encrypt certificate using certbot standalone mode
generate_letsencrypt() {
    print_info "Generating Let's Encrypt SSL certificate..."
    
    # Check if certbot is installed
    if ! command -v certbot &> /dev/null; then
        print_error "certbot is not installed!"
        print_info "Installing certbot..."
        
        # Install certbot based on OS
        if command -v apt-get &> /dev/null; then
            sudo apt-get update
            sudo apt-get install -y certbot
        elif command -v yum &> /dev/null; then
            sudo yum install -y certbot
        else
            print_error "Could not install certbot. Please install it manually."
            exit 1
        fi
    fi
    
    # Check if port 80 is available
    if netstat -tuln | grep -q ':80 '; then
        print_warning "Port 80 is in use. Make sure to stop any web server before generating Let's Encrypt certificate."
        print_warning "You can stop the FreePBX container with: docker-compose down"
        read -p "Continue anyway? (y/N): " -n 1 -r
        echo
        if [[ ! $REPLY =~ ^[Yy]$ ]]; then
            exit 1
        fi
    fi
    
    print_info "Requesting certificate from Let's Encrypt for domain: ${DOMAIN}"
    print_info "This will use standalone mode and requires ports 80 and 443 to be accessible from the internet."
    
    # Request certificate using certbot standalone mode
    sudo certbot certonly --standalone \
        --preferred-challenges http \
        --email "${SSL_EMAIL}" \
        --agree-tos \
        --no-eff-email \
        -d "${DOMAIN}" \
        --cert-path "${CERTS_DIR}/server.crt" \
        --key-path "${CERTS_DIR}/server.key" \
        --non-interactive || {
            print_error "Failed to generate Let's Encrypt certificate"
            print_info "Make sure:"
            print_info "  1. Domain ${DOMAIN} points to this server's public IP"
            print_info "  2. Ports 80 and 443 are open and accessible from the internet"
            print_info "  3. No other service is using port 80"
            exit 1
        }
    
    # Copy certificates to certs directory
    print_info "Copying certificates to ${CERTS_DIR}..."
    sudo cp "/etc/letsencrypt/live/${DOMAIN}/fullchain.pem" "${CERTS_DIR}/server.crt"
    sudo cp "/etc/letsencrypt/live/${DOMAIN}/privkey.pem" "${CERTS_DIR}/server.key"
    sudo chown $(whoami):$(whoami) "${CERTS_DIR}/server.crt" "${CERTS_DIR}/server.key"
    
    print_info "Let's Encrypt certificate generated successfully!"
    print_info "Certificate: ${CERTS_DIR}/server.crt"
    print_info "Private key: ${CERTS_DIR}/server.key"
    
    echo ""
    print_warning "Remember: Let's Encrypt certificates expire in 90 days"
    print_info "To renew: sudo certbot renew"
    print_info "You can set up automatic renewal with cron"
}

# Set proper permissions on certificate files
set_permissions() {
    print_info "Setting proper permissions on certificate files..."
    chmod 644 "${CERTS_DIR}/server.crt"
    chmod 600 "${CERTS_DIR}/server.key"
}

# Main execution
main() {
    print_info "FreePBX SSL Certificate Initialization"
    print_info "========================================"
    echo ""
    
    validate_env
    check_existing_certs
    create_certs_dir
    
    case "$SSL_MODE" in
        selfsigned)
            generate_selfsigned
            ;;
        letsencrypt)
            generate_letsencrypt
            ;;
        *)
            print_error "Unknown SSL_MODE: $SSL_MODE"
            exit 1
            ;;
    esac
    
    set_permissions
    
    echo ""
    print_info "SSL certificate initialization completed successfully!"
    print_info "You can now start the FreePBX container with: docker-compose up -d"
}

# Run main function
main
