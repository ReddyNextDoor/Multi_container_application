#!/bin/bash

# SSL Certificate Setup Script for Todo API
# This script sets up SSL certificates using Let's Encrypt

set -e

# Configuration
DOMAIN=${1:-"todo-api.example.com"}
EMAIL=${2:-"admin@example.com"}
STAGING=${3:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging function
log() {
    echo -e "${GREEN}[$(date +'%Y-%m-%d %H:%M:%S')] $1${NC}"
}

warn() {
    echo -e "${YELLOW}[$(date +'%Y-%m-%d %H:%M:%S')] WARNING: $1${NC}"
}

error() {
    echo -e "${RED}[$(date +'%Y-%m-%d %H:%M:%S')] ERROR: $1${NC}"
    exit 1
}

# Check if domain is provided
if [ "$DOMAIN" = "todo-api.example.com" ]; then
    error "Please provide a valid domain name as the first argument"
fi

# Check if email is provided
if [ "$EMAIL" = "admin@example.com" ]; then
    error "Please provide a valid email address as the second argument"
fi

log "Setting up SSL certificates for domain: $DOMAIN"
log "Email: $EMAIL"
log "Staging mode: $STAGING"

# Create SSL directories
log "Creating SSL certificate directories..."
mkdir -p ssl/letsencrypt
mkdir -p ssl/webroot
mkdir -p ssl/dhparam

# Generate DH parameters if they don't exist
if [ ! -f "ssl/dhparam/ssl-dhparams.pem" ]; then
    log "Generating DH parameters (this may take a while)..."
    openssl dhparam -out ssl/dhparam/ssl-dhparams.pem 2048
else
    log "DH parameters already exist"
fi

# Create initial certificate directory
mkdir -p "ssl/letsencrypt/live/$DOMAIN"

# Create dummy certificates for initial nginx startup
if [ ! -f "ssl/letsencrypt/live/$DOMAIN/fullchain.pem" ]; then
    log "Creating dummy SSL certificates for initial setup..."
    
    # Create dummy certificates
    openssl req -x509 -nodes -newkey rsa:2048 \
        -days 1 \
        -keyout "ssl/letsencrypt/live/$DOMAIN/privkey.pem" \
        -out "ssl/letsencrypt/live/$DOMAIN/fullchain.pem" \
        -subj "/CN=$DOMAIN"
    
    # Create chain file
    cp "ssl/letsencrypt/live/$DOMAIN/fullchain.pem" "ssl/letsencrypt/live/$DOMAIN/chain.pem"
    
    log "Dummy certificates created"
else
    log "SSL certificates already exist"
fi

# Update nginx configuration with the domain
log "Updating nginx configuration with domain: $DOMAIN"
if [ -f "nginx/custom-domain.conf.template" ]; then
    sed "s/DOMAIN_NAME/$DOMAIN/g" nginx/custom-domain.conf.template > nginx/nginx.conf
    log "Nginx configuration updated"
else
    warn "Custom domain template not found, using default configuration"
fi

# Start nginx with dummy certificates
log "Starting nginx with dummy certificates..."
docker-compose -f docker-compose.nginx-prod.yml up -d nginx

# Wait for nginx to be ready
log "Waiting for nginx to be ready..."
sleep 10

# Request real certificates
log "Requesting SSL certificates from Let's Encrypt..."

# Determine if we should use staging
STAGING_FLAG=""
if [ "$STAGING" = "true" ]; then
    STAGING_FLAG="--staging"
    warn "Using Let's Encrypt staging environment"
fi

# Request certificate
docker run --rm \
    -v "$(pwd)/ssl/letsencrypt:/etc/letsencrypt" \
    -v "$(pwd)/ssl/webroot:/var/www/certbot" \
    certbot/certbot certonly \
    --webroot \
    --webroot-path=/var/www/certbot \
    --email "$EMAIL" \
    --agree-tos \
    --no-eff-email \
    $STAGING_FLAG \
    -d "$DOMAIN"

if [ $? -eq 0 ]; then
    log "SSL certificates obtained successfully!"
    
    # Reload nginx with real certificates
    log "Reloading nginx with real certificates..."
    docker-compose -f docker-compose.nginx-prod.yml exec nginx nginx -s reload
    
    log "SSL setup completed successfully!"
    log "Your Todo API is now available at: https://$DOMAIN"
else
    error "Failed to obtain SSL certificates"
fi

# Set up certificate renewal
log "Setting up automatic certificate renewal..."
cat > ssl/renew-certs.sh << EOF
#!/bin/bash
# Automatic certificate renewal script

docker run --rm \\
    -v "\$(pwd)/ssl/letsencrypt:/etc/letsencrypt" \\
    -v "\$(pwd)/ssl/webroot:/var/www/certbot" \\
    certbot/certbot renew --webroot --webroot-path=/var/www/certbot --quiet

# Reload nginx if certificates were renewed
if [ \$? -eq 0 ]; then
    docker-compose -f docker-compose.nginx-prod.yml exec nginx nginx -s reload
fi
EOF

chmod +x ssl/renew-certs.sh

log "Certificate renewal script created at ssl/renew-certs.sh"
log "Add this to your crontab to run twice daily:"
log "0 */12 * * * cd $(pwd) && ./ssl/renew-certs.sh"

log "SSL setup completed!"