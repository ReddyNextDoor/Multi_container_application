# Docker Compose Testing Guide

This guide provides comprehensive instructions for testing the Docker Compose setup for the Todo API application.

## Prerequisites

1. **Docker Desktop** or **Docker Engine** must be installed and running
2. **Docker Compose** must be available (included with Docker Desktop)
3. Ports 3000 and 27017 must be available on your system

## Testing Scripts

### 1. Configuration Validation (`validate-docker-setup.sh`)

This script validates the Docker Compose configuration without requiring Docker to be running.

```bash
./validate-docker-setup.sh
```

**What it tests:**
- Docker Compose file syntax validation
- Required files existence
- Service definitions (mongodb, todo-api)
- Network configuration
- Volume configuration
- Environment variables
- Port mappings
- Service dependencies
- Health check configuration

### 2. Full Integration Testing (`test-docker-setup.sh`)

This script performs comprehensive testing of the running Docker Compose setup.

```bash
# Start Docker Desktop first, then run:
./test-docker-setup.sh
```

**What it tests:**
- Container startup and communication
- API functionality (CRUD operations)
- Data persistence across container restarts
- Volume persistence across complete shutdowns
- MongoDB connectivity and health checks

## Manual Testing Steps

### Step 1: Start Docker Desktop

Ensure Docker Desktop is running on your system.

### Step 2: Validate Configuration

```bash
# Run configuration validation
./validate-docker-setup.sh
```

### Step 3: Start Services

```bash
# Start all services in detached mode
docker-compose up -d

# Check service status
docker-compose ps

# View logs
docker-compose logs -f
```

### Step 4: Test API Endpoints

#### Health Check
```bash
curl http://localhost:3000/health
```

Expected response:
```json
{
  "success": true,
  "message": "API is running",
  "timestamp": "2024-01-01T00:00:00.000Z",
  "database": {
    "status": "connected",
    "message": "Database connection is healthy"
  }
}
```

#### Create Todo
```bash
curl -X POST http://localhost:3000/todos \
  -H "Content-Type: application/json" \
  -d '{"title":"Test Todo","description":"Testing Docker setup","completed":false}'
```

#### Get All Todos
```bash
curl http://localhost:3000/todos
```

#### Get Specific Todo
```bash
# Replace {id} with actual todo ID from create response
curl http://localhost:3000/todos/{id}
```

#### Update Todo
```bash
# Replace {id} with actual todo ID
curl -X PUT http://localhost:3000/todos/{id} \
  -H "Content-Type: application/json" \
  -d '{"title":"Updated Todo","completed":true}'
```

#### Delete Todo
```bash
# Replace {id} with actual todo ID
curl -X DELETE http://localhost:3000/todos/{id}
```

### Step 5: Test Data Persistence

#### Test Container Restart
```bash
# Restart containers
docker-compose restart

# Wait for services to be ready
sleep 30

# Verify data still exists
curl http://localhost:3000/todos
```

#### Test Complete Shutdown and Restart
```bash
# Stop all containers
docker-compose down

# Start containers again
docker-compose up -d

# Wait for services to be ready
sleep 30

# Verify data still exists
curl http://localhost:3000/todos
```

### Step 6: Test Container Communication

#### Check MongoDB Connection
```bash
# Check health endpoint for database status
curl http://localhost:3000/health | jq '.database'
```

#### Inspect Network
```bash
# List Docker networks
docker network ls

# Inspect the todo network
docker network inspect multi_container_application_todo-network
```

#### Test Inter-container Communication
```bash
# Execute command in API container to test MongoDB connection
docker-compose exec todo-api node -e "
const mongoose = require('mongoose');
mongoose.connect('mongodb://mongodb:27017/todoapi')
  .then(() => console.log('✅ MongoDB connection successful'))
  .catch(err => console.log('❌ MongoDB connection failed:', err.message));
"
```

## Troubleshooting

### Common Issues

#### 1. Port Already in Use
```bash
# Check what's using the ports
lsof -i :3000
lsof -i :27017

# Kill processes if needed
sudo kill -9 <PID>
```

#### 2. Docker Daemon Not Running
```bash
# Start Docker Desktop or Docker daemon
# On macOS: Open Docker Desktop application
# On Linux: sudo systemctl start docker
```

#### 3. Permission Issues
```bash
# Fix Docker permissions (Linux)
sudo usermod -aG docker $USER
newgrp docker
```

#### 4. Container Build Failures
```bash
# Clean Docker cache
docker system prune -a

# Rebuild containers
docker-compose build --no-cache
```

#### 5. Database Connection Issues
```bash
# Check MongoDB container logs
docker-compose logs mongodb

# Check API container logs
docker-compose logs todo-api

# Restart MongoDB service
docker-compose restart mongodb
```

### Debugging Commands

```bash
# View all container logs
docker-compose logs

# View specific service logs
docker-compose logs todo-api
docker-compose logs mongodb

# Execute shell in container
docker-compose exec todo-api sh
docker-compose exec mongodb mongosh

# Check container resource usage
docker stats

# Inspect container details
docker-compose exec todo-api env
```

## Test Results Verification

### Successful Test Indicators

1. **Configuration Validation**: All checks pass with ✅ symbols
2. **Container Startup**: Services show "Up" status in `docker-compose ps`
3. **API Health**: Health endpoint returns 200 status with database connected
4. **CRUD Operations**: All API endpoints respond correctly
5. **Data Persistence**: Data survives container restarts and shutdowns
6. **Network Communication**: API can connect to MongoDB container

### Expected Test Output

When running `./test-docker-setup.sh`, you should see:
- All tests marked with ✅ (green checkmarks)
- No ❌ (red X marks) indicating failures
- Final summary showing all test categories passed
- Confirmation that Docker Compose setup is working correctly

## Cleanup

```bash
# Stop and remove containers, networks, and volumes
docker-compose down -v

# Remove unused Docker resources
docker system prune -f

# Remove Docker images (optional)
docker-compose down --rmi all
```

## Requirements Verification

This testing validates the following requirements:

- **Requirement 2.1**: Docker Compose starts both MongoDB and API containers
- **Requirement 2.2**: API is accessible at http://localhost:3000
- **Requirement 2.3**: Todo data persists in MongoDB container
- **Requirement 2.4**: Data remains intact after container restarts

The comprehensive testing ensures the Docker Compose setup meets all specified requirements for container orchestration and data persistence.