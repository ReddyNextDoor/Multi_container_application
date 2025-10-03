#!/bin/bash

# Complete Nginx SSL Deployment Script for Todo API
# This script handles the complete deployment with SSL certificates

set -e

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
DOMAIN=""
EMAIL=""
STAGING="false"
SKIP_SSL="false"
ENVIRONMENT="production"

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
Complete Nginx SSL Deployment Script for Todo API

Usage: $0 [OPTIONS]

Options:
    -d, --domain DOMAIN         Domain name for SSL certificate
    -e, --email EMAIL           Email for Let's Encrypt registration
    -s, --staging               Use Let's Encrypt staging environment
    --skip-ssl                  Skip SSL setup (HTTP only)
    --dev                       Deploy development environment
    --prod                      Deploy production environment (default)
    -h, --help                  Show this help message

Examples:
    # Production deployment with SSL
    $0 --domain todo-api.example.com --email admin@example.com

    # Staging deployment for testing
    $0 --domain todo-api.staging.com --email admin@example.com --staging

    # Development deployment (no SSL)
    $0 --dev

    # Production deployment without SSL
    $0 --prod --skip-ssl

Environment Variables:
    DOMAIN_NAME                 Default domain name
    SSL_EMAIL                   Default email for SSL
    DOCKER_IMAGE                Docker image for production

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -d|--domain)
            DOMAIN="$2"
            shift 2
            ;;
        -e|--email)
            EMAIL="$2"
            shift 2
            ;;
        -s|--staging)
            STAGING="true"
            shift
            ;;
        --skip-ssl)
            SKIP_SSL="true"
            shift
            ;;
        --dev)
            ENVIRONMENT="development"
            shift
            ;;
        --prod)
            ENVIRONMENT="production"
            shift
            ;;
        -h|--help)
            show_help
            exit 0
            ;;
        *)
            error "Unknown option: $1"
            ;;
    esac
done

# Set defaults from environment
DOMAIN="${DOMAIN:-${DOMAIN_NAME:-}}"
EMAIL="${EMAIL:-${SSL_EMAIL:-}}"

# Validate requirements for production with SSL
if [[ "$ENVIRONMENT" == "production" && "$SKIP_SSL" == "false" ]]; then
    if [[ -z "$DOMAIN" ]]; then
        error "Domain is required for production deployment with SSL"
    fi
    if [[ -z "$EMAIL" ]]; then
        error "Email is required for SSL certificate registration"
    fi
fi

log "Starting Todo API deployment with Nginx reverse proxy"
log "Environment: $ENVIRONMENT"
log "Domain: ${DOMAIN:-'localhost'}"
log "SSL: $([ "$SKIP_SSL" == "true" ] && echo "disabled" || echo "enabled")"

# Step 1: Prepare environment
log "Step 1: Preparing environment..."

# Create necessary directories
mkdir -p ssl/letsencrypt
mkdir -p ssl/webroot
mkdir -p ssl/dhparam
mkdir -p ssl/backups
mkdir -p nginx/static

# Step 2: Build application if needed
log "Step 2: Building application..."

if [[ "$ENVIRONMENT" == "production" ]]; then
    # Build production image
    docker build -t todo-api:latest .
    log "Production image built"
else
    log "Using development build"
fi

# Step 3: Deploy based on environment
log "Step 3: Deploying services..."

case "$ENVIRONMENT" in
    "development")
        log "Deploying development environment..."
        docker-compose -f docker-compose.yml -f docker-compose.override.yml up -d
        
        # Wait for services to be ready
        sleep 10
        
        # Test health
        if curl -f http://localhost/health >/dev/null 2>&1; then
            log "Development deployment successful!"
            log "API available at: http://localhost"
            log "Direct API access: http://localhost:3001"
        else
            error "Development deployment failed - health check failed"
        fi
        ;;
        
    "production")
        if [[ "$SKIP_SSL" == "true" ]]; then
            log "Deploying production environment without SSL..."
            
            # Use development nginx config for HTTP-only production
            cp nginx/nginx-dev.conf nginx/nginx-prod-http.conf
            
            # Create temporary compose file for HTTP-only production
            cat > docker-compose.prod-http.yml << EOF
version: '3.8'
services:
  nginx:
    image: nginx:1.25-alpine
    container_name: todo-nginx-prod
    restart: unless-stopped
    ports:
      - "80:80"
    volumes:
      - ./nginx/nginx-prod-http.conf:/etc/nginx/nginx.conf:ro
      - ./nginx/static:/var/www/static:ro
      - nginx_logs:/var/log/nginx
    networks:
      - todo-network
    depends_on:
      - todo-api

volumes:
  nginx_logs:
    driver: local

networks:
  todo-network:
    external: true
EOF
            
            # Start base services first
            docker-compose -f docker-compose.yml up -d mongodb todo-api
            
            # Start nginx
            docker-compose -f docker-compose.prod-http.yml up -d
            
        else
            log "Deploying production environment with SSL..."
            
            # Step 3a: Initialize SSL certificates
            log "Step 3a: Setting up SSL certificates..."
            "$SCRIPT_DIR/ssl-manager.sh" init "$DOMAIN" "$EMAIL" $([ "$STAGING" == "true" ] && echo "--staging" || echo "")
            
            # Step 3b: Deploy production services
            log "Step 3b: Starting production services..."
            docker-compose -f docker-compose.nginx-prod.yml up -d
        fi
        
        # Wait for services to be ready
        sleep 15
        
        # Test health
        local health_url="http://localhost/health"
        if [[ "$SKIP_SSL" == "false" ]]; then
            health_url="https://$DOMAIN/health"
        fi
        
        if curl -f -k "$health_url" >/dev/null 2>&1; then
            log "Production deployment successful!"
            if [[ "$SKIP_SSL" == "false" ]]; then
                log "API available at: https://$DOMAIN"
            else
                log "API available at: http://localhost"
            fi
        else
            error "Production deployment failed - health check failed"
        fi
        ;;
esac

# Step 4: Setup monitoring and maintenance
log "Step 4: Setting up monitoring and maintenance..."

if [[ "$ENVIRONMENT" == "production" && "$SKIP_SSL" == "false" ]]; then
    # Setup SSL certificate renewal
    log "Setting up SSL certificate auto-renewal..."
    
    # Create cron job for certificate renewal
    (crontab -l 2>/dev/null; echo "0 */12 * * * cd $PROJECT_DIR && $SCRIPT_DIR/ssl-manager.sh renew >/dev/null 2>&1") | crontab -
    
    # Setup SSL health monitoring
    (crontab -l 2>/dev/null; echo "0 9 * * * cd $PROJECT_DIR && $SCRIPT_DIR/ssl-health-check.sh >/dev/null 2>&1") | crontab -
    
    log "SSL monitoring and renewal configured"
fi

# Step 5: Display deployment summary
log "Step 5: Deployment summary"

echo ""
echo "=========================================="
echo "Todo API Deployment Complete"
echo "=========================================="
echo ""
echo "Environment: $ENVIRONMENT"
echo "Domain: ${DOMAIN:-'localhost'}"
echo "SSL: $([ "$SKIP_SSL" == "true" ] && echo "disabled" || echo "enabled")"
echo ""

if [[ "$ENVIRONMENT" == "development" ]]; then
    echo "Access URLs:"
    echo "  - Main API (via Nginx): http://localhost"
    echo "  - Direct API access: http://localhost:3001"
    echo "  - Health check: http://localhost/health"
    echo ""
    echo "Development features:"
    echo "  - Hot reload enabled"
    echo "  - Development dependencies available"
    echo "  - Direct database access on port 27017"
elif [[ "$SKIP_SSL" == "true" ]]; then
    echo "Access URLs:"
    echo "  - API: http://localhost"
    echo "  - Health check: http://localhost/health"
    echo ""
    echo "Production features:"
    echo "  - Optimized Docker images"
    echo "  - Nginx reverse proxy"
    echo "  - Rate limiting enabled"
else
    echo "Access URLs:"
    echo "  - API: https://$DOMAIN"
    echo "  - Health check: https://$DOMAIN/health"
    echo ""
    echo "Production features:"
    echo "  - SSL/TLS encryption"
    echo "  - Automatic certificate renewal"
    echo "  - Security headers enabled"
    echo "  - Rate limiting enabled"
    echo "  - HSTS enabled"
fi

echo ""
echo "Management commands:"
echo "  - View logs: docker-compose logs -f"
echo "  - Stop services: docker-compose down"
echo "  - Restart services: docker-compose restart"

if [[ "$ENVIRONMENT" == "production" && "$SKIP_SSL" == "false" ]]; then
    echo "  - SSL status: $SCRIPT_DIR/ssl-manager.sh status"
    echo "  - SSL health check: $SCRIPT_DIR/ssl-health-check.sh"
    echo "  - Renew certificates: $SCRIPT_DIR/ssl-manager.sh renew"
fi

echo ""
log "Deployment completed successfully!"