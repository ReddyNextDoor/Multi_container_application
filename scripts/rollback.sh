#!/bin/bash

# Rollback script for Todo API
# This script can be used to rollback to a previous version

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
ANSIBLE_DIR="$PROJECT_ROOT/ansible"

# Default values
SERVER_HOST="${SERVER_HOST:-}"
SERVER_USER="${SERVER_USER:-ubuntu}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"
APP_NAME="${APP_NAME:-todo-api}"
ROLLBACK_TAG="${ROLLBACK_TAG:-}"
INVENTORY_FILE="${INVENTORY_FILE:-}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
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

log_debug() {
    echo -e "${BLUE}[DEBUG]${NC} $1"
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Rollback Todo API application to a previous version

OPTIONS:
    -h, --host          Server hostname or IP address
    -u, --user          SSH username (default: ubuntu)
    -d, --docker-user   Docker Hub username
    -t, --tag           Specific tag to rollback to (optional)
    -i, --inventory     Ansible inventory file (optional)
    --list-tags         List available tags from Docker Hub
    --help              Show this help message

ENVIRONMENT VARIABLES:
    SERVER_HOST         Server hostname or IP address
    SERVER_USER         SSH username
    DOCKER_USERNAME     Docker Hub username
    APP_NAME            Application name (default: todo-api)
    ROLLBACK_TAG        Specific tag to rollback to
    INVENTORY_FILE      Ansible inventory file path

EXAMPLES:
    $0 --host 192.168.1.100 --docker-user myuser
    $0 -h example.com -u deploy -d myuser -t v1.0.0
    $0 --list-tags --docker-user myuser

EOF
}

# Function to list available tags from Docker Hub
list_docker_tags() {
    local username="$1"
    local repo="$2"
    
    log_info "Fetching available tags for $username/$repo..."
    
    # Fetch tags from Docker Hub API
    local response
    if response=$(curl -s "https://hub.docker.com/v2/repositories/$username/$repo/tags/?page_size=25"); then
        echo "$response" | jq -r '.results[] | select(.name != "latest") | "\(.name) - Updated: \(.last_updated | split("T")[0])"' 2>/dev/null || {
            log_error "Failed to parse Docker Hub response. jq might not be installed."
            return 1
        }
    else
        log_error "Failed to fetch tags from Docker Hub"
        return 1
    fi
}

# Function to get the previous tag (excluding current)
get_previous_tag() {
    local username="$1"
    local repo="$2"
    local current_tag="$3"
    
    log_info "Finding previous tag (excluding $current_tag)..."
    
    local response
    if response=$(curl -s "https://hub.docker.com/v2/repositories/$username/$repo/tags/?page_size=10"); then
        echo "$response" | jq -r --arg current "$current_tag" '.results[] | select(.name != "latest" and .name != $current) | .name' 2>/dev/null | head -1
    else
        log_error "Failed to fetch tags from Docker Hub"
        return 1
    fi
}

# Function to get current running tag
get_current_tag() {
    local host="$1"
    local user="$2"
    
    log_info "Getting current running image tag..."
    
    ssh "$user@$host" "docker ps --format 'table {{.Image}}' | grep '$APP_NAME' | head -1" 2>/dev/null || echo "unknown"
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
        -d|--docker-user)
            DOCKER_USERNAME="$2"
            shift 2
            ;;
        -t|--tag)
            ROLLBACK_TAG="$2"
            shift 2
            ;;
        -i|--inventory)
            INVENTORY_FILE="$2"
            shift 2
            ;;
        --list-tags)
            LIST_TAGS=true
            shift
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

# Handle list tags option
if [[ "${LIST_TAGS:-false}" == "true" ]]; then
    if [[ -z "$DOCKER_USERNAME" ]]; then
        log_error "Docker username is required for listing tags. Use --docker-user or set DOCKER_USERNAME."
        exit 1
    fi
    
    list_docker_tags "$DOCKER_USERNAME" "$APP_NAME"
    exit 0
fi

# Validate required parameters
if [[ -z "$SERVER_HOST" ]]; then
    log_error "Server host is required. Use --host or set SERVER_HOST environment variable."
    exit 1
fi

if [[ -z "$DOCKER_USERNAME" ]]; then
    log_error "Docker username is required. Use --docker-user or set DOCKER_USERNAME environment variable."
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

# Check dependencies
for cmd in curl jq ssh ansible-playbook; do
    if ! command -v "$cmd" &> /dev/null; then
        log_error "$cmd command not found. Please install it."
        exit 1
    fi
done

# Get current running tag
current_tag=$(get_current_tag "$SERVER_HOST" "$SERVER_USER")
log_info "Current running image: $current_tag"

# Determine rollback tag
if [[ -z "$ROLLBACK_TAG" ]]; then
    log_info "No specific rollback tag provided, finding previous version..."
    
    # Extract current tag from full image name
    current_tag_only=$(echo "$current_tag" | cut -d':' -f2 2>/dev/null || echo "unknown")
    
    ROLLBACK_TAG=$(get_previous_tag "$DOCKER_USERNAME" "$APP_NAME" "$current_tag_only")
    
    if [[ -z "$ROLLBACK_TAG" ]]; then
        log_error "Could not determine previous version to rollback to."
        log_info "Available tags:"
        list_docker_tags "$DOCKER_USERNAME" "$APP_NAME"
        exit 1
    fi
    
    log_info "Found previous version: $ROLLBACK_TAG"
fi

# Construct full image name
ROLLBACK_IMAGE="$DOCKER_USERNAME/$APP_NAME:$ROLLBACK_TAG"

# Confirm rollback
echo
log_warn "=== ROLLBACK CONFIRMATION ==="
log_warn "Current: $current_tag"
log_warn "Rollback to: $ROLLBACK_IMAGE"
log_warn "Server: $SERVER_HOST"
echo

read -p "Are you sure you want to proceed with the rollback? (y/N): " -n 1 -r
echo
if [[ ! $REPLY =~ ^[Yy]$ ]]; then
    log_info "Rollback cancelled by user"
    exit 0
fi

# Perform rollback
log_info "Starting rollback to $ROLLBACK_IMAGE..."

# Check if target image exists
log_info "Verifying target image exists..."
if ! curl -f -s "https://hub.docker.com/v2/repositories/$DOCKER_USERNAME/$APP_NAME/tags/$ROLLBACK_TAG/" > /dev/null; then
    log_error "Target image tag '$ROLLBACK_TAG' not found in Docker Hub"
    exit 1
fi

# Execute rollback using Ansible
log_info "Executing rollback deployment..."
if ansible-playbook \
    -i "$INVENTORY_FILE" \
    "$ANSIBLE_DIR/site.yml" \
    -e "docker_image_tag=$ROLLBACK_IMAGE" \
    -e "app_env=production" \
    -v; then
    
    log_info "Rollback deployment completed!"
    
    # Perform health check
    log_info "Performing post-rollback health check..."
    sleep 15  # Wait for services to start
    
    max_attempts=6
    attempt=1
    
    while [[ $attempt -le $max_attempts ]]; do
        log_info "Health check attempt $attempt/$max_attempts..."
        
        if curl -f -s "http://$SERVER_HOST/health" > /dev/null; then
            log_info "Health check passed - Rollback successful!"
            
            # Display rollback summary
            echo
            log_info "=== ROLLBACK SUMMARY ==="
            log_info "Server: $SERVER_HOST"
            log_info "Previous Image: $current_tag"
            log_info "Rolled back to: $ROLLBACK_IMAGE"
            log_info "Health Check: ✅ PASSED"
            log_info "Application URL: http://$SERVER_HOST"
            echo
            
            exit 0
        else
            log_warn "Health check failed (attempt $attempt/$max_attempts)"
            if [[ $attempt -lt $max_attempts ]]; then
                sleep 10
            fi
        fi
        
        ((attempt++))
    done
    
    log_error "Health check failed after rollback - Application may not be working correctly"
    log_error "Please check the application logs on the server"
    exit 1
    
else
    log_error "Rollback deployment failed!"
    exit 1
fi