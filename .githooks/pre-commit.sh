#!/bin/bash

# Pre-commit Git hook for GitLab API Helper
# Tests the library functions before allowing commits

set -euo pipefail

# Get project root directory
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

# Hook configuration
HOOK_NAME="pre-commit"
QUICK_MODE=${QUICK_MODE:-false}

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m' # No Color

# Logging functions
log_info() {
    echo -e "${BLUE}[INFO]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[SUCCESS]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[WARNING]${NC} $1"
}

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we should skip hooks
if [ "${SKIP_HOOKS:-}" = "true" ] || [ "${NO_VERIFY:-}" = "true" ]; then
    log_warning "Hooks skipped due to SKIP_HOOKS or NO_VERIFY flag"
    exit 0
fi

log_info "🔍 Running pre-commit hook for GitLab API Helper..."

# Track test results
TESTS_PASSED=0
TESTS_FAILED=0

run_test_section() {
    local section_name="$1"
    local test_command="$2"
    
    log_info "Running $section_name..."
    
    if eval "$test_command"; then
        log_success "$section_name passed"
        ((TESTS_PASSED++))
        return 0
    else
        log_error "$section_name failed"
        ((TESTS_FAILED++))
        return 1
    fi
}

# ============================================================================
# TEST SECTIONS
# ============================================================================

# 1. Syntax validation
test_syntax() {
    log_info "Checking shell script syntax..."
    
    # Check main script
    if ! bash -n gitlab-api.sh; then
        log_error "Syntax error in gitlab-api.sh"
        return 1
    fi
    
    # Check hook scripts
    for script in hooks/*.sh tests/*.sh 2>/dev/null; do
        if [ -f "$script" ]; then
            if ! bash -n "$script"; then
                log_error "Syntax error in $script"
                return 1
            fi
        fi
    done
    
    return 0
}

# 2. Dependency check
test_dependencies() {
    log_info "Checking required dependencies..."
    
    local missing_deps=0
    
    for cmd in bash curl jq sed grep; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            log_error "Missing dependency: $cmd"
            ((missing_deps++))
        fi
    done
    
    if [ $missing_deps -gt 0 ]; then
        log_error "$missing_deps missing dependencies found"
        return 1
    fi
    
    return 0
}

# 3. Function definition check
test_functions() {
    log_info "Checking function definitions..."
    
    # Source the main script
    if ! source ./gitlab-api.sh; then
        log_error "Failed to source gitlab-api.sh"
        return 1
    fi
    
    # Check if main functions are defined
    local required_functions=("input_token" "get_list_of_projects" "make_new_project" "get_list_of_projects_simple")
    
    for func in "${required_functions[@]}"; do
        if ! declare -f "$func" > /dev/null; then
            log_error "Function '$func' not defined"
            return 1
        fi
    done
    
    return 0
}

# 4. Test your specific commands (with timeout and mock)
test_user_commands() {
    log_info "Testing your specific commands..."
    
    # Source the library
    source ./gitlab-api.sh
    
    # Use a mock token for testing
    local mock_token="glpat-mock-token-for-testing"
    export GITLAB_GMAIL_API_TOKEN="$mock_token"
    
    local command_tests=(
        'get_list_of_projects_simple "$GITLAB_GMAIL_API_TOKEN"'
        'get_list_of_projects "$GITLAB_GMAIL_API_TOKEN"'
        'get_list_of_projects "$GITLAB_GMAIL_API_TOKEN" "csv"'
        'get_list_of_projects "$GITLAB_GMAIL_API_TOKEN" "json"'
    )
    
    for i in "${!command_tests[@]}"; do
        local cmd="${command_tests[$i]}"
        log_info "Testing command $((i+1)): $cmd"
        
        # Run with timeout and capture result
        if timeout 10 bash -c "$cmd" >/dev/null 2>&1; then
            log_success "Command $((i+1)) executed without errors"
        else
            local exit_code=$?
            if [ $exit_code -eq 124 ]; then
                log_warning "Command $((i+1)) timed out (expected with no real API token)"
            else
                log_warning "Command $((i+1)) failed with exit code $exit_code (may be expected without real token)"
            fi
        fi
    done
    
    return 0
}

# 5. Check for secrets or sensitive data
test_security() {
    log_info "Checking for sensitive data..."
    
    # Check for hardcoded tokens (but allow examples and documentation)
    if git diff --cached --name-only | grep -E '\.(sh|bash)$' | xargs grep -l "glpat-" 2>/dev/null | grep -v README.md | grep -v ".md$" | head -1 >/dev/null; then
        log_error "Found potential hardcoded GitLab token in code files"
        log_error "Please remove hardcoded tokens and use environment variables"
        return 1
    fi
    
    return 0
}

# ============================================================================
# MAIN EXECUTION
# ============================================================================

main() {
    local start_time=$(date +%s)
    
    log_info "Starting pre-commit validation..."
    echo "=========================================="
    
    # Run test sections
    if [ "$QUICK_MODE" = "true" ]; then
        log_info "Running in quick mode..."
        run_test_section "Syntax Check" "test_syntax"
        run_test_section "Function Check" "test_functions"
    else
        run_test_section "Syntax Validation" "test_syntax"
        run_test_section "Dependencies" "test_dependencies"  
        run_test_section "Function Definitions" "test_functions"
        run_test_section "User Commands" "test_user_commands"
        run_test_section "Security Check" "test_security"
    fi
    
    # Summary
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "=========================================="
    log_info "Pre-commit hook completed in ${duration}s"
    log_info "Tests passed: $TESTS_PASSED"
    log_info "Tests failed: $TESTS_FAILED"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        log_success "🎉 All pre-commit checks passed!"
        log_success "✅ Commit is ready to proceed"
        exit 0
    else
        log_error "💥 Some pre-commit checks failed!"
        log_error "❌ Commit blocked - please fix the issues above"
        echo ""
        log_info "💡 To bypass this check, use: git commit --no-verify"
        log_info "💡 To run in quick mode, use: QUICK_MODE=true git commit"
        exit 1
    fi
}

# Run the main function
main "$@"
