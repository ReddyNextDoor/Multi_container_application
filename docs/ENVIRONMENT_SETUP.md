# Environment Setup Guide

This guide explains how to set up and manage different environments for the Todo API application.

## Available Environments

- **Development**: Local development with hot reload and debugging features
- **Staging**: Pre-production environment for testing
- **Production**: Production-ready configuration with optimizations and security

## Environment Files

Each environment has its own configuration file:

- `.env.development` - Development environment variables
- `.env.staging` - Staging environment variables  
- `.env.production` - Production environment variables

## Docker Compose Files

- `docker-compose.yml` - Development configuration (default)
- `docker-compose.staging.yml` - Staging configuration
- `docker-compose.prod.yml` - Production configuration

## Quick Start

### Development Environment

```bash
# Start development environment
./scripts/manage-environment.sh development up

# View logs
./scripts/manage-environment.sh development logs

# Stop services
./scripts/manage-environment.sh development down
```

### Staging Environment

```bash
# Start staging environment
./scripts/manage-environment.sh staging up

# Check health
./scripts/manage-environment.sh staging health

# Create backup
./scripts/manage-environment.sh staging backup
```

### Production Environment

```bash
# Start production environment
./scripts/manage-environment.sh production up

# Monitor services
./scripts/manage-environment.sh production status

# Restart services
./scripts/manage-environment.sh production restart
```

## Environment Configuration

### Development Features

- Hot reload with nodemon
- Debug logging enabled
- CORS allowed from any origin
- Relaxed resource limits
- Source code mounted as volumes

### Staging Features

- Production-like configuration
- Debug logging for troubleshooting
- Moderate resource limits
- Separate database namespace
- Debug routes enabled

### Production Features

- Optimized resource limits
- Info-level logging only
- Security hardening
- Automatic restarts
- Persistent data volumes
- Health checks and monitoring

## Resource Limits

### Development
- No resource limits (uses host resources)

### Staging
- API: 256MB RAM, 0.3 CPU cores
- MongoDB: 512MB RAM, 0.3 CPU cores

### Production
- API: 512MB RAM, 0.5 CPU cores
- MongoDB: 1GB RAM, 0.5 CPU cores

## Data Persistence

### Development
- Uses Docker named volumes
- Data stored in Docker's default location

### Staging/Production
- Uses bind mounts to host filesystem
- Configurable data path via `DATA_PATH` environment variable
- Default paths:
  - Staging: `./staging-data`
  - Production: `/opt/todo-api/data`

## Logging Configuration

Logging is configured per environment in `config/logging.json`:

- **Development**: Pretty-formatted console output with debug level
- **Staging**: JSON-formatted logs with debug level
- **Production**: JSON-formatted logs with info level and error handling

## Monitoring and Backup

Configuration files are provided for:

- `config/monitoring.yml` - Health checks, metrics, and alerting
- `config/backup.yml` - Backup schedules and retention policies

## Security Considerations

### Development
- MongoDB port exposed for debugging
- Relaxed security settings
- Debug routes enabled

### Staging
- MongoDB port not exposed to host
- Production-like security
- Debug routes available for testing

### Production
- MongoDB port not exposed to host
- Runs as non-root user (UID 1000)
- Strict resource limits
- No debug features enabled

## Troubleshooting

### Check Service Status
```bash
./scripts/manage-environment.sh [environment] status
```

### View Service Logs
```bash
./scripts/manage-environment.sh [environment] logs
```

### Health Check
```bash
./scripts/manage-environment.sh [environment] health
```

### Restart Services
```bash
./scripts/manage-environment.sh [environment] restart
```

## Environment Variables

Key environment variables that can be customized:

- `PORT` - API server port (default: 3000)
- `MONGODB_URI` - MongoDB connection string
- `DB_MAX_POOL_SIZE` - Database connection pool size
- `DATA_PATH` - Path for persistent data storage
- `DOCKER_IMAGE_TAG` - Docker image tag to use
- `LOG_LEVEL` - Logging level (debug, info, warn, error)

## Migration Between Environments

When promoting from staging to production:

1. Test thoroughly in staging environment
2. Create backup of production data
3. Update production environment variables if needed
4. Deploy using the production configuration
5. Verify health checks pass
6. Monitor application performance

## Best Practices

1. Always test changes in development first
2. Use staging environment for integration testing
3. Create backups before production deployments
4. Monitor resource usage and adjust limits as needed
5. Keep environment configurations in version control
6. Use secrets management for sensitive data in production