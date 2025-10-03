#!/bin/bash

# Health check script for Todo API
# This script performs comprehensive health checks on the deployed application

set -euo pipefail

# Default values
SERVER_HOST="${SERVER_HOST:-localhost}"
SERVER_PORT="${SERVER_PORT:-3000}"
TIMEOUT="${TIMEOUT:-30}"
VERBOSE="${VERBOSE:-false}"

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
    if [[ "$VERBOSE" == "true" ]]; then
        echo -e "${BLUE}[DEBUG]${NC} $1"
    fi
}

# Usage function
usage() {
    cat << EOF
Usage: $0 [OPTIONS]

Perform health checks on Todo API application

OPTIONS:
    -h, --host          Server hostname or IP address (default: localhost)
    -p, --port          Server port (default: 3000)
    -t, --timeout       Timeout in seconds (default: 30)
    -v, --verbose       Enable verbose output
    --help              Show this help message

ENVIRONMENT VARIABLES:
    SERVER_HOST         Server hostname or IP address
    SERVER_PORT         Server port
    TIMEOUT             Timeout in seconds
    VERBOSE             Enable verbose output (true/false)

EXAMPLES:
    $0
    $0 --host 192.168.1.100 --port 3000
    $0 -h example.com -p 80 -t 60 -v

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -h|--host)
            SERVER_HOST="$2"
            shift 2
            ;;
        -p|--port)
            SERVER_PORT="$2"
            shift 2
            ;;
        -t|--timeout)
            TIMEOUT="$2"
            shift 2
            ;;
        -v|--verbose)
            VERBOSE="true"
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

# Base URL
BASE_URL="http://$SERVER_HOST:$SERVER_PORT"

# Health check results
HEALTH_CHECKS=()
FAILED_CHECKS=0

# Function to perform HTTP request with timeout
http_request() {
    local url="$1"
    local method="${2:-GET}"
    local data="${3:-}"
    local expected_status="${4:-200}"
    
    log_debug "Making $method request to $url"
    
    local response
    local status_code
    
    if [[ -n "$data" ]]; then
        response=$(curl -s -w "\n%{http_code}" -X "$method" -H "Content-Type: application/json" -d "$data" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo -e "\n000")
    else
        response=$(curl -s -w "\n%{http_code}" -X "$method" --max-time "$TIMEOUT" "$url" 2>/dev/null || echo -e "\n000")
    fi
    
    status_code=$(echo "$response" | tail -n1)
    body=$(echo "$response" | head -n -1)
    
    log_debug "Response status: $status_code"
    log_debug "Response body: $body"
    
    if [[ "$status_code" == "$expected_status" ]]; then
        return 0
    else
        return 1
    fi
}

# Function to add health check result
add_check_result() {
    local name="$1"
    local status="$2"
    local message="$3"
    
    HEALTH_CHECKS+=("$name|$status|$message")
    
    if [[ "$status" == "FAIL" ]]; then
        ((FAILED_CHECKS++))
        log_error "$name: $message"
    else
        log_info "$name: $message"
    fi
}

# Health check functions
check_basic_connectivity() {
    log_info "Checking basic connectivity..."
    
    if http_request "$BASE_URL" "GET"; then
        add_check_result "Basic Connectivity" "PASS" "Server is responding"
    else
        add_check_result "Basic Connectivity" "FAIL" "Server is not responding"
    fi
}

check_health_endpoint() {
    log_info "Checking health endpoint..."
    
    if http_request "$BASE_URL/health" "GET"; then
        add_check_result "Health Endpoint" "PASS" "Health endpoint is working"
    else
        add_check_result "Health Endpoint" "FAIL" "Health endpoint is not responding"
    fi
}

check_api_endpoints() {
    log_info "Checking API endpoints..."
    
    # Test GET /todos
    if http_request "$BASE_URL/todos" "GET"; then
        add_check_result "GET /todos" "PASS" "Todos endpoint is working"
    else
        add_check_result "GET /todos" "FAIL" "Todos endpoint is not working"
        return
    fi
    
    # Test POST /todos
    local test_todo='{"title":"Health Check Test","description":"This is a test todo for health check"}'
    if http_request "$BASE_URL/todos" "POST" "$test_todo" "201"; then
        add_check_result "POST /todos" "PASS" "Create todo endpoint is working"
        
        # Get the created todo ID for further tests
        local response
        response=$(curl -s -X POST -H "Content-Type: application/json" -d "$test_todo" --max-time "$TIMEOUT" "$BASE_URL/todos" 2>/dev/null || echo '{}')
        local todo_id
        todo_id=$(echo "$response" | jq -r '.data._id' 2>/dev/null || echo "")
        
        if [[ -n "$todo_id" && "$todo_id" != "null" ]]; then
            # Test GET /todos/:id
            if http_request "$BASE_URL/todos/$todo_id" "GET"; then
                add_check_result "GET /todos/:id" "PASS" "Get single todo endpoint is working"
            else
                add_check_result "GET /todos/:id" "FAIL" "Get single todo endpoint is not working"
            fi
            
            # Test PUT /todos/:id
            local update_todo='{"title":"Updated Health Check Test","completed":true}'
            if http_request "$BASE_URL/todos/$todo_id" "PUT" "$update_todo"; then
                add_check_result "PUT /todos/:id" "PASS" "Update todo endpoint is working"
            else
                add_check_result "PUT /todos/:id" "FAIL" "Update todo endpoint is not working"
            fi
            
            # Test DELETE /todos/:id
            if http_request "$BASE_URL/todos/$todo_id" "DELETE"; then
                add_check_result "DELETE /todos/:id" "PASS" "Delete todo endpoint is working"
            else
                add_check_result "DELETE /todos/:id" "FAIL" "Delete todo endpoint is not working"
            fi
        else
            add_check_result "API Integration" "FAIL" "Could not extract todo ID from response"
        fi
    else
        add_check_result "POST /todos" "FAIL" "Create todo endpoint is not working"
    fi
}

check_database_connectivity() {
    log_info "Checking database connectivity through health endpoint..."
    
    local response
    response=$(curl -s --max-time "$TIMEOUT" "$BASE_URL/health" 2>/dev/null || echo '{}')
    
    local db_status
    db_status=$(echo "$response" | jq -r '.database.status' 2>/dev/null || echo "unknown")
    
    if [[ "$db_status" == "connected" ]]; then
        add_check_result "Database Connectivity" "PASS" "Database is connected and healthy"
    else
        add_check_result "Database Connectivity" "FAIL" "Database connection issue: $db_status"
    fi
}

check_response_times() {
    log_info "Checking response times..."
    
    local start_time
    local end_time
    local response_time
    
    start_time=$(date +%s%N)
    if http_request "$BASE_URL/health" "GET"; then
        end_time=$(date +%s%N)
        response_time=$(( (end_time - start_time) / 1000000 )) # Convert to milliseconds
        
        if [[ $response_time -lt 1000 ]]; then
            add_check_result "Response Time" "PASS" "Health endpoint responded in ${response_time}ms"
        elif [[ $response_time -lt 5000 ]]; then
            add_check_result "Response Time" "WARN" "Health endpoint responded in ${response_time}ms (slow)"
        else
            add_check_result "Response Time" "FAIL" "Health endpoint responded in ${response_time}ms (too slow)"
        fi
    else
        add_check_result "Response Time" "FAIL" "Could not measure response time (endpoint not responding)"
    fi
}

# Function to display results
display_results() {
    echo
    log_info "=== HEALTH CHECK RESULTS ==="
    echo
    
    printf "%-25s %-8s %s\n" "CHECK" "STATUS" "MESSAGE"
    printf "%-25s %-8s %s\n" "-----" "------" "-------"
    
    for check in "${HEALTH_CHECKS[@]}"; do
        IFS='|' read -r name status message <<< "$check"
        
        case $status in
            "PASS")
                printf "%-25s ${GREEN}%-8s${NC} %s\n" "$name" "$status" "$message"
                ;;
            "WARN")
                printf "%-25s ${YELLOW}%-8s${NC} %s\n" "$name" "$status" "$message"
                ;;
            "FAIL")
                printf "%-25s ${RED}%-8s${NC} %s\n" "$name" "$status" "$message"
                ;;
        esac
    done
    
    echo
    
    if [[ $FAILED_CHECKS -eq 0 ]]; then
        log_info "✅ All health checks passed!"
        echo
        log_info "Application is healthy and ready to serve requests"
        log_info "Base URL: $BASE_URL"
        return 0
    else
        log_error "❌ $FAILED_CHECKS health check(s) failed!"
        echo
        log_error "Application may not be functioning correctly"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting health checks for Todo API"
    log_info "Target: $BASE_URL"
    log_info "Timeout: ${TIMEOUT}s"
    echo
    
    # Check if curl is available
    if ! command -v curl &> /dev/null; then
        log_error "curl command not found. Please install curl."
        exit 1
    fi
    
    # Check if jq is available (optional but recommended)
    if ! command -v jq &> /dev/null; then
        log_warn "jq command not found. Some checks may be limited."
    fi
    
    # Perform health checks
    check_basic_connectivity
    check_health_endpoint
    check_database_connectivity
    check_response_times
    check_api_endpoints
    
    # Display results
    display_results
}

# Run main function
main "$@"