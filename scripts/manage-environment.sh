#!/bin/bash

# Environment Management Script for Todo API
# Usage: ./scripts/manage-environment.sh [environment] [action]

set -e

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_DIR="$(dirname "$SCRIPT_DIR")"

# Default values
ENVIRONMENT=${1:-development}
ACTION=${2:-up}

# Validate environment
case $ENVIRONMENT in
    development|staging|production)
        ;;
    *)
        echo "Error: Invalid environment '$ENVIRONMENT'"
        echo "Valid environments: development, staging, production"
        exit 1
        ;;
esac

# Set environment-specific variables
ENV_FILE="$PROJECT_DIR/.env.$ENVIRONMENT"
COMPOSE_FILE="$PROJECT_DIR/docker-compose.$ENVIRONMENT.yml"

# Use default compose file for development
if [ "$ENVIRONMENT" = "development" ]; then
    COMPOSE_FILE="$PROJECT_DIR/docker-compose.yml"
fi

# Check if environment file exists
if [ ! -f "$ENV_FILE" ]; then
    echo "Error: Environment file '$ENV_FILE' not found"
    exit 1
fi

# Check if compose file exists
if [ ! -f "$COMPOSE_FILE" ]; then
    echo "Error: Docker Compose file '$COMPOSE_FILE' not found"
    exit 1
fi

# Load environment variables
export $(grep -v '^#' "$ENV_FILE" | xargs)

echo "Managing Todo API - Environment: $ENVIRONMENT, Action: $ACTION"
echo "Using compose file: $COMPOSE_FILE"
echo "Using environment file: $ENV_FILE"

# Create data directories if they don't exist
if [ "$ENVIRONMENT" != "development" ]; then
    DATA_DIR="${DATA_PATH:-./data}"
    mkdir -p "$DATA_DIR/mongodb"
    mkdir -p "$DATA_DIR/mongodb-config"
    mkdir -p "$DATA_DIR/logs"
    mkdir -p "$DATA_DIR/backups"
    
    # Set proper permissions for production
    if [ "$ENVIRONMENT" = "production" ]; then
        sudo chown -R 1000:1000 "$DATA_DIR"
        chmod -R 755 "$DATA_DIR"
    fi
fi

# Execute Docker Compose command
case $ACTION in
    up)
        echo "Starting services..."
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" up -d
        ;;
    down)
        echo "Stopping services..."
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" down
        ;;
    restart)
        echo "Restarting services..."
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" restart
        ;;
    logs)
        echo "Showing logs..."
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" logs -f
        ;;
    status)
        echo "Service status..."
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps
        ;;
    pull)
        echo "Pulling latest images..."
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" pull
        ;;
    build)
        echo "Building images..."
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" build
        ;;
    health)
        echo "Checking service health..."
        # Check API health
        API_URL="http://localhost:${PORT:-3000}/health"
        if curl -f -s "$API_URL" > /dev/null; then
            echo "✓ API is healthy"
        else
            echo "✗ API is not responding"
        fi
        
        # Check MongoDB health
        if docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec mongodb mongosh --eval "db.adminCommand('ping')" > /dev/null 2>&1; then
            echo "✓ MongoDB is healthy"
        else
            echo "✗ MongoDB is not responding"
        fi
        ;;
    backup)
        echo "Creating backup..."
        BACKUP_DIR="${DATA_PATH:-./data}/backups/$(date +%Y%m%d_%H%M%S)"
        mkdir -p "$BACKUP_DIR"
        
        # Backup MongoDB
        docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" exec mongodb mongodump --out /data/backup
        docker cp "$(docker-compose --env-file "$ENV_FILE" -f "$COMPOSE_FILE" ps -q mongodb):/data/backup" "$BACKUP_DIR/mongodb"
        
        echo "Backup created at: $BACKUP_DIR"
        ;;
    *)
        echo "Error: Invalid action '$ACTION'"
        echo "Valid actions: up, down, restart, logs, status, pull, build, health, backup"
        exit 1
        ;;
esac

echo "Operation completed successfully!"