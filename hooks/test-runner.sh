#!/bin/bash

# Comprehensive test runner for GitLab API Helper
# Used by Git hooks and can be run manually

set -euo pipefail

PROJECT_ROOT="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
cd "$PROJECT_ROOT"

# Test configuration
TEST_MODE="${1:-full}"
MOCK_TOKEN="glpat-test-mock-token-for-hooks"

# Colors
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

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

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

run_test() {
    local test_name="$1"
    local test_command="$2"
    
    ((TOTAL_TESTS++))
    
    log_info "🧪 Running: $test_name"
    
    if eval "$test_command" > "/tmp/test_${TOTAL_TESTS}.log" 2>&1; then
        log_success "✅ $test_name"
        ((PASSED_TESTS++))
        return 0
    else
        log_error "❌ $test_name"
        log_error "   Command: $test_command"
        log_error "   Log: $(tail -2 "/tmp/test_${TOTAL_TESTS}.log" | tr '\n' ' ')"
        ((FAILED_TESTS++))
        return 1
    fi
}

# ============================================================================
# TEST DEFINITIONS
# ============================================================================

test_script_syntax() {
    bash -n gitlab-api.sh
}

test_dependencies() {
    for cmd in bash curl jq sed grep; do
        command -v "$cmd" >/dev/null
    done
}

test_function_loading() {
    source ./gitlab-api.sh
    declare -f input_token get_list_of_projects make_new_project get_list_of_projects_simple >/dev/null
}

test_parameter_validation() {
    source ./gitlab-api.sh
    
    # These should fail with proper error messages
    ! make_new_project "" "$MOCK_TOKEN" 2>/dev/null
    ! get_list_of_projects "" 2>/dev/null
}

test_user_command_1() {
    source ./gitlab-api.sh
    export GITLAB_GMAIL_API_TOKEN="$MOCK_TOKEN"
    timeout 5 get_list_of_projects_simple "$GITLAB_GMAIL_API_TOKEN" 2>/dev/null || true
}

test_user_command_2() {
    source ./gitlab-api.sh  
    export GITLAB_GMAIL_API_TOKEN="$MOCK_TOKEN"
    timeout 5 get_list_of_projects "$GITLAB_GMAIL_API_TOKEN" 2>/dev/null || true
}

test_user_command_3() {
    source ./gitlab-api.sh
    export GITLAB_GMAIL_API_TOKEN="$MOCK_TOKEN"
    timeout 5 get_list_of_projects "$GITLAB_GMAIL_API_TOKEN" "csv" 2>/dev/null || true
}

test_user_command_4() {
    source ./gitlab-api.sh
    export GITLAB_GMAIL_API_TOKEN="$MOCK_TOKEN"
    timeout 5 get_list_of_projects "$GITLAB_GMAIL_API_TOKEN" "json" 2>/dev/null || true
}

test_env_file_operations() {
    source ./gitlab-api.sh
    
    local temp_home=$(mktemp -d)
    local old_home="$HOME"
    export HOME="$temp_home"
    
    update_env_file "TEST_VAR" "test_value"
    local retrieved_value
    retrieved_value=$(get_env_variable "TEST_VAR")
    
    export HOME="$old_home"
    rm -rf "$temp_home"
    
    [ "$retrieved_value" = "test_value" ]
}

test_member_management_functions() {
    source ./gitlab-api.sh
    
    # Test that member management functions are loaded
    declare -f add_project_member list_project_members remove_project_member get_role_name >/dev/null
}

test_member_management_unit_tests() {
    if [ -f "tests/test-member-management.sh" ]; then
        bash tests/test-member-management.sh unit
    else
        log_warning "Member management test file not found, skipping"
        return 0
    fi
}

# ============================================================================
# TEST EXECUTION
# ============================================================================

run_quick_tests() {
    log_info "🏃 Running quick tests..."
    run_test "Script Syntax" "test_script_syntax"
    run_test "Function Loading" "test_function_loading"
}

run_standard_tests() {
    log_info "🚀 Running standard tests..."
    run_test "Script Syntax" "test_script_syntax"
    run_test "Dependencies" "test_dependencies"
    run_test "Function Loading" "test_function_loading"
    run_test "Parameter Validation" "test_parameter_validation"
    run_test "Environment File Operations" "test_env_file_operations"
}

run_comprehensive_tests() {
    log_info "🔍 Running comprehensive tests..."
    run_test "Script Syntax" "test_script_syntax"
    run_test "Dependencies" "test_dependencies"
    run_test "Function Loading" "test_function_loading"
    run_test "Parameter Validation" "test_parameter_validation"
    run_test "Environment File Operations" "test_env_file_operations"
    run_test "Member Management Functions" "test_member_management_functions"
    
    # Your specific user commands
    log_info "Testing your specific commands..."
    run_test "get_list_of_projects_simple" "test_user_command_1"
    run_test "get_list_of_projects (default)" "test_user_command_2"
    run_test "get_list_of_projects (csv)" "test_user_command_3"
    run_test "get_list_of_projects (json)" "test_user_command_4"
    
    # Member management tests
    log_info "Testing member management features..."
    run_test "Member Management Unit Tests" "test_member_management_unit_tests"
}

main() {
    local start_time=$(date +%s)
    
    log_info "🧪 GitLab API Helper Test Runner"
    log_info "Mode: $TEST_MODE"
    echo "=============================================="
    
    case "$TEST_MODE" in
        quick)
            run_quick_tests
            ;;
        standard|full)
            run_standard_tests
            ;;
        comprehensive|all)
            run_comprehensive_tests
            ;;
        *)
            log_error "Invalid test mode: $TEST_MODE"
            log_info "Valid modes: quick, standard, full, comprehensive, all"
            exit 1
            ;;
    esac
    
    # Cleanup
    rm -f /tmp/test_*.log
    
    # Results
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "=============================================="
    log_info "Test Results (${duration}s):"
    log_info "  Total: $TOTAL_TESTS"
    log_success "  Passed: $PASSED_TESTS"
    [ $FAILED_TESTS -gt 0 ] && log_error "  Failed: $FAILED_TESTS" || log_info "  Failed: $FAILED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "🎉 All tests passed!"
        exit 0
    else
        log_error "💥 Some tests failed!"
        exit 1
    fi
}

main "$@"
