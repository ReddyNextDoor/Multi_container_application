#!/bin/bash

# Environment management script for Todo API
# This script provides helper functions for managing different deployment environments

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT="${ENVIRONMENT:-}"
ACTION="${ACTION:-}"
SERVER_HOST="${SERVER_HOST:-}"
DOCKER_USERNAME="${DOCKER_USERNAME:-}"

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
Usage: $0 [ACTION] [OPTIONS]

Manage Todo API deployment environments

ACTIONS:
    status              Show environment status
    logs               Show application logs
    restart            Restart application services
    update             Update application to latest version
    backup             Create database backup
    restore            Restore database from backup
    cleanup            Clean up old Docker images and containers
    shell              Open shell in application container

OPTIONS:
    -e, --environment   Environment name (staging/production)
    -h, --host          Server hostname or IP address
    -u, --docker-user   Docker Hub username
    --help              Show this help message

ENVIRONMENT VARIABLES:
    ENVIRONMENT         Environment name
    SERVER_HOST         Server hostname or IP address
    DOCKER_USERNAME     Docker Hub username

EXAMPLES:
    $0 status --environment production --host 192.168.1.100
    $0 logs -e staging -h staging.example.com
    $0 restart --environment production --host prod.example.com
    $0 backup -e production -h prod.example.com
    $0 cleanup --environment staging --host staging.example.com

EOF
}

# Function to check if server is accessible
check_server_access() {
    local host="$1"
    
    log_info "Checking server access to $host..."
    
    if ssh -o ConnectTimeout=10 -o BatchMode=yes "ubuntu@$host" exit 2>/dev/null; then
        log_info "✅ Server access confirmed"
        return 0
    else
        log_error "❌ Cannot access server via SSH"
        return 1
    fi
}

# Function to show environment status
show_status() {
    local host="$1"
    
    log_info "Getting environment status from $host..."
    
    # Check Docker services
    log_info "Docker services status:"
    ssh "ubuntu@$host" "docker-compose -f /opt/todo-api/docker-compose.yml ps" || {
        log_error "Failed to get Docker services status"
        return 1
    }
    
    # Check system resources
    log_info "System resources:"
    ssh "ubuntu@$host" "df -h / && echo && free -h && echo && uptime" || {
        log_warn "Could not retrieve system resources"
    }
    
    # Check application health
    log_info "Application health check:"
    if ssh "ubuntu@$host" "curl -f -s http://localhost:3000/health" > /dev/null; then
        log_info "✅ Application is healthy"
    else
        log_warn "⚠️  Application health check failed"
    fi
}

# Function to show application logs
show_logs() {
    local host="$1"
    local lines="${2:-50}"
    
    log_info "Showing last $lines lines of application logs from $host..."
    
    ssh "ubuntu@$host" "docker-compose -f /opt/todo-api/docker-compose.yml logs --tail=$lines -f" || {
        log_error "Failed to retrieve logs"
        return 1
    }
}

# Function to restart services
restart_services() {
    local host="$1"
    
    log_info "Restarting application services on $host..."
    
    ssh "ubuntu@$host" "cd /opt/todo-api && docker-compose restart" || {
        log_error "Failed to restart services"
        return 1
    }
    
    # Wait for services to start
    log_info "Waiting for services to start..."
    sleep 15
    
    # Verify health
    if ssh "ubuntu@$host" "curl -f -s http://localhost:3000/health" > /dev/null; then
        log_info "✅ Services restarted successfully"
    else
        log_warn "⚠️  Services may not be healthy after restart"
    fi
}

# Function to update application
update_application() {
    local host="$1"
    local docker_user="$2"
    
    log_info "Updating application on $host..."
    
    # Pull latest images
    ssh "ubuntu@$host" "cd /opt/todo-api && docker-compose pull" || {
        log_error "Failed to pull latest images"
        return 1
    }
    
    # Restart with new images
    ssh "ubuntu@$host" "cd /opt/todo-api && docker-compose up -d" || {
        log_error "Failed to restart with new images"
        return 1
    }
    
    # Wait and verify
    log_info "Waiting for application to start..."
    sleep 20
    
    if ssh "ubuntu@$host" "curl -f -s http://localhost:3000/health" > /dev/null; then
        log_info "✅ Application updated successfully"
    else
        log_error "❌ Application update failed - health check failed"
        return 1
    fi
}

# Function to create backup
create_backup() {
    local host="$1"
    local backup_name="${2:-backup_$(date +%Y%m%d_%H%M%S)}"
    
    log_info "Creating database backup '$backup_name' on $host..."
    
    ssh "ubuntu@$host" "/opt/todo-api/backup-db.sh $backup_name" || {
        log_error "Failed to create backup"
        return 1
    }
    
    log_info "✅ Backup created successfully"
}

# Function to restore backup
restore_backup() {
    local host="$1"
    local backup_name="$2"
    
    if [[ -z "$backup_name" ]]; then
        log_error "Backup name is required for restore operation"
        return 1
    fi
    
    log_info "Restoring database from backup '$backup_name' on $host..."
    
    # Check if backup exists
    if ! ssh "ubuntu@$host" "test -f /opt/todo-api/backups/${backup_name}.tar.gz"; then
        log_error "Backup file not found: ${backup_name}.tar.gz"
        return 1
    fi
    
    # Confirm restore
    log_warn "⚠️  WARNING: This will overwrite the current database!"
    read -p "Are you sure you want to restore from '$backup_name'? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    # Perform restore
    ssh "ubuntu@$host" "/opt/todo-api/restore-db.sh $backup_name" || {
        log_error "Failed to restore backup"
        return 1
    }
    
    log_info "✅ Database restored successfully"
}

# Function to cleanup old resources
cleanup_resources() {
    local host="$1"
    
    log_info "Cleaning up old Docker resources on $host..."
    
    # Remove unused images
    ssh "ubuntu@$host" "docker image prune -f" || {
        log_warn "Failed to clean up Docker images"
    }
    
    # Remove unused containers
    ssh "ubuntu@$host" "docker container prune -f" || {
        log_warn "Failed to clean up Docker containers"
    }
    
    # Remove unused volumes (be careful with this)
    read -p "Do you want to remove unused Docker volumes? This may delete data! (y/N): " -n 1 -r
    echo
    if [[ $REPLY =~ ^[Yy]$ ]]; then
        ssh "ubuntu@$host" "docker volume prune -f" || {
            log_warn "Failed to clean up Docker volumes"
        }
    fi
    
    log_info "✅ Cleanup completed"
}

# Function to open shell in container
open_shell() {
    local host="$1"
    local container="${2:-todo-api}"
    
    log_info "Opening shell in $container container on $host..."
    
    ssh -t "ubuntu@$host" "docker exec -it todo-api-${container}-1 /bin/bash" || {
        log_error "Failed to open shell in container"
        return 1
    }
}

# Parse command line arguments
if [[ $# -eq 0 ]]; then
    usage
    exit 1
fi

ACTION="$1"
shift

while [[ $# -gt 0 ]]; do
    case $1 in
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -h|--host)
            SERVER_HOST="$2"
            shift 2
            ;;
        -u|--docker-user)
            DOCKER_USERNAME="$2"
            shift 2
            ;;
        --help)
            usage
            exit 0
            ;;
        *)
            # Treat as backup name for restore action
            if [[ "$ACTION" == "restore" ]]; then
                BACKUP_NAME="$1"
            else
                log_error "Unknown option: $1"
                usage
                exit 1
            fi
            shift
            ;;
    esac
done

# Validate required parameters
if [[ -z "$SERVER_HOST" ]]; then
    log_error "Server host is required. Use --host or set SERVER_HOST environment variable."
    exit 1
fi

# Check server access
if ! check_server_access "$SERVER_HOST"; then
    exit 1
fi

# Execute action
case "$ACTION" in
    status)
        show_status "$SERVER_HOST"
        ;;
    logs)
        show_logs "$SERVER_HOST"
        ;;
    restart)
        restart_services "$SERVER_HOST"
        ;;
    update)
        if [[ -z "$DOCKER_USERNAME" ]]; then
            log_error "Docker username is required for update. Use --docker-user or set DOCKER_USERNAME."
            exit 1
        fi
        update_application "$SERVER_HOST" "$DOCKER_USERNAME"
        ;;
    backup)
        create_backup "$SERVER_HOST"
        ;;
    restore)
        if [[ -z "${BACKUP_NAME:-}" ]]; then
            log_error "Backup name is required for restore action"
            exit 1
        fi
        restore_backup "$SERVER_HOST" "$BACKUP_NAME"
        ;;
    cleanup)
        cleanup_resources "$SERVER_HOST"
        ;;
    shell)
        open_shell "$SERVER_HOST"
        ;;
    *)
        log_error "Unknown action: $ACTION"
        usage
        exit 1
        ;;
esac

log_info "Operation completed successfully!"