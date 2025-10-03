#!/bin/bash

# Docker Compose Setup Test Script
# This script tests the Docker Compose configuration for the Todo API

set -e  # Exit on any error

echo "🧪 Starting Docker Compose Setup Tests"
echo "======================================"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Test configuration
API_URL="http://localhost:3000"
HEALTH_URL="$API_URL/health"
TODOS_URL="$API_URL/todos"
MAX_WAIT_TIME=120  # Maximum wait time in seconds
POLL_INTERVAL=5    # Poll interval in seconds

# Function to print colored output
print_status() {
    local color=$1
    local message=$2
    echo -e "${color}${message}${NC}"
}

# Function to wait for service to be ready
wait_for_service() {
    local url=$1
    local service_name=$2
    local wait_time=0
    
    print_status $YELLOW "⏳ Waiting for $service_name to be ready..."
    
    while [ $wait_time -lt $MAX_WAIT_TIME ]; do
        if curl -s -f "$url" > /dev/null 2>&1; then
            print_status $GREEN "✅ $service_name is ready!"
            return 0
        fi
        
        echo "   Waiting... ($wait_time/$MAX_WAIT_TIME seconds)"
        sleep $POLL_INTERVAL
        wait_time=$((wait_time + POLL_INTERVAL))
    done
    
    print_status $RED "❌ $service_name failed to start within $MAX_WAIT_TIME seconds"
    return 1
}

# Function to test API endpoint
test_api_endpoint() {
    local method=$1
    local url=$2
    local data=$3
    local expected_status=$4
    local description=$5
    
    print_status $BLUE "🔍 Testing: $description"
    
    if [ -n "$data" ]; then
        response=$(curl -s -w "%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" "$url")
    else
        response=$(curl -s -w "%{http_code}" -X "$method" "$url")
    fi
    
    # Extract status code (last 3 characters)
    status_code="${response: -3}"
    response_body="${response%???}"
    
    if [ "$status_code" = "$expected_status" ]; then
        print_status $GREEN "   ✅ Success: HTTP $status_code"
        echo "   Response: $response_body" | head -c 200
        echo
        return 0
    else
        print_status $RED "   ❌ Failed: Expected HTTP $expected_status, got HTTP $status_code"
        echo "   Response: $response_body"
        return 1
    fi
}

# Function to cleanup containers
cleanup() {
    print_status $YELLOW "🧹 Cleaning up containers..."
    docker-compose down -v --remove-orphans 2>/dev/null || true
    docker system prune -f 2>/dev/null || true
}

# Trap to ensure cleanup on exit
trap cleanup EXIT

# Test 1: Clean start - ensure no existing containers
print_status $BLUE "📋 Test 1: Clean Environment Setup"
cleanup
print_status $GREEN "✅ Environment cleaned"

# Test 2: Start containers
print_status $BLUE "📋 Test 2: Container Startup"
print_status $YELLOW "🚀 Starting Docker Compose services..."

if docker-compose up -d; then
    print_status $GREEN "✅ Docker Compose started successfully"
else
    print_status $RED "❌ Failed to start Docker Compose"
    exit 1
fi

# Test 3: Verify containers are running
print_status $BLUE "📋 Test 3: Container Status Verification"
sleep 5  # Give containers a moment to initialize

# Check if containers are running
if docker-compose ps | grep -q "Up"; then
    print_status $GREEN "✅ Containers are running"
    docker-compose ps
else
    print_status $RED "❌ Containers are not running properly"
    docker-compose ps
    docker-compose logs
    exit 1
fi

# Test 4: Wait for services to be ready
print_status $BLUE "📋 Test 4: Service Health Checks"
wait_for_service "$HEALTH_URL" "Todo API"

# Test 5: Test API endpoints
print_status $BLUE "📋 Test 5: API Functionality Tests"

# Test health endpoint
test_api_endpoint "GET" "$HEALTH_URL" "" "200" "Health check endpoint"

# Test root endpoint
test_api_endpoint "GET" "$API_URL" "" "200" "Root endpoint"

# Test GET all todos (should be empty initially)
test_api_endpoint "GET" "$TODOS_URL" "" "200" "Get all todos (empty)"

# Test POST create todo
todo_data='{"title":"Test Todo","description":"Testing Docker setup","completed":false}'
create_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$todo_data" "$TODOS_URL")
todo_id=$(echo "$create_response" | grep -o '"_id":"[^"]*"' | cut -d'"' -f4)

if [ -n "$todo_id" ]; then
    print_status $GREEN "✅ Todo created successfully with ID: $todo_id"
else
    print_status $RED "❌ Failed to create todo"
    echo "Response: $create_response"
    exit 1
fi

# Test GET specific todo
test_api_endpoint "GET" "$TODOS_URL/$todo_id" "" "200" "Get specific todo"

# Test PUT update todo
update_data='{"title":"Updated Test Todo","description":"Updated description","completed":true}'
test_api_endpoint "PUT" "$TODOS_URL/$todo_id" "$update_data" "200" "Update todo"

# Test 6: Data persistence test
print_status $BLUE "📋 Test 6: Data Persistence Test"

# Create another todo before restart
persistence_data='{"title":"Persistence Test","description":"This should survive restart","completed":false}'
persistence_response=$(curl -s -X POST -H "Content-Type: application/json" -d "$persistence_data" "$TODOS_URL")
persistence_id=$(echo "$persistence_response" | grep -o '"_id":"[^"]*"' | cut -d'"' -f4)

print_status $YELLOW "🔄 Restarting containers to test data persistence..."
docker-compose restart

# Wait for services to come back up
wait_for_service "$HEALTH_URL" "Todo API (after restart)"

# Verify data persisted
print_status $YELLOW "🔍 Checking if data persisted after restart..."

# Check if our todos still exist
if test_api_endpoint "GET" "$TODOS_URL/$todo_id" "" "200" "Original todo after restart"; then
    print_status $GREEN "✅ Original todo data persisted"
else
    print_status $RED "❌ Original todo data lost after restart"
    exit 1
fi

if test_api_endpoint "GET" "$TODOS_URL/$persistence_id" "" "200" "Persistence test todo after restart"; then
    print_status $GREEN "✅ Persistence test todo data persisted"
else
    print_status $RED "❌ Persistence test todo data lost after restart"
    exit 1
fi

# Test 7: Container communication test
print_status $BLUE "📋 Test 7: Container Communication Test"

# Check if API can communicate with MongoDB
health_response=$(curl -s "$HEALTH_URL")
if echo "$health_response" | grep -q '"status":"connected"'; then
    print_status $GREEN "✅ API successfully communicates with MongoDB"
else
    print_status $RED "❌ API cannot communicate with MongoDB"
    echo "Health response: $health_response"
    exit 1
fi

# Test 8: Volume persistence test
print_status $BLUE "📋 Test 8: Volume Persistence Test"

# Stop containers completely
print_status $YELLOW "🛑 Stopping containers completely..."
docker-compose down

# Start containers again
print_status $YELLOW "🚀 Starting containers again..."
docker-compose up -d

# Wait for services
wait_for_service "$HEALTH_URL" "Todo API (after full restart)"

# Check if data still exists after complete restart
if test_api_endpoint "GET" "$TODOS_URL/$todo_id" "" "200" "Todo after complete restart"; then
    print_status $GREEN "✅ Data persisted through complete container restart"
else
    print_status $RED "❌ Data lost after complete container restart"
    exit 1
fi

# Test 9: Cleanup test todo
print_status $BLUE "📋 Test 9: Cleanup Test Data"
test_api_endpoint "DELETE" "$TODOS_URL/$todo_id" "" "200" "Delete original todo"
test_api_endpoint "DELETE" "$TODOS_URL/$persistence_id" "" "200" "Delete persistence test todo"

# Verify todos are deleted
if test_api_endpoint "GET" "$TODOS_URL/$todo_id" "" "404" "Verify todo deletion"; then
    print_status $GREEN "✅ Todo successfully deleted"
else
    print_status $RED "❌ Todo deletion failed"
fi

# Final summary
print_status $GREEN "🎉 All Docker Compose setup tests passed!"
print_status $BLUE "📊 Test Summary:"
echo "   ✅ Container startup and communication"
echo "   ✅ API functionality (CRUD operations)"
echo "   ✅ Data persistence across container restarts"
echo "   ✅ Volume persistence across complete shutdowns"
echo "   ✅ MongoDB connectivity and health checks"

print_status $YELLOW "🏁 Docker Compose setup is working correctly!"