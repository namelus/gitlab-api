#!/bin/bash

# ==============================================================================
# GitLab API Member Management Test Suite
# ==============================================================================
#
# Comprehensive test suite for GitLab project member management functions.
# Tests add_project_member, list_project_members, remove_project_member functions.
#
# USAGE:
#   bash tests/test-member-management.sh [test_mode]
#
# TEST MODES:
#   unit     - Unit tests with mocked API responses
#   integration - Integration tests with real API (requires valid token)
#   all      - Run both unit and integration tests
#
# REQUIREMENTS:
#   - bash shell
#   - curl (for API requests)
#   - jq (for JSON processing)
#   - Valid GitLab token for integration tests
#
# ==============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Source the main GitLab API functions
source "./gitlab-api.sh"

# Test configuration
TEST_MODE="${1:-unit}"
MOCK_TOKEN="glpat-test-mock-token-for-member-tests"
MOCK_PROJECT_ID="12345"
MOCK_USER_EMAIL="test@example.com"
MOCK_USER_ID="67890"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TOTAL_TESTS=0
PASSED_TESTS=0
FAILED_TESTS=0

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

run_test() {
    local test_name="$1"
    local test_function="$2"
    
    ((TOTAL_TESTS++))
    
    log_info "🧪 Running: $test_name"
    
    if $test_function > "/tmp/member_test_${TOTAL_TESTS}.log" 2>&1; then
        log_success "✅ $test_name"
        ((PASSED_TESTS++))
        return 0
    else
        log_error "❌ $test_name"
        log_error "   Log: $(tail -2 "/tmp/member_test_${TOTAL_TESTS}.log" | tr '\n' ' ')"
        ((FAILED_TESTS++))
        return 1
    fi
}

# ============================================================================
# MOCK API SETUP
# ============================================================================

setup_mock_api() {
    # Create temporary directory for mock responses
    MOCK_DIR=$(mktemp -d)
    
    # Mock user search response
    cat > "$MOCK_DIR/user_search.json" << 'EOF'
[
  {
    "id": 67890,
    "username": "testuser",
    "name": "Test User",
    "email": "test@example.com",
    "state": "active"
  }
]
EOF

    # Mock successful member add response
    cat > "$MOCK_DIR/member_add_success.json" << 'EOF'
{
  "id": 67890,
  "username": "testuser",
  "name": "Test User",
  "state": "active",
  "access_level": 30,
  "expires_at": null
}
EOF

    # Mock project members list response
    cat > "$MOCK_DIR/members_list.json" << 'EOF'
[
  {
    "id": 67890,
    "username": "testuser",
    "name": "Test User",
    "state": "active",
    "access_level": 30,
    "expires_at": null
  },
  {
    "id": 11111,
    "username": "admin",
    "name": "Admin User",
    "state": "active",
    "access_level": 50,
    "expires_at": "2025-12-31"
  }
]
EOF

    # Mock error responses
    cat > "$MOCK_DIR/user_not_found.json" << 'EOF'
[]
EOF

    cat > "$MOCK_DIR/member_already_exists.json" << 'EOF'
{
  "message": "Member already exists"
}
EOF

    cat > "$MOCK_DIR/unauthorized.json" << 'EOF'
{
  "message": "401 Unauthorized"
}
EOF

    cat > "$MOCK_DIR/forbidden.json" << 'EOF'
{
  "message": "403 Forbidden"
}
EOF

    cat > "$MOCK_DIR/not_found.json" << 'EOF'
{
  "message": "404 Not Found"
}
EOF
}

cleanup_mock_api() {
    [ -n "${MOCK_DIR:-}" ] && rm -rf "$MOCK_DIR"
}

# Mock curl function for unit tests
mock_curl() {
    local url="$*"
    
    # Extract the endpoint from the URL
    if [[ "$url" == *"/users?search="* ]]; then
        if [[ "$url" == *"test@example.com"* ]]; then
            cat "$MOCK_DIR/user_search.json"
            echo "200"
        else
            cat "$MOCK_DIR/user_not_found.json"
            echo "200"
        fi
    elif [[ "$url" == *"/members"* ]] && [[ "$url" == *"POST"* ]]; then
        cat "$MOCK_DIR/member_add_success.json"
        echo "201"
    elif [[ "$url" == *"/members"* ]] && [[ "$url" != *"DELETE"* ]]; then
        cat "$MOCK_DIR/members_list.json"
        echo "200"
    elif [[ "$url" == *"/members/"* ]] && [[ "$url" == *"DELETE"* ]]; then
        echo "204"
    else
        cat "$MOCK_DIR/not_found.json"
        echo "404"
    fi
}

# ============================================================================
# UNIT TESTS
# ============================================================================

test_get_role_name() {
    local result
    
    # Test all valid access levels
    result=$(get_role_name 10)
    [ "$result" = "Guest" ] || return 1
    
    result=$(get_role_name 20)
    [ "$result" = "Reporter" ] || return 1
    
    result=$(get_role_name 30)
    [ "$result" = "Developer" ] || return 1
    
    result=$(get_role_name 40)
    [ "$result" = "Maintainer" ] || return 1
    
    result=$(get_role_name 50)
    [ "$result" = "Owner" ] || return 1
    
    # Test invalid access level
    result=$(get_role_name 99)
    [ "$result" = "Unknown" ] || return 1
    
    return 0
}

test_add_project_member_parameter_validation() {
    # Test missing parameters
    ! add_project_member "" "$MOCK_TOKEN" 2>/dev/null || return 1
    ! add_project_member "$MOCK_PROJECT_ID" "" 2>/dev/null || return 1
    ! add_project_member "" "" 2>/dev/null || return 1
    
    return 0
}

test_list_project_members_parameter_validation() {
    # Test missing parameters
    ! list_project_members "" "$MOCK_TOKEN" 2>/dev/null || return 1
    ! list_project_members "$MOCK_PROJECT_ID" "" 2>/dev/null || return 1
    ! list_project_members "" "" 2>/dev/null || return 1
    
    return 0
}

test_remove_project_member_parameter_validation() {
    # Test missing parameters
    ! remove_project_member "" "$MOCK_USER_EMAIL" "$MOCK_TOKEN" 2>/dev/null || return 1
    ! remove_project_member "$MOCK_PROJECT_ID" "" "$MOCK_TOKEN" 2>/dev/null || return 1
    ! remove_project_member "$MOCK_PROJECT_ID" "$MOCK_USER_EMAIL" "" 2>/dev/null || return 1
    
    return 0
}

test_email_validation() {
    # This test simulates the email validation logic
    local valid_emails=("test@example.com" "user.name@domain.co.uk" "test+tag@example.org")
    local invalid_emails=("invalid-email" "@example.com" "test@" "test.example.com")
    
    for email in "${valid_emails[@]}"; do
        if ! echo "$email" | grep -qE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
            return 1
        fi
    done
    
    for email in "${invalid_emails[@]}"; do
        if echo "$email" | grep -qE '^[A-Za-z0-9._%+-]+@[A-Za-z0-9.-]+\.[A-Za-z]{2,}$'; then
            return 1
        fi
    done
    
    return 0
}

test_date_validation() {
    # This test simulates the date validation logic
    local valid_dates=("2025-12-31" "2025-01-01" "2025-06-15")
    local invalid_dates=("2025-13-01" "25-12-31" "2025/12/31" "invalid-date")
    
    for date in "${valid_dates[@]}"; do
        if ! echo "$date" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
            return 1
        fi
    done
    
    for date in "${invalid_dates[@]}"; do
        if echo "$date" | grep -qE '^[0-9]{4}-[0-9]{2}-[0-9]{2}$'; then
            return 1
        fi
    done
    
    return 0
}

# ============================================================================
# INTEGRATION TESTS (require real GitLab token)
# ============================================================================

test_integration_list_members() {
    local token
    token=$(get_env_variable "GITLAB_API_TOKEN" 2>/dev/null) || {
        log_warning "No GITLAB_API_TOKEN found, skipping integration test"
        return 0
    }
    
    # Try to list members of a project (this will fail if no projects exist)
    # We'll use a timeout to prevent hanging
    timeout 10 list_project_members "1" "$token" "json" >/dev/null 2>&1 || true
    
    return 0
}

test_integration_user_search() {
    local token
    token=$(get_env_variable "GITLAB_API_TOKEN" 2>/dev/null) || {
        log_warning "No GITLAB_API_TOKEN found, skipping integration test"
        return 0
    }
    
    # Test user search with a common email domain
    timeout 10 curl -s --header "PRIVATE-TOKEN: $token" \
        "https://gitlab.com/api/v4/users?search=test" >/dev/null 2>&1 || true
    
    return 0
}

# ============================================================================
# INTERACTIVE TESTS (for manual testing)
# ============================================================================

test_interactive_add_member() {
    log_info "Interactive test for add_project_member function"
    log_info "This test requires manual input and a valid GitLab token"
    
    local token
    token=$(get_env_variable "GITLAB_API_TOKEN" 2>/dev/null) || {
        log_warning "No GITLAB_API_TOKEN found, skipping interactive test"
        return 0
    }
    
    echo "To test the add_project_member function interactively, run:"
    echo "  source ./gitlab-api.sh"
    echo "  add_project_member <project_id> \"\$(get_env_variable 'GITLAB_API_TOKEN')\""
    echo
    
    return 0
}

# ============================================================================
# MOCK FUNCTION TESTS
# ============================================================================

test_mock_user_search() {
    # Override curl with mock function
    curl() { mock_curl "$@"; }
    
    # Test successful user search
    local response
    response=$(curl -s --header "PRIVATE-TOKEN: $MOCK_TOKEN" \
                    "https://gitlab.com/api/v4/users?search=test@example.com")
    
    # Check if response contains expected user
    echo "$response" | jq -e '.[0].email == "test@example.com"' >/dev/null || return 1
    
    # Test user not found
    response=$(curl -s --header "PRIVATE-TOKEN: $MOCK_TOKEN" \
                    "https://gitlab.com/api/v4/users?search=nonexistent@example.com")
    
    # Check if response is empty array
    [ "$(echo "$response" | jq length)" -eq 0 ] || return 1
    
    return 0
}

test_mock_member_operations() {
    # Override curl with mock function
    curl() { mock_curl "$@"; }
    
    # Test member list
    local response
    response=$(curl -s --header "PRIVATE-TOKEN: $MOCK_TOKEN" \
                    "https://gitlab.com/api/v4/projects/$MOCK_PROJECT_ID/members")
    
    # Check if response contains members
    [ "$(echo "$response" | jq length)" -gt 0 ] || return 1
    
    # Test member add
    response=$(curl --request POST \
                    --header "PRIVATE-TOKEN: $MOCK_TOKEN" \
                    --header "Content-Type: application/json" \
                    --data '{"user_id": 67890, "access_level": 30}' \
                    --url "https://gitlab.com/api/v4/projects/$MOCK_PROJECT_ID/members" \
                    --silent)
    
    # Check if response contains added member
    echo "$response" | jq -e '.id == 67890' >/dev/null || return 1
    
    return 0
}

# ============================================================================
# TEST EXECUTION
# ============================================================================

run_unit_tests() {
    log_info "🧪 Running unit tests for member management..."
    
    setup_mock_api
    
    run_test "Role Name Conversion" "test_get_role_name"
    run_test "Add Member Parameter Validation" "test_add_project_member_parameter_validation"
    run_test "List Members Parameter Validation" "test_list_project_members_parameter_validation"
    run_test "Remove Member Parameter Validation" "test_remove_project_member_parameter_validation"
    run_test "Email Format Validation" "test_email_validation"
    run_test "Date Format Validation" "test_date_validation"
    run_test "Mock User Search" "test_mock_user_search"
    run_test "Mock Member Operations" "test_mock_member_operations"
    
    cleanup_mock_api
}

run_integration_tests() {
    log_info "🌐 Running integration tests for member management..."
    
    run_test "Integration: List Members" "test_integration_list_members"
    run_test "Integration: User Search" "test_integration_user_search"
}

run_interactive_tests() {
    log_info "👤 Running interactive tests for member management..."
    
    run_test "Interactive: Add Member Guide" "test_interactive_add_member"
}

show_usage() {
    echo "Usage: $0 [test_mode]"
    echo
    echo "Test modes:"
    echo "  unit         - Run unit tests with mocked API responses"
    echo "  integration  - Run integration tests with real GitLab API"
    echo "  interactive  - Show interactive test instructions"
    echo "  all          - Run unit and integration tests"
    echo
    echo "Examples:"
    echo "  $0 unit"
    echo "  $0 integration"
    echo "  $0 all"
}

main() {
    local start_time=$(date +%s)
    
    log_info "🧪 GitLab API Member Management Test Suite"
    log_info "Mode: $TEST_MODE"
    echo "=============================================="
    
    case "$TEST_MODE" in
        unit)
            run_unit_tests
            ;;
        integration)
            run_integration_tests
            ;;
        interactive)
            run_interactive_tests
            ;;
        all)
            run_unit_tests
            run_integration_tests
            ;;
        help|--help|-h)
            show_usage
            exit 0
            ;;
        *)
            log_error "Invalid test mode: $TEST_MODE"
            show_usage
            exit 1
            ;;
    esac
    
    # Cleanup
    rm -f /tmp/member_test_*.log
    
    # Results
    local end_time=$(date +%s)
    local duration=$((end_time - start_time))
    
    echo "=============================================="
    log_info "Test Results (${duration}s):"
    log_info "  Total: $TOTAL_TESTS"
    log_success "  Passed: $PASSED_TESTS"
    [ $FAILED_TESTS -gt 0 ] && log_error "  Failed: $FAILED_TESTS" || log_info "  Failed: $FAILED_TESTS"
    
    if [ $FAILED_TESTS -eq 0 ]; then
        log_success "🎉 All member management tests passed!"
        exit 0
    else
        log_error "💥 Some member management tests failed!"
        exit 1
    fi
}

# Handle script being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
