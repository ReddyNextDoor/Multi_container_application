#!/bin/bash

# Docker Compose Configuration Validation Script
# This script validates the Docker Compose setup without requiring Docker to be running

set -e

echo "🔍 Docker Compose Configuration Validation"
echo "=========================================="

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Test 1: Check if Docker Compose file exists
print_status $BLUE "📋 Test 1: Docker Compose File Validation"
if [ -f "docker-compose.yml" ]; then
    print_status $GREEN "✅ docker-compose.yml exists"
else
    print_status $RED "❌ docker-compose.yml not found"
    exit 1
fi

# Test 2: Validate Docker Compose syntax
print_status $BLUE "📋 Test 2: Docker Compose Syntax Validation"
if docker-compose config > /dev/null 2>&1; then
    print_status $GREEN "✅ Docker Compose syntax is valid"
else
    print_status $RED "❌ Docker Compose syntax validation failed"
    print_status $YELLOW "Running docker-compose config to show errors:"
    docker-compose config
    exit 1
fi

# Test 3: Check required files exist
print_status $BLUE "📋 Test 3: Required Files Check"

required_files=(
    "Dockerfile"
    "package.json"
    "src/server.js"
    "src/utils/config.js"
    "src/utils/database.js"
    "src/routes/todos.js"
)

for file in "${required_files[@]}"; do
    if [ -f "$file" ]; then
        print_status $GREEN "✅ $file exists"
    else
        print_status $RED "❌ $file not found"
        exit 1
    fi
done

# Test 4: Validate Docker Compose configuration structure
print_status $BLUE "📋 Test 4: Docker Compose Structure Validation"

# Check if required services are defined
services=$(docker-compose config --services)
expected_services=("mongodb" "todo-api")

for service in "${expected_services[@]}"; do
    if echo "$services" | grep -q "^$service$"; then
        print_status $GREEN "✅ Service '$service' is defined"
    else
        print_status $RED "❌ Service '$service' is missing"
        exit 1
    fi
done

# Test 5: Check network configuration
print_status $BLUE "📋 Test 5: Network Configuration Check"
if docker-compose config | grep -q "todo-network"; then
    print_status $GREEN "✅ Custom network 'todo-network' is configured"
else
    print_status $RED "❌ Custom network 'todo-network' is missing"
    exit 1
fi

# Test 6: Check volume configuration
print_status $BLUE "📋 Test 6: Volume Configuration Check"
volumes=$(docker-compose config | grep -A 10 "^volumes:" | grep -E "^\s+[a-zA-Z]")
expected_volumes=("mongodb_data" "mongodb_config")

for volume in "${expected_volumes[@]}"; do
    if echo "$volumes" | grep -q "$volume"; then
        print_status $GREEN "✅ Volume '$volume' is configured"
    else
        print_status $RED "❌ Volume '$volume' is missing"
        exit 1
    fi
done

# Test 7: Check environment variables
print_status $BLUE "📋 Test 7: Environment Variables Check"
config_output=$(docker-compose config)

required_env_vars=(
    "MONGODB_URI"
    "NODE_ENV"
    "PORT"
    "DB_NAME"
)

for env_var in "${required_env_vars[@]}"; do
    if echo "$config_output" | grep -q "$env_var"; then
        print_status $GREEN "✅ Environment variable '$env_var' is configured"
    else
        print_status $RED "❌ Environment variable '$env_var' is missing"
        exit 1
    fi
done

# Test 8: Check health checks
print_status $BLUE "📋 Test 8: Health Check Configuration"
if echo "$config_output" | grep -q "healthcheck"; then
    print_status $GREEN "✅ Health checks are configured"
else
    print_status $YELLOW "⚠️  Health checks not found (optional but recommended)"
fi

# Test 9: Check port mappings
print_status $BLUE "📋 Test 9: Port Mapping Check"
if echo "$config_output" | grep -q "target: 3000"; then
    print_status $GREEN "✅ API port mapping (3000) is configured"
else
    print_status $RED "❌ API port mapping is missing or incorrect"
    exit 1
fi

if echo "$config_output" | grep -q "target: 27017"; then
    print_status $GREEN "✅ MongoDB port mapping (27017) is configured"
else
    print_status $RED "❌ MongoDB port mapping is missing or incorrect"
    exit 1
fi

# Test 10: Check service dependencies
print_status $BLUE "📋 Test 10: Service Dependencies Check"
if echo "$config_output" | grep -A 5 "depends_on" | grep -q "mongodb"; then
    print_status $GREEN "✅ API service depends on MongoDB"
else
    print_status $RED "❌ Service dependency configuration is missing"
    exit 1
fi

print_status $GREEN "🎉 All Docker Compose configuration validations passed!"
print_status $BLUE "📊 Configuration Summary:"
echo "   ✅ Valid Docker Compose syntax"
echo "   ✅ All required services defined (mongodb, todo-api)"
echo "   ✅ Custom network configured"
echo "   ✅ Persistent volumes configured"
echo "   ✅ Environment variables set"
echo "   ✅ Port mappings configured"
echo "   ✅ Service dependencies defined"

print_status $YELLOW "📝 Next Steps:"
echo "   1. Start Docker Desktop or Docker daemon"
echo "   2. Run: docker-compose up -d"
echo "   3. Test API at: http://localhost:3000"
echo "   4. Run full integration tests with: ./test-docker-setup.sh"

print_status $GREEN "✅ Docker Compose setup is properly configured!"