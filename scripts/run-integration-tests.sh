#!/bin/bash

# Integration test runner for Todo API deployment
# This script runs comprehensive integration tests for the entire deployment pipeline

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
TEST_RESULTS_DIR="$PROJECT_ROOT/test-results"

# Default values
TEST_TYPE="${TEST_TYPE:-all}"
CLEANUP="${CLEANUP:-true}"
VERBOSE="${VERBOSE:-false}"
PARALLEL="${PARALLEL:-false}"
ENVIRONMENT="${ENVIRONMENT:-integration-test}"

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

Run integration tests for Todo API deployment

OPTIONS:
    -t, --type          Test type (all|infrastructure|ansible|deployment) (default: all)
    -e, --environment   Test environment name (default: integration-test)
    -c, --cleanup       Clean up resources after tests (default: true)
    -v, --verbose       Enable verbose output
    -p, --parallel      Run tests in parallel (default: false)
    --no-cleanup        Skip cleanup after tests
    --help              Show this help message

TEST TYPES:
    all                 Run all integration tests
    infrastructure      Run infrastructure validation tests only
    ansible            Run Ansible configuration tests only
    deployment         Run full deployment integration tests only

ENVIRONMENT VARIABLES:
    TEST_TYPE          Test type to run
    CLEANUP            Whether to clean up after tests (true/false)
    VERBOSE            Enable verbose output (true/false)
    PARALLEL           Run tests in parallel (true/false)
    ENVIRONMENT        Test environment name
    AWS_REGION         AWS region for infrastructure tests
    DOCKER_USERNAME    Docker Hub username for deployment tests

EXAMPLES:
    $0                                    # Run all tests
    $0 --type infrastructure             # Run infrastructure tests only
    $0 --type deployment --verbose       # Run deployment tests with verbose output
    $0 --no-cleanup                      # Run tests without cleanup

EOF
}

# Parse command line arguments
while [[ $# -gt 0 ]]; do
    case $1 in
        -t|--type)
            TEST_TYPE="$2"
            shift 2
            ;;
        -e|--environment)
            ENVIRONMENT="$2"
            shift 2
            ;;
        -c|--cleanup)
            CLEANUP="true"
            shift
            ;;
        --no-cleanup)
            CLEANUP="false"
            shift
            ;;
        -v|--verbose)
            VERBOSE="true"
            shift
            ;;
        -p|--parallel)
            PARALLEL="true"
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

# Validate test type
case "$TEST_TYPE" in
    all|infrastructure|ansible|deployment)
        ;;
    *)
        log_error "Invalid test type: $TEST_TYPE"
        usage
        exit 1
        ;;
esac

# Function to check prerequisites
check_prerequisites() {
    log_info "Checking prerequisites..."
    
    # Check required tools
    local required_tools=("node" "npm" "docker" "aws")
    local missing_tools=()
    
    for tool in "${required_tools[@]}"; do
        if ! command -v "$tool" &> /dev/null; then
            missing_tools+=("$tool")
        else
            log_debug "$tool is available"
        fi
    done
    
    if [[ ${#missing_tools[@]} -gt 0 ]]; then
        log_error "Missing required tools: ${missing_tools[*]}"
        return 1
    fi
    
    # Check Node.js version
    local node_version
    node_version=$(node --version | sed 's/v//')
    local major_version
    major_version=$(echo "$node_version" | cut -d. -f1)
    
    if [[ $major_version -lt 16 ]]; then
        log_error "Node.js version 16+ required, found: $node_version"
        return 1
    fi
    
    log_debug "Node.js version: $node_version"
    
    # Check Docker
    if ! docker info &> /dev/null; then
        log_error "Docker is not running"
        return 1
    fi
    
    log_debug "Docker is running"
    
    # Check AWS credentials (if needed)
    if [[ "$TEST_TYPE" == "all" || "$TEST_TYPE" == "infrastructure" || "$TEST_TYPE" == "deployment" ]]; then
        if ! aws sts get-caller-identity &> /dev/null; then
            log_warn "AWS credentials not configured - some tests may be skipped"
        else
            log_debug "AWS credentials are configured"
        fi
    fi
    
    log_info "Prerequisites check completed"
}

# Function to setup test environment
setup_test_environment() {
    log_info "Setting up test environment..."
    
    # Create test results directory
    mkdir -p "$TEST_RESULTS_DIR"/{integration,logs,artifacts}
    
    # Install test dependencies
    log_info "Installing test dependencies..."
    cd "$PROJECT_ROOT"
    npm install --silent
    
    # Set environment variables
    export NODE_ENV=test
    export TEST_ENVIRONMENT="$ENVIRONMENT"
    export AWS_REGION="${AWS_REGION:-us-east-1}"
    
    if [[ "$VERBOSE" == "true" ]]; then
        export VERBOSE=true
    fi
    
    log_info "Test environment setup completed"
}

# Function to run specific test suite
run_test_suite() {
    local test_file="$1"
    local test_name="$2"
    
    log_info "Running $test_name tests..."
    
    local jest_args=(
        "--config" "tests/integration/jest.config.js"
        "--testPathPattern" "$test_file"
        "--verbose"
    )
    
    if [[ "$VERBOSE" == "true" ]]; then
        jest_args+=("--detectOpenHandles")
    fi
    
    local start_time
    start_time=$(date +%s)
    
    if npm run test:integration -- "${jest_args[@]}"; then
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_info "$test_name tests completed successfully in ${duration}s"
        return 0
    else
        local end_time
        end_time=$(date +%s)
        local duration=$((end_time - start_time))
        
        log_error "$test_name tests failed after ${duration}s"
        return 1
    fi
}

# Function to run all tests
run_all_tests() {
    log_info "Running all integration tests..."
    
    local test_results=()
    local overall_start_time
    overall_start_time=$(date +%s)
    
    # Define test suites
    local test_suites=(
        "infrastructure-validation.test.js:Infrastructure Validation"
        "ansible-validation.test.js:Ansible Configuration"
        "deployment-integration.test.js:Deployment Integration"
    )
    
    # Run tests based on type
    case "$TEST_TYPE" in
        infrastructure)
            test_suites=("infrastructure-validation.test.js:Infrastructure Validation")
            ;;
        ansible)
            test_suites=("ansible-validation.test.js:Ansible Configuration")
            ;;
        deployment)
            test_suites=("deployment-integration.test.js:Deployment Integration")
            ;;
        all)
            # Use all test suites
            ;;
    esac
    
    # Run tests sequentially or in parallel
    if [[ "$PARALLEL" == "true" && "$TEST_TYPE" == "all" ]]; then
        log_info "Running tests in parallel..."
        
        local pids=()
        
        for suite in "${test_suites[@]}"; do
            IFS=':' read -r test_file test_name <<< "$suite"
            (
                run_test_suite "$test_file" "$test_name"
                echo $? > "$TEST_RESULTS_DIR/${test_name// /_}_result.txt"
            ) &
            pids+=($!)
        done
        
        # Wait for all tests to complete
        for pid in "${pids[@]}"; do
            wait "$pid"
        done
        
        # Check results
        local failed_tests=()
        for suite in "${test_suites[@]}"; do
            IFS=':' read -r test_file test_name <<< "$suite"
            local result_file="$TEST_RESULTS_DIR/${test_name// /_}_result.txt"
            if [[ -f "$result_file" ]]; then
                local result
                result=$(cat "$result_file")
                if [[ "$result" != "0" ]]; then
                    failed_tests+=("$test_name")
                fi
                rm -f "$result_file"
            fi
        done
        
        if [[ ${#failed_tests[@]} -gt 0 ]]; then
            log_error "Failed test suites: ${failed_tests[*]}"
            return 1
        fi
        
    else
        log_info "Running tests sequentially..."
        
        for suite in "${test_suites[@]}"; do
            IFS=':' read -r test_file test_name <<< "$suite"
            
            if ! run_test_suite "$test_file" "$test_name"; then
                log_error "Test suite failed: $test_name"
                return 1
            fi
        done
    fi
    
    local overall_end_time
    overall_end_time=$(date +%s)
    local total_duration=$((overall_end_time - overall_start_time))
    
    log_info "All tests completed successfully in ${total_duration}s"
    return 0
}

# Function to generate test report
generate_test_report() {
    log_info "Generating test report..."
    
    local report_file="$TEST_RESULTS_DIR/integration-test-summary.md"
    
    cat > "$report_file" << EOF
# Integration Test Report

**Generated:** $(date -u +"%Y-%m-%d %H:%M:%S UTC")
**Environment:** $ENVIRONMENT
**Test Type:** $TEST_TYPE
**Platform:** $(uname -s) $(uname -m)
**Node.js:** $(node --version)

## Test Configuration

- **Cleanup:** $CLEANUP
- **Verbose:** $VERBOSE
- **Parallel:** $PARALLEL
- **AWS Region:** ${AWS_REGION:-not set}

## Test Results

EOF
    
    # Add test results if available
    if [[ -f "$TEST_RESULTS_DIR/integration/integration-test-results.xml" ]]; then
        echo "See detailed results in: \`integration-test-results.xml\`" >> "$report_file"
    fi
    
    # Add system information
    cat >> "$report_file" << EOF

## System Information

- **Memory:** $(free -h | grep '^Mem:' | awk '{print $3 "/" $2}' 2>/dev/null || echo "N/A")
- **Disk:** $(df -h . | tail -1 | awk '{print $3 "/" $2 " (" $5 " used)"}' 2>/dev/null || echo "N/A")
- **CPU:** $(nproc 2>/dev/null || echo "N/A") cores
- **Docker:** $(docker --version 2>/dev/null || echo "N/A")

## Artifacts

EOF
    
    # List artifacts
    if [[ -d "$TEST_RESULTS_DIR/artifacts" ]]; then
        local artifacts
        artifacts=$(ls -la "$TEST_RESULTS_DIR/artifacts" 2>/dev/null || echo "No artifacts")
        echo "\`\`\`" >> "$report_file"
        echo "$artifacts" >> "$report_file"
        echo "\`\`\`" >> "$report_file"
    else
        echo "No artifacts generated" >> "$report_file"
    fi
    
    log_info "Test report generated: $report_file"
}

# Function to cleanup test resources
cleanup_test_resources() {
    if [[ "$CLEANUP" != "true" ]]; then
        log_info "Skipping cleanup (--no-cleanup specified)"
        return 0
    fi
    
    log_info "Cleaning up test resources..."
    
    # Clean up any test infrastructure that might have been created
    # This is handled by the individual test files, but we can add
    # additional cleanup here if needed
    
    # Clean up Docker test images
    local test_images=(
        "todo-api:test"
        "todo-api:integration-test"
        "${DOCKER_USERNAME:-testuser}/todo-api:integration-test"
    )
    
    for image in "${test_images[@]}"; do
        if docker images --format "{{.Repository}}:{{.Tag}}" | grep -q "^$image$"; then
            log_debug "Removing Docker image: $image"
            docker rmi "$image" &> /dev/null || true
        fi
    done
    
    # Clean up unused Docker resources
    docker system prune -f &> /dev/null || true
    
    log_info "Cleanup completed"
}

# Main execution
main() {
    log_info "Starting integration tests..."
    log_info "Test type: $TEST_TYPE"
    log_info "Environment: $ENVIRONMENT"
    log_info "Cleanup: $CLEANUP"
    
    # Check prerequisites
    if ! check_prerequisites; then
        log_error "Prerequisites check failed"
        exit 1
    fi
    
    # Setup test environment
    setup_test_environment
    
    # Run tests
    local test_exit_code=0
    if ! run_all_tests; then
        test_exit_code=1
    fi
    
    # Generate report
    generate_test_report
    
    # Cleanup
    cleanup_test_resources
    
    # Final status
    if [[ $test_exit_code -eq 0 ]]; then
        log_info "✅ All integration tests passed!"
        echo
        log_info "Test results available in: $TEST_RESULTS_DIR"
    else
        log_error "❌ Some integration tests failed!"
        echo
        log_error "Check test results in: $TEST_RESULTS_DIR"
        exit 1
    fi
}

# Run main function
main "$@"