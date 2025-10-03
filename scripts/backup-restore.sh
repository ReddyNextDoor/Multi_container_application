#!/bin/bash

# Database backup and restore script for Todo API
# This script provides comprehensive backup and restore functionality

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"

# Default values
ACTION="${ACTION:-}"
SERVER_HOST="${SERVER_HOST:-}"
BACKUP_NAME="${BACKUP_NAME:-}"
BACKUP_DIR="${BACKUP_DIR:-/opt/todo-api/backups}"
CONTAINER_NAME="${CONTAINER_NAME:-todo-api-mongodb-1}"
DB_NAME="${DB_NAME:-todoapp}"
RETENTION_DAYS="${RETENTION_DAYS:-7}"

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

Backup and restore MongoDB database for Todo API

ACTIONS:
    backup              Create a new database backup
    restore             Restore database from backup
    list                List available backups
    cleanup             Clean up old backups
    schedule            Set up automated backup schedule

OPTIONS:
    -h, --host          Server hostname or IP address
    -n, --name          Backup name (for backup/restore)
    -d, --dir           Backup directory (default: /opt/todo-api/backups)
    -c, --container     MongoDB container name (default: todo-api-mongodb-1)
    --db-name           Database name (default: todoapp)
    --retention         Retention period in days (default: 7)
    --help              Show this help message

ENVIRONMENT VARIABLES:
    SERVER_HOST         Server hostname or IP address
    BACKUP_NAME         Backup name
    BACKUP_DIR          Backup directory path
    CONTAINER_NAME      MongoDB container name
    DB_NAME             Database name
    RETENTION_DAYS      Backup retention period

EXAMPLES:
    $0 backup --host 192.168.1.100
    $0 backup -h prod.example.com -n manual_backup_20241003
    $0 restore -h prod.example.com -n backup_20241003_120000
    $0 list --host prod.example.com
    $0 cleanup --host prod.example.com --retention 14

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

# Function to check if MongoDB container is running
check_mongodb_container() {
    local host="$1"
    local container="$2"
    
    log_info "Checking MongoDB container status..."
    
    if ssh "ubuntu@$host" "docker ps --format '{{.Names}}' | grep -q '^${container}$'"; then
        log_info "✅ MongoDB container is running"
        return 0
    else
        log_error "❌ MongoDB container '$container' is not running"
        return 1
    fi
}

# Function to create backup
create_backup() {
    local host="$1"
    local backup_name="$2"
    local backup_dir="$3"
    local container="$4"
    local db_name="$5"
    
    log_info "Creating database backup '$backup_name'..."
    
    # Create backup directory on remote server
    ssh "ubuntu@$host" "mkdir -p $backup_dir"
    
    # Create MongoDB dump
    log_info "Creating MongoDB dump..."
    ssh "ubuntu@$host" "docker exec $container mongodump --db $db_name --out /tmp/$backup_name" || {
        log_error "Failed to create MongoDB dump"
        return 1
    }
    
    # Copy backup from container to host
    log_info "Copying backup from container to host..."
    ssh "ubuntu@$host" "docker cp $container:/tmp/$backup_name $backup_dir/" || {
        log_error "Failed to copy backup from container"
        return 1
    }
    
    # Compress backup
    log_info "Compressing backup..."
    ssh "ubuntu@$host" "cd $backup_dir && tar -czf ${backup_name}.tar.gz $backup_name && rm -rf $backup_name" || {
        log_error "Failed to compress backup"
        return 1
    }
    
    # Clean up container
    ssh "ubuntu@$host" "docker exec $container rm -rf /tmp/$backup_name" || {
        log_warn "Failed to clean up temporary files in container"
    }
    
    # Get backup size
    local backup_size
    backup_size=$(ssh "ubuntu@$host" "ls -lh $backup_dir/${backup_name}.tar.gz | awk '{print \$5}'")
    
    log_info "✅ Backup created successfully!"
    log_info "   File: $backup_dir/${backup_name}.tar.gz"
    log_info "   Size: $backup_size"
    
    return 0
}

# Function to restore backup
restore_backup() {
    local host="$1"
    local backup_name="$2"
    local backup_dir="$3"
    local container="$4"
    local db_name="$5"
    
    local backup_file="$backup_dir/${backup_name}.tar.gz"
    
    log_info "Restoring database from backup '$backup_name'..."
    
    # Check if backup file exists
    if ! ssh "ubuntu@$host" "test -f $backup_file"; then
        log_error "Backup file not found: $backup_file"
        return 1
    fi
    
    # Confirm restore
    log_warn "⚠️  WARNING: This will overwrite the current database!"
    log_warn "   Database: $db_name"
    log_warn "   Backup: $backup_name"
    echo
    read -p "Are you sure you want to proceed? Type 'yes' to confirm: " -r
    if [[ "$REPLY" != "yes" ]]; then
        log_info "Restore cancelled"
        return 0
    fi
    
    # Extract backup
    log_info "Extracting backup..."
    ssh "ubuntu@$host" "cd $backup_dir && tar -xzf ${backup_name}.tar.gz" || {
        log_error "Failed to extract backup"
        return 1
    }
    
    # Copy backup to container
    log_info "Copying backup to container..."
    ssh "ubuntu@$host" "docker cp $backup_dir/$backup_name $container:/tmp/" || {
        log_error "Failed to copy backup to container"
        return 1
    }
    
    # Drop existing database
    log_info "Dropping existing database..."
    ssh "ubuntu@$host" "docker exec $container mongo $db_name --eval 'db.dropDatabase()'" || {
        log_warn "Failed to drop existing database (it may not exist)"
    }
    
    # Restore database
    log_info "Restoring database..."
    ssh "ubuntu@$host" "docker exec $container mongorestore --db $db_name /tmp/$backup_name/$db_name" || {
        log_error "Failed to restore database"
        return 1
    }
    
    # Clean up
    ssh "ubuntu@$host" "rm -rf $backup_dir/$backup_name" || {
        log_warn "Failed to clean up extracted backup"
    }
    
    ssh "ubuntu@$host" "docker exec $container rm -rf /tmp/$backup_name" || {
        log_warn "Failed to clean up container temporary files"
    }
    
    log_info "✅ Database restored successfully!"
    
    return 0
}

# Function to list backups
list_backups() {
    local host="$1"
    local backup_dir="$2"
    
    log_info "Listing available backups on $host..."
    
    if ! ssh "ubuntu@$host" "test -d $backup_dir"; then
        log_warn "Backup directory does not exist: $backup_dir"
        return 0
    fi
    
    local backups
    backups=$(ssh "ubuntu@$host" "ls -la $backup_dir/*.tar.gz 2>/dev/null" || echo "")
    
    if [[ -z "$backups" ]]; then
        log_info "No backups found in $backup_dir"
        return 0
    fi
    
    echo
    log_info "Available backups:"
    echo "----------------------------------------"
    printf "%-30s %-10s %-20s\n" "BACKUP NAME" "SIZE" "DATE"
    echo "----------------------------------------"
    
    ssh "ubuntu@$host" "ls -la $backup_dir/*.tar.gz" | while read -r line; do
        if [[ "$line" =~ \.tar\.gz$ ]]; then
            local size=$(echo "$line" | awk '{print $5}')
            local date=$(echo "$line" | awk '{print $6, $7, $8}')
            local filename=$(basename "$(echo "$line" | awk '{print $9}')" .tar.gz)
            printf "%-30s %-10s %-20s\n" "$filename" "$size" "$date"
        fi
    done
    
    echo "----------------------------------------"
    
    return 0
}

# Function to cleanup old backups
cleanup_backups() {
    local host="$1"
    local backup_dir="$2"
    local retention_days="$3"
    
    log_info "Cleaning up backups older than $retention_days days..."
    
    if ! ssh "ubuntu@$host" "test -d $backup_dir"; then
        log_warn "Backup directory does not exist: $backup_dir"
        return 0
    fi
    
    # Find and list old backups
    local old_backups
    old_backups=$(ssh "ubuntu@$host" "find $backup_dir -name '*.tar.gz' -type f -mtime +$retention_days" || echo "")
    
    if [[ -z "$old_backups" ]]; then
        log_info "No old backups found to clean up"
        return 0
    fi
    
    log_info "Found old backups to delete:"
    echo "$old_backups"
    
    # Confirm cleanup
    echo
    read -p "Do you want to delete these backups? (y/N): " -n 1 -r
    echo
    if [[ ! $REPLY =~ ^[Yy]$ ]]; then
        log_info "Cleanup cancelled"
        return 0
    fi
    
    # Delete old backups
    local deleted_count
    deleted_count=$(ssh "ubuntu@$host" "find $backup_dir -name '*.tar.gz' -type f -mtime +$retention_days -delete -print | wc -l")
    
    log_info "✅ Deleted $deleted_count old backup(s)"
    
    return 0
}

# Function to set up automated backup schedule
setup_backup_schedule() {
    local host="$1"
    local backup_dir="$2"
    
    log_info "Setting up automated backup schedule on $host..."
    
    # Create backup script on remote server
    local remote_script="/opt/todo-api/backup-db.sh"
    
    ssh "ubuntu@$host" "cat > $remote_script << 'EOF'
#!/bin/bash
# Auto-generated backup script
BACKUP_DIR=\"$backup_dir\"
CONTAINER_NAME=\"$CONTAINER_NAME\"
DB_NAME=\"$DB_NAME\"
TIMESTAMP=\$(date +\"%Y%m%d_%H%M%S\")
BACKUP_NAME=\"backup_\$TIMESTAMP\"

mkdir -p \"\$BACKUP_DIR\"
docker exec \"\$CONTAINER_NAME\" mongodump --db \"\$DB_NAME\" --out \"/tmp/\$BACKUP_NAME\"
docker cp \"\$CONTAINER_NAME:/tmp/\$BACKUP_NAME\" \"\$BACKUP_DIR/\"
cd \"\$BACKUP_DIR\" && tar -czf \"\${BACKUP_NAME}.tar.gz\" \"\$BACKUP_NAME\" && rm -rf \"\$BACKUP_NAME\"
docker exec \"\$CONTAINER_NAME\" rm -rf \"/tmp/\$BACKUP_NAME\"

# Clean up old backups
find \"\$BACKUP_DIR\" -name \"backup_*.tar.gz\" -type f -mtime +$RETENTION_DAYS -delete

echo \"Backup completed: \$BACKUP_DIR/\${BACKUP_NAME}.tar.gz\"
EOF"
    
    # Make script executable
    ssh "ubuntu@$host" "chmod +x $remote_script"
    
    # Add cron job for daily backups at 2 AM
    ssh "ubuntu@$host" "(crontab -l 2>/dev/null | grep -v '$remote_script'; echo '0 2 * * * $remote_script >> /var/log/todo-api-backup.log 2>&1') | crontab -"
    
    log_info "✅ Automated backup schedule configured!"
    log_info "   Schedule: Daily at 2:00 AM"
    log_info "   Script: $remote_script"
    log_info "   Log: /var/log/todo-api-backup.log"
    log_info "   Retention: $RETENTION_DAYS days"
    
    return 0
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
        -h|--host)
            SERVER_HOST="$2"
            shift 2
            ;;
        -n|--name)
            BACKUP_NAME="$2"
            shift 2
            ;;
        -d|--dir)
            BACKUP_DIR="$2"
            shift 2
            ;;
        -c|--container)
            CONTAINER_NAME="$2"
            shift 2
            ;;
        --db-name)
            DB_NAME="$2"
            shift 2
            ;;
        --retention)
            RETENTION_DAYS="$2"
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

# Check server access
if ! check_server_access "$SERVER_HOST"; then
    exit 1
fi

# Check MongoDB container (except for list and cleanup actions)
if [[ "$ACTION" != "list" && "$ACTION" != "cleanup" ]]; then
    if ! check_mongodb_container "$SERVER_HOST" "$CONTAINER_NAME"; then
        exit 1
    fi
fi

# Execute action
case "$ACTION" in
    backup)
        if [[ -z "$BACKUP_NAME" ]]; then
            BACKUP_NAME="backup_$(date +%Y%m%d_%H%M%S)"
        fi
        create_backup "$SERVER_HOST" "$BACKUP_NAME" "$BACKUP_DIR" "$CONTAINER_NAME" "$DB_NAME"
        ;;
    restore)
        if [[ -z "$BACKUP_NAME" ]]; then
            log_error "Backup name is required for restore action. Use --name option."
            exit 1
        fi
        restore_backup "$SERVER_HOST" "$BACKUP_NAME" "$BACKUP_DIR" "$CONTAINER_NAME" "$DB_NAME"
        ;;
    list)
        list_backups "$SERVER_HOST" "$BACKUP_DIR"
        ;;
    cleanup)
        cleanup_backups "$SERVER_HOST" "$BACKUP_DIR" "$RETENTION_DAYS"
        ;;
    schedule)
        setup_backup_schedule "$SERVER_HOST" "$BACKUP_DIR"
        ;;
    *)
        log_error "Unknown action: $ACTION"
        usage
        exit 1
        ;;
esac

log_info "Operation completed successfully!"