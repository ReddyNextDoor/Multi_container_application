#!/bin/bash

# Advanced SSL Certificate Manager for Todo API
# Handles certificate creation, renewal, and management

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"
SSL_DIR="$PROJECT_DIR/ssl"
NGINX_COMPOSE_FILE="$PROJECT_DIR/docker-compose.nginx-prod.yml"

# Default values
DEFAULT_DOMAIN="todo-api.example.com"
DEFAULT_EMAIL="admin@example.com"
DEFAULT_STAGING="false"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
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

info() {
    echo -e "${BLUE}[$(date +'%Y-%m-%d %H:%M:%S')] INFO: $1${NC}"
}

# Help function
show_help() {
    cat << EOF
SSL Certificate Manager for Todo API

Usage: $0 [COMMAND] [OPTIONS]

Commands:
    init DOMAIN EMAIL [--staging]    Initialize SSL certificates for domain
    renew [DOMAIN]                   Renew certificates for domain (or all)
    status [DOMAIN]                  Show certificate status
    revoke DOMAIN                    Revoke certificate for domain
    cleanup                          Clean up expired certificates
    test-config                      Test nginx SSL configuration
    backup                           Backup certificates
    restore BACKUP_FILE              Restore certificates from backup

Options:
    --staging                        Use Let's Encrypt staging environment
    --force                          Force certificate renewal
    --dry-run                        Show what would be done without executing
    --help                           Show this help message

Examples:
    $0 init todo-api.example.com admin@example.com
    $0 init todo-api.example.com admin@example.com --staging
    $0 renew
    $0 renew todo-api.example.com --force
    $0 status
    $0 backup

Environment Variables:
    SSL_EMAIL                        Default email for Let's Encrypt
    SSL_STAGING                      Use staging environment (true/false)
    CERTBOT_IMAGE                    Certbot Docker image (default: certbot/certbot:latest)

EOF
}

# Parse command line arguments
COMMAND=""
DOMAIN=""
EMAIL=""
STAGING="false"
FORCE="false"
DRY_RUN="false"

while [[ $# -gt 0 ]]; do
    case $1 in
        init|renew|status|revoke|cleanup|test-config|backup|restore)
            COMMAND="$1"
            shift
            ;;
        --staging)
            STAGING="true"
            shift
            ;;
        --force)
            FORCE="true"
            shift
            ;;
        --dry-run)
            DRY_RUN="true"
            shift
            ;;
        --help|-h)
            show_help
            exit 0
            ;;
        *)
            if [[ -z "$DOMAIN" && "$COMMAND" != "cleanup" && "$COMMAND" != "test-config" && "$COMMAND" != "backup" ]]; then
                DOMAIN="$1"
            elif [[ -z "$EMAIL" && "$COMMAND" == "init" ]]; then
                EMAIL="$1"
            else
                warn "Unknown argument: $1"
            fi
            shift
            ;;
    esac
done

# Set defaults from environment or fallback
EMAIL="${EMAIL:-${SSL_EMAIL:-$DEFAULT_EMAIL}}"
STAGING="${SSL_STAGING:-$STAGING}"
CERTBOT_IMAGE="${CERTBOT_IMAGE:-certbot/certbot:latest}"

# Validate command
if [[ -z "$COMMAND" ]]; then
    error "No command specified. Use --help for usage information."
fi

# Create SSL directories
create_ssl_dirs() {
    log "Creating SSL directories..."
    mkdir -p "$SSL_DIR/letsencrypt"
    mkdir -p "$SSL_DIR/webroot"
    mkdir -p "$SSL_DIR/dhparam"
    mkdir -p "$SSL_DIR/backups"
}

# Generate DH parameters
generate_dhparam() {
    local dhparam_file="$SSL_DIR/dhparam/ssl-dhparams.pem"
    
    if [[ ! -f "$dhparam_file" ]]; then
        log "Generating DH parameters (this may take several minutes)..."
        if [[ "$DRY_RUN" == "false" ]]; then
            openssl dhparam -out "$dhparam_file" 2048
        else
            info "DRY RUN: Would generate DH parameters at $dhparam_file"
        fi
    else
        info "DH parameters already exist at $dhparam_file"
    fi
}

# Create dummy certificates
create_dummy_certs() {
    local domain="$1"
    local cert_dir="$SSL_DIR/letsencrypt/live/$domain"
    
    log "Creating dummy certificates for $domain..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        mkdir -p "$cert_dir"
        
        openssl req -x509 -nodes -newkey rsa:2048 \
            -days 1 \
            -keyout "$cert_dir/privkey.pem" \
            -out "$cert_dir/fullchain.pem" \
            -subj "/CN=$domain" 2>/dev/null
        
        cp "$cert_dir/fullchain.pem" "$cert_dir/chain.pem"
    else
        info "DRY RUN: Would create dummy certificates for $domain"
    fi
}

# Update nginx configuration
update_nginx_config() {
    local domain="$1"
    local template_file="$PROJECT_DIR/nginx/custom-domain.conf.template"
    local config_file="$PROJECT_DIR/nginx/nginx.conf"
    
    if [[ -f "$template_file" ]]; then
        log "Updating nginx configuration for domain: $domain"
        if [[ "$DRY_RUN" == "false" ]]; then
            sed "s/DOMAIN_NAME/$domain/g" "$template_file" > "$config_file"
        else
            info "DRY RUN: Would update nginx configuration for $domain"
        fi
    else
        warn "Custom domain template not found at $template_file"
    fi
}

# Start nginx
start_nginx() {
    log "Starting nginx..."
    if [[ "$DRY_RUN" == "false" ]]; then
        docker-compose -f "$NGINX_COMPOSE_FILE" up -d nginx
        sleep 10
    else
        info "DRY RUN: Would start nginx"
    fi
}

# Request certificate
request_certificate() {
    local domain="$1"
    local email="$2"
    local staging="$3"
    
    local staging_flag=""
    if [[ "$staging" == "true" ]]; then
        staging_flag="--staging"
        warn "Using Let's Encrypt staging environment"
    fi
    
    log "Requesting SSL certificate for $domain..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        docker run --rm \
            -v "$SSL_DIR/letsencrypt:/etc/letsencrypt" \
            -v "$SSL_DIR/webroot:/var/www/certbot" \
            "$CERTBOT_IMAGE" certonly \
            --webroot \
            --webroot-path=/var/www/certbot \
            --email "$email" \
            --agree-tos \
            --no-eff-email \
            $staging_flag \
            -d "$domain"
    else
        info "DRY RUN: Would request certificate for $domain with email $email"
    fi
}

# Renew certificates
renew_certificates() {
    local domain="$1"
    local force="$2"
    
    local force_flag=""
    if [[ "$force" == "true" ]]; then
        force_flag="--force-renewal"
    fi
    
    local domain_flag=""
    if [[ -n "$domain" ]]; then
        domain_flag="-d $domain"
    fi
    
    log "Renewing SSL certificates..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        docker run --rm \
            -v "$SSL_DIR/letsencrypt:/etc/letsencrypt" \
            -v "$SSL_DIR/webroot:/var/www/certbot" \
            "$CERTBOT_IMAGE" renew \
            --webroot \
            --webroot-path=/var/www/certbot \
            $force_flag \
            $domain_flag
        
        # Reload nginx if certificates were renewed
        if [[ $? -eq 0 ]]; then
            reload_nginx
        fi
    else
        info "DRY RUN: Would renew certificates"
    fi
}

# Reload nginx
reload_nginx() {
    log "Reloading nginx configuration..."
    if [[ "$DRY_RUN" == "false" ]]; then
        docker-compose -f "$NGINX_COMPOSE_FILE" exec nginx nginx -s reload
    else
        info "DRY RUN: Would reload nginx"
    fi
}

# Show certificate status
show_status() {
    local domain="$1"
    
    info "Certificate Status:"
    echo "==================="
    
    if [[ -n "$domain" ]]; then
        # Show status for specific domain
        local cert_file="$SSL_DIR/letsencrypt/live/$domain/fullchain.pem"
        if [[ -f "$cert_file" ]]; then
            echo "Domain: $domain"
            openssl x509 -in "$cert_file" -text -noout | grep -E "(Subject:|Not Before|Not After|Issuer:)"
        else
            warn "No certificate found for domain: $domain"
        fi
    else
        # Show status for all domains
        for cert_dir in "$SSL_DIR/letsencrypt/live"/*; do
            if [[ -d "$cert_dir" ]]; then
                local domain_name=$(basename "$cert_dir")
                local cert_file="$cert_dir/fullchain.pem"
                if [[ -f "$cert_file" ]]; then
                    echo ""
                    echo "Domain: $domain_name"
                    openssl x509 -in "$cert_file" -text -noout | grep -E "(Subject:|Not Before|Not After|Issuer:)"
                fi
            fi
        done
    fi
}

# Backup certificates
backup_certificates() {
    local backup_file="$SSL_DIR/backups/ssl-backup-$(date +%Y%m%d-%H%M%S).tar.gz"
    
    log "Creating certificate backup..."
    
    if [[ "$DRY_RUN" == "false" ]]; then
        tar -czf "$backup_file" -C "$SSL_DIR" letsencrypt dhparam
        log "Backup created: $backup_file"
    else
        info "DRY RUN: Would create backup at $backup_file"
    fi
}

# Main command execution
case "$COMMAND" in
    init)
        if [[ -z "$DOMAIN" || -z "$EMAIL" ]]; then
            error "Domain and email are required for init command"
        fi
        
        log "Initializing SSL certificates for $DOMAIN"
        create_ssl_dirs
        generate_dhparam
        create_dummy_certs "$DOMAIN"
        update_nginx_config "$DOMAIN"
        start_nginx
        request_certificate "$DOMAIN" "$EMAIL" "$STAGING"
        reload_nginx
        log "SSL initialization completed for $DOMAIN"
        ;;
        
    renew)
        renew_certificates "$DOMAIN" "$FORCE"
        ;;
        
    status)
        show_status "$DOMAIN"
        ;;
        
    backup)
        backup_certificates
        ;;
        
    test-config)
        log "Testing nginx SSL configuration..."
        if [[ "$DRY_RUN" == "false" ]]; then
            docker-compose -f "$NGINX_COMPOSE_FILE" exec nginx nginx -t
        else
            info "DRY RUN: Would test nginx configuration"
        fi
        ;;
        
    *)
        error "Unknown command: $COMMAND"
        ;;
esac