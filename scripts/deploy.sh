#!/bin/bash

# Deployment script for Todo API
# This script is used by the CI/CD pipeline to deploy the application

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Default values
SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-ubuntu}"
DOCKER_IMAGE_TAG="${DOCKER_IMAGE_TAG:-}"
APP_ENV="${APP_ENV:-production}"
INVENTORY_FILE="${INVENTORY_FILE:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${GREEN}[INFO]${NC} $1"
}

log_warn() {
    echo -e "${YELLOW}[WARN]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Deploy Todo API application using Ansible

OPTIONS:
    -h, --host          Server hostname or IP address
    -u, --user          SSH username (default: ubuntu)
    -t, --tag           Docker image tag to deploy
    -e, --env           Environment (default: production)
    -i, --inventory     Ansible inventory file (optional)
    --help              Show this help message

ENVIRONMENT VARIABLES:
    SERVER_HOST         Server hostname or IP address
    SERVER_USER         SSH username
    DOCKER_IMAGE_TAG    Docker image tag to deploy
    APP_ENV             Environment name
    INVENTORY_FILE      Ansible inventory file path

EXAMPLES:
    $0 --host 192.168.1.100 --tag myuser/todo-api:v1.0.0
    $0 -h example.com -u deploy -t myuser/todo-api:latest -e staging

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            SERVER_HOST="$2"
            shift 2
            ;;
        -u|--user)
            SERVER_USER="$2"
            shift 2
            ;;
        -t|--tag)
            DOCKER_IMAGE_TAG="$2"
            shift 2
            ;;
        -e|--env)
            APP_ENV="$2"
            shift 2
            ;;
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            log_error "Unknown option: $1"
            usage
            exit 1
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SERVER_HOST" ]]; then
    log_error "Server host is required. Use --host or set SERVER_HOST environment variable."
    exit 1
fi

if [[ -z "$DOCKER_IMAGE_TAG" ]]; then
    log_error "Docker image tag is required. Use --tag or set DOCKER_IMAGE_TAG environment variable."
    exit 1
fi

# Validate Ansible directory exists
if [[ ! -d "$ANSIBLE_DIR" ]]; then
    log_error "Ansible directory not found: $ANSIBLE_DIR"
    exit 1
fi

# Create temporary inventory if not provided
if [[ -z "$INVENTORY_FILE" ]]; then
    INVENTORY_FILE=$(mktemp)
    echo "$SERVER_HOST ansible_user=$SERVER_USER" > "$INVENTORY_FILE"
    log_info "Created temporary inventory: $INVENTORY_FILE"
    CLEANUP_INVENTORY=true
else
    CLEANUP_INVENTORY=false
fi

# Cleanup function
cleanup() {
    if [[ "$CLEANUP_INVENTORY" == "true" && -f "$INVENTORY_FILE" ]]; then
        rm -f "$INVENTORY_FILE"
        log_info "Cleaned up temporary inventory file"
    fi
}

# Set trap for cleanup
trap cleanup EXIT

# Validate inventory file
if [[ ! -f "$INVENTORY_FILE" ]]; then
    log_error "Inventory file not found: $INVENTORY_FILE"
    exit 1
fi

# Check if Ansible is installed
if ! command -v ansible-playbook &> /dev/null; then
    log_error "ansible-playbook command not found. Please install Ansible."
    exit 1
fi

# Check SSH connectivity
log_info "Testing SSH connectivity to $SERVER_HOST..."
if ! ssh -o ConnectTimeout=10 -o BatchMode=yes "$SERVER_USER@$SERVER_HOST" exit 2>/dev/null; then
    log_error "Cannot connect to $SERVER_HOST via SSH. Please check:"
    log_error "  - Server is accessible"
    log_error "  - SSH key is properly configured"
    log_error "  - Username is correct"
    exit 1
fi

log_info "SSH connectivity test passed"

# Validate Ansible playbook syntax
log_info "Validating Ansible playbook syntax..."
if ! ansible-playbook -i "$INVENTORY_FILE" "$ANSIBLE_DIR/site.yml" --syntax-check; then
    log_error "Ansible playbook syntax validation failed"
    exit 1
fi

log_info "Ansible playbook syntax validation passed"

# Run deployment
log_info "Starting deployment..."
log_info "  Server: $SERVER_HOST"
log_info "  User: $SERVER_USER"
log_info "  Docker Image: $DOCKER_IMAGE_TAG"
log_info "  Environment: $APP_ENV"

# Execute Ansible playbook
if ansible-playbook \
    -i "$INVENTORY_FILE" \
    "$ANSIBLE_DIR/site.yml" \
    -e "docker_image_tag=$DOCKER_IMAGE_TAG" \
    -e "app_env=$APP_ENV" \
    -v; then
    
    log_info "Deployment completed successfully!"
    
    # Perform health check
    log_info "Performing health check..."
    sleep 10  # Wait for services to start
    
    if curl -f -s "http://$SERVER_HOST/health" > /dev/null; then
        log_info "Health check passed - Application is running"
        
        # Display deployment summary
        echo
        log_info "=== DEPLOYMENT SUMMARY ==="
        log_info "Server: $SERVER_HOST"
        log_info "Image: $DOCKER_IMAGE_TAG"
        log_info "Environment: $APP_ENV"
        log_info "Health Check: ✅ PASSED"
        log_info "Application URL: http://$SERVER_HOST"
        echo
        
    else
        log_warn "Health check failed - Application may not be ready yet"
        log_warn "Please check the application logs on the server"
        exit 1
    fi
    
else
    log_error "Deployment failed!"
    exit 1
fi