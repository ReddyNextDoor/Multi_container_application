#!/bin/bash

# Workflow validation script
# This script validates GitHub Actions workflow files for syntax errors

set -euo pipefail

# Configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
WORKFLOWS_DIR="$PROJECT_ROOT/.github/workflows"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
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

# Function to validate YAML syntax
validate_yaml() {
    local file="$1"
    
    log_info "Validating YAML syntax: $(basename "$file")"
    
    if command -v yq &> /dev/null; then
        if yq eval '.' "$file" > /dev/null 2>&1; then
            log_info "✅ YAML syntax is valid"
            return 0
        else
            log_error "❌ YAML syntax error in $file"
            return 1
        fi
    elif command -v python3 &> /dev/null; then
        if python3 -c "import yaml; yaml.safe_load(open('$file'))" 2>/dev/null; then
            log_info "✅ YAML syntax is valid"
            return 0
        else
            log_error "❌ YAML syntax error in $file"
            return 1
        fi
    else
        log_warn "⚠️ No YAML validator found (yq or python3), skipping syntax check"
        return 0
    fi
}

# Function to validate workflow structure
validate_workflow_structure() {
    local file="$1"
    
    log_info "Validating workflow structure: $(basename "$file")"
    
    # Check for required top-level keys
    local required_keys=("name" "on" "jobs")
    local missing_keys=()
    
    for key in "${required_keys[@]}"; do
        if ! grep -q "^$key:" "$file"; then
            missing_keys+=("$key")
        fi
    done
    
    if [[ ${#missing_keys[@]} -gt 0 ]]; then
        log_error "❌ Missing required keys: ${missing_keys[*]}"
        return 1
    fi
    
    # Check for at least one job
    if ! grep -q "^  [a-zA-Z0-9_-]*:" "$file"; then
        log_error "❌ No jobs defined in workflow"
        return 1
    fi
    
    log_info "✅ Workflow structure is valid"
    return 0
}

# Function to check for common issues
check_common_issues() {
    local file="$1"
    
    log_info "Checking for common issues: $(basename "$file")"
    
    local issues=()
    
    # Check for secrets usage without proper conditions
    if grep -q "secrets\." "$file" && ! grep -q "if:.*secrets\." "$file"; then
        issues+=("Secrets used without conditional checks")
    fi
    
    # Check for hardcoded values that should be secrets
    if grep -qE "(password|token|key).*:" "$file" | grep -v "secrets\."; then
        issues+=("Potential hardcoded secrets found")
    fi
    
    # Check for missing error handling in scripts
    if grep -q "run: |" "$file" && ! grep -q "set -e" "$file"; then
        issues+=("Multi-line scripts without error handling")
    fi
    
    if [[ ${#issues[@]} -gt 0 ]]; then
        log_warn "⚠️ Potential issues found:"
        for issue in "${issues[@]}"; do
            log_warn "  - $issue"
        done
    else
        log_info "✅ No common issues found"
    fi
    
    return 0
}

# Main validation function
validate_workflow() {
    local file="$1"
    
    echo
    log_info "=== Validating $(basename "$file") ==="
    
    local validation_passed=true
    
    # Validate YAML syntax
    if ! validate_yaml "$file"; then
        validation_passed=false
    fi
    
    # Validate workflow structure
    if ! validate_workflow_structure "$file"; then
        validation_passed=false
    fi
    
    # Check for common issues
    check_common_issues "$file"
    
    if [[ "$validation_passed" == "true" ]]; then
        log_info "✅ $(basename "$file") validation passed"
        return 0
    else
        log_error "❌ $(basename "$file") validation failed"
        return 1
    fi
}

# Main execution
main() {
    log_info "Starting GitHub Actions workflow validation..."
    
    if [[ ! -d "$WORKFLOWS_DIR" ]]; then
        log_error "Workflows directory not found: $WORKFLOWS_DIR"
        exit 1
    fi
    
    local workflow_files=()
    for file in "$WORKFLOWS_DIR"/*.yml "$WORKFLOWS_DIR"/*.yaml; do
        if [[ -f "$file" ]]; then
            workflow_files+=("$file")
        fi
    done
    
    if [[ ${#workflow_files[@]} -eq 0 ]]; then
        log_warn "No workflow files found in $WORKFLOWS_DIR"
        exit 0
    fi
    
    log_info "Found ${#workflow_files[@]} workflow file(s)"
    
    local failed_validations=0
    
    for workflow_file in "${workflow_files[@]}"; do
        if ! validate_workflow "$workflow_file"; then
            ((failed_validations++))
        fi
    done
    
    echo
    log_info "=== Validation Summary ==="
    log_info "Total workflows: ${#workflow_files[@]}"
    log_info "Passed: $((${#workflow_files[@]} - failed_validations))"
    
    if [[ $failed_validations -gt 0 ]]; then
        log_error "Failed: $failed_validations"
        log_error "❌ Workflow validation failed!"
        exit 1
    else
        log_info "Failed: 0"
        log_info "✅ All workflows validated successfully!"
        exit 0
    fi
}

# Run main function
main "$@"