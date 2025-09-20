#!/bin/bash

# ==============================================================================
# Unit Tests for Git Repository Creation Functions
# ==============================================================================
#
# This script contains comprehensive unit tests for all Git repository creation
# functions added to gitlab-api.sh. Tests cover both success and failure cases
# with proper mocking and isolation.
#
# USAGE:
#   bash tests/test-git-repository-creation.sh [test_name]
#
# TEST CATEGORIES:
#   - detect_active_gitlab_token
#   - detect_current_project
#   - create_gitlab_project_with_options
#   - setup_local_git_repository
#   - push_to_gitlab
#   - create_gitlab_repository_from_folder (integration)
#
# ==============================================================================

set -euo pipefail

# Test configuration
TEST_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$TEST_DIR")"
SCRIPT_DIR="$PROJECT_ROOT"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Test counters
TESTS_RUN=0
TESTS_PASSED=0
TESTS_FAILED=0

# Test output functions
test_log() {
    echo -e "${BLUE}[TEST]${NC} $1"
}

test_success() {
    echo -e "${GREEN}[PASS]${NC} $1"
    ((TESTS_PASSED++))
}

test_failure() {
    echo -e "${RED}[FAIL]${NC} $1"
    ((TESTS_FAILED++))
}

test_info() {
    echo -e "${YELLOW}[INFO]${NC} $1"
}

# Load the functions under test
if [ -f "$SCRIPT_DIR/gitlab-api.sh" ]; then
    source "$SCRIPT_DIR/gitlab-api.sh"
else
    echo "Error: gitlab-api.sh not found at $SCRIPT_DIR/gitlab-api.sh" >&2
    exit 1
fi

# Load cache functions if available
if [ -f "$SCRIPT_DIR/gitlab-project-cache.sh" ]; then
    source "$SCRIPT_DIR/gitlab-project-cache.sh"
fi

# ==============================================================================
# TEST UTILITIES
# ==============================================================================

# Create a temporary directory for testing
create_test_dir() {
    local test_name="$1"
    local temp_dir
    temp_dir=$(mktemp -d -t "gitlab-test-$test_name-XXXXXX")
    echo "$temp_dir"
}

# Clean up test directory
cleanup_test_dir() {
    local test_dir="$1"
    if [ -d "$test_dir" ]; then
        rm -rf "$test_dir"
    fi
}

# Mock git commands
mock_git() {
    local mock_dir="$1"
    local git_commands="$2"
    
    # Create a mock git script
    cat > "$mock_dir/git" << EOF
#!/bin/bash
case "\$1" in
    --version)
        echo "git version 2.30.0"
        ;;
    rev-parse)
        if [ "\$2" = "--git-dir" ]; then
            if [ -d ".git" ]; then
                echo ".git"
                exit 0
            else
                exit 1
            fi
        fi
        ;;
    branch)
        if [ "\$2" = "--show-current" ]; then
            echo "\${GIT_BRANCH:-main}"
        fi
        ;;
    init)
        mkdir -p .git
        echo "Initialized empty Git repository"
        ;;
    remote)
        case "\$2" in
            add)
                echo "origin \$4" > .git/remote_origin
                echo "Remote 'origin' added"
                ;;
            get-url)
                if [ -f ".git/remote_origin" ]; then
                    cat .git/remote_origin
                else
                    exit 1
                fi
                ;;
            set-url)
                echo "origin \$4" > .git/remote_origin
                echo "Remote 'origin' updated"
                ;;
        esac
        ;;
    config)
        case "\$2" in
            --local)
                echo "\$4" > ".git/config_\$3"
                ;;
        esac
        ;;
    add)
        echo "Added files to staging"
        ;;
    commit)
        echo "Committed changes"
        ;;
    push)
        if [ "\$3" = "origin" ]; then
            echo "Pushed to origin/\$4"
        else
            exit 1
        fi
        ;;
    *)
        echo "Mock git: \$*"
        ;;
esac
EOF
    chmod +x "$mock_dir/git"
}

# Mock curl for API calls
mock_curl() {
    local mock_dir="$1"
    local response_code="$2"
    local response_body="$3"
    
    cat > "$mock_dir/curl" << EOF
#!/bin/bash
# Mock curl that returns specified response
echo "$response_body"
echo -n "$response_code"
EOF
    chmod +x "$mock_dir/curl"
}

# Mock jq for JSON processing
mock_jq() {
    local mock_dir="$1"
    
    cat > "$mock_dir/jq" << EOF
#!/bin/bash
# Simple mock jq that handles basic operations
case "\$1" in
    -n)
        # Handle jq -n with --arg
        if [ "\$2" = "--arg" ] && [ "\$3" = "name" ]; then
            echo "{\"name\": \"\$4\"}"
        elif [ "\$2" = "--arg" ] && [ "\$3" = "description" ]; then
            echo "{\"description\": \"\$4\"}"
        elif [ "\$2" = "--arg" ] && [ "\$3" = "visibility" ]; then
            echo "{\"visibility\": \"\$4\"}"
        fi
        ;;
    -r)
        case "\$2" in
            '.id')
                echo "12345"
                ;;
            '.web_url')
                echo "https://gitlab.com/testuser/testproject"
                ;;
            '.ssh_url_to_repo')
                echo "git@gitlab.com:testuser/testproject.git"
                ;;
            '.name')
                echo "Test Project"
                ;;
            '.path_with_namespace')
                echo "testuser/testproject"
                ;;
        esac
        ;;
    '.')
        echo "$response_body"
        ;;
    *)
        echo "Mock jq: \$*"
        ;;
esac
EOF
    chmod +x "$mock_dir/jq"
}

# Set up test environment
setup_test_env() {
    local test_dir="$1"
    local git_branch="${2:-main}"
    
    # Set environment variables
    export GIT_BRANCH="$git_branch"
    export PATH="$test_dir:$PATH"
    
    # Create mock .env file
    cat > "$test_dir/.env" << 'EOF'
GITLAB_API_TOKEN="glpat-test-token-12345"
GITLAB_DEV_TOKEN="glpat-dev-token-67890"
GITLAB_PROD_TOKEN="glpat-prod-token-abcdef"
OTHER_TOKEN="not-a-gitlab-token"
EOF
    
    # Create mock cache file
    mkdir -p "$test_dir/.local/share/gitlab-api-helper"
    cat > "$test_dir/.local/share/gitlab-api-helper/projects-cache.json" << 'EOF'
[
  {
    "id": 12345,
    "name": "Test Project",
    "path_with_namespace": "testuser/testproject",
    "web_url": "https://gitlab.com/testuser/testproject",
    "ssh_url_to_repo": "git@gitlab.com:testuser/testproject.git"
  }
]
EOF
    
    # Set HOME to test directory
    export HOME="$test_dir"
}

# ==============================================================================
# TEST CASES
# ==============================================================================

test_detect_active_gitlab_token() {
    test_log "Testing detect_active_gitlab_token function"
    
    local test_dir
    test_dir=$(create_test_dir "detect_token")
    
    # Test 1: Production branch should select PROD token
    test_info "Test 1: Production branch selection"
    setup_test_env "$test_dir" "main"
    local result
    if result=$(detect_active_gitlab_token 2>/dev/null); then
        if [ "$result" = "GITLAB_PROD_TOKEN" ]; then
            test_success "Production branch correctly selected PROD token"
        else
            test_failure "Production branch selected wrong token: $result"
        fi
    else
        test_failure "Token detection failed for production branch"
    fi
    
    # Test 2: Development branch should select DEV token
    test_info "Test 2: Development branch selection"
    setup_test_env "$test_dir" "develop"
    if result=$(detect_active_gitlab_token 2>/dev/null); then
        if [ "$result" = "GITLAB_DEV_TOKEN" ]; then
            test_success "Development branch correctly selected DEV token"
        else
            test_failure "Development branch selected wrong token: $result"
        fi
    else
        test_failure "Token detection failed for development branch"
    fi
    
    # Test 3: Unknown branch should fall back to API token
    test_info "Test 3: Unknown branch fallback"
    setup_test_env "$test_dir" "feature-branch"
    if result=$(detect_active_gitlab_token 2>/dev/null); then
        if [ "$result" = "GITLAB_API_TOKEN" ]; then
            test_success "Unknown branch correctly fell back to API token"
        else
            test_failure "Unknown branch selected wrong token: $result"
        fi
    else
        test_failure "Token detection failed for unknown branch"
    fi
    
    # Test 4: No .env file should fail
    test_info "Test 4: Missing .env file"
    rm -f "$test_dir/.env"
    if detect_active_gitlab_token >/dev/null 2>&1; then
        test_failure "Should fail when .env file is missing"
    else
        test_success "Correctly failed when .env file is missing"
    fi
    
    cleanup_test_dir "$test_dir"
}

test_detect_current_project() {
    test_log "Testing detect_current_project function"
    
    local test_dir
    test_dir=$(create_test_dir "detect_project")
    
    # Test 1: Valid GitLab repository
    test_info "Test 1: Valid GitLab repository"
    setup_test_env "$test_dir"
    mock_git "$test_dir"
    
    # Create a mock git repository
    mkdir -p "$test_dir/.git"
    echo "git@gitlab.com:testuser/testproject.git" > "$test_dir/.git/remote_origin"
    
    cd "$test_dir"
    if result=$(detect_current_project 2>/dev/null); then
        if [ "$result" = "12345" ]; then
            test_success "Correctly detected project ID from cache"
        else
            test_failure "Detected wrong project ID: $result"
        fi
    else
        test_failure "Project detection failed for valid repository"
    fi
    
    # Test 2: Not in git repository
    test_info "Test 2: Not in git repository"
    rm -rf "$test_dir/.git"
    if detect_current_project >/dev/null 2>&1; then
        test_failure "Should fail when not in git repository"
    else
        test_success "Correctly failed when not in git repository"
    fi
    
    # Test 3: No origin remote
    test_info "Test 3: No origin remote"
    mkdir -p "$test_dir/.git"
    if detect_current_project >/dev/null 2>&1; then
        test_failure "Should fail when no origin remote exists"
    else
        test_success "Correctly failed when no origin remote exists"
    fi
    
    cleanup_test_dir "$test_dir"
}

test_create_gitlab_project_with_options() {
    test_log "Testing create_gitlab_project_with_options function"
    
    local test_dir
    test_dir=$(create_test_dir "create_project")
    
    # Test 1: Successful project creation
    test_info "Test 1: Successful project creation"
    setup_test_env "$test_dir"
    mock_curl "$test_dir" "201" '{"id": 12345, "name": "Test Project", "web_url": "https://gitlab.com/testuser/testproject", "ssh_url_to_repo": "git@gitlab.com:testuser/testproject.git"}'
    mock_jq "$test_dir"
    
    if result=$(create_gitlab_project_with_options "test-project" "glpat-test-token" "Test description" "private" 2>/dev/null); then
        test_success "Project creation succeeded"
    else
        test_failure "Project creation failed: $result"
    fi
    
    # Test 2: Project already exists (409)
    test_info "Test 2: Project already exists"
    mock_curl "$test_dir" "409" '{"message": "Project already exists"}'
    
    if create_gitlab_project_with_options "test-project" "glpat-test-token" >/dev/null 2>&1; then
        test_failure "Should fail when project already exists"
    else
        test_success "Correctly failed when project already exists"
    fi
    
    # Test 3: Invalid visibility level
    test_info "Test 3: Invalid visibility level"
    if create_gitlab_project_with_options "test-project" "glpat-test-token" "Test" "invalid" >/dev/null 2>&1; then
        test_failure "Should fail with invalid visibility level"
    else
        test_success "Correctly failed with invalid visibility level"
    fi
    
    # Test 4: Missing parameters
    test_info "Test 4: Missing parameters"
    if create_gitlab_project_with_options "" "glpat-test-token" >/dev/null 2>&1; then
        test_failure "Should fail with missing project name"
    else
        test_success "Correctly failed with missing project name"
    fi
    
    cleanup_test_dir "$test_dir"
}

test_setup_local_git_repository() {
    test_log "Testing setup_local_git_repository function"
    
    local test_dir
    test_dir=$(create_test_dir "setup_git")
    
    # Test 1: Successful git setup
    test_info "Test 1: Successful git setup"
    setup_test_env "$test_dir"
    mock_git "$test_dir"
    
    cd "$test_dir"
    if setup_local_git_repository "git@gitlab.com:testuser/testproject.git" "main" >/dev/null 2>&1; then
        test_success "Git repository setup succeeded"
    else
        test_failure "Git repository setup failed"
    fi
    
    # Test 2: Git not available
    test_info "Test 2: Git not available"
    export PATH="/nonexistent:$PATH"
    if setup_local_git_repository "git@gitlab.com:testuser/testproject.git" >/dev/null 2>&1; then
        test_failure "Should fail when git is not available"
    else
        test_success "Correctly failed when git is not available"
    fi
    
    # Test 3: Missing SSH URL
    test_info "Test 3: Missing SSH URL"
    setup_test_env "$test_dir"
    mock_git "$test_dir"
    if setup_local_git_repository "" >/dev/null 2>&1; then
        test_failure "Should fail with missing SSH URL"
    else
        test_success "Correctly failed with missing SSH URL"
    fi
    
    cleanup_test_dir "$test_dir"
}

test_push_to_gitlab() {
    test_log "Testing push_to_gitlab function"
    
    local test_dir
    test_dir=$(create_test_dir "push_git")
    
    # Test 1: Successful push
    test_info "Test 1: Successful push"
    setup_test_env "$test_dir"
    mock_git "$test_dir"
    
    # Create a mock git repository
    mkdir -p "$test_dir/.git"
    echo "git@gitlab.com:testuser/testproject.git" > "$test_dir/.git/remote_origin"
    
    cd "$test_dir"
    if push_to_gitlab "main" >/dev/null 2>&1; then
        test_success "Git push succeeded"
    else
        test_failure "Git push failed"
    fi
    
    # Test 2: Not in git repository
    test_info "Test 2: Not in git repository"
    rm -rf "$test_dir/.git"
    if push_to_gitlab >/dev/null 2>&1; then
        test_failure "Should fail when not in git repository"
    else
        test_success "Correctly failed when not in git repository"
    fi
    
    # Test 3: No origin remote
    test_info "Test 3: No origin remote"
    mkdir -p "$test_dir/.git"
    if push_to_gitlab >/dev/null 2>&1; then
        test_failure "Should fail when no origin remote exists"
    else
        test_success "Correctly failed when no origin remote exists"
    fi
    
    cleanup_test_dir "$test_dir"
}

test_create_gitlab_repository_from_folder() {
    test_log "Testing create_gitlab_repository_from_folder function (integration test)"
    
    local test_dir
    test_dir=$(create_test_dir "create_repo")
    
    # Test 1: Successful repository creation
    test_info "Test 1: Successful repository creation"
    setup_test_env "$test_dir"
    mock_git "$test_dir"
    mock_curl "$test_dir" "201" '{"id": 12345, "name": "Test Project", "web_url": "https://gitlab.com/testuser/testproject", "ssh_url_to_repo": "git@gitlab.com:testuser/testproject.git"}'
    mock_jq "$test_dir"
    
    # Create some test files
    echo "Test content" > "$test_dir/test.txt"
    echo "Another file" > "$test_dir/README.md"
    
    cd "$test_dir"
    if create_gitlab_repository_from_folder "test-project" "glpat-test-token" "Test description" "private" "main" >/dev/null 2>&1; then
        test_success "Repository creation workflow succeeded"
    else
        test_failure "Repository creation workflow failed"
    fi
    
    # Test 2: Missing project name
    test_info "Test 2: Missing project name"
    if create_gitlab_repository_from_folder "" >/dev/null 2>&1; then
        test_failure "Should fail with missing project name"
    else
        test_success "Correctly failed with missing project name"
    fi
    
    # Test 3: Project already exists
    test_info "Test 3: Project already exists"
    # Mock check_project_exists to return true
    check_project_exists() {
        return 0
    }
    
    if create_gitlab_repository_from_folder "existing-project" "glpat-test-token" >/dev/null 2>&1; then
        test_failure "Should fail when project already exists"
    else
        test_success "Correctly failed when project already exists"
    fi
    
    cleanup_test_dir "$test_dir"
}

# ==============================================================================
# TEST RUNNER
# ==============================================================================

run_all_tests() {
    echo "🧪 Running Git Repository Creation Tests"
    echo "========================================"
    echo
    
    test_detect_active_gitlab_token
    test_detect_current_project
    test_create_gitlab_project_with_options
    test_setup_local_git_repository
    test_push_to_gitlab
    test_create_gitlab_repository_from_folder
    
    echo
    echo "📊 Test Results"
    echo "==============="
    echo "Total tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some tests failed!${NC}"
        return 1
    fi
}

run_specific_test() {
    local test_name="$1"
    
    case "$test_name" in
        "detect_token")
            test_detect_active_gitlab_token
            ;;
        "detect_project")
            test_detect_current_project
            ;;
        "create_project")
            test_create_gitlab_project_with_options
            ;;
        "setup_git")
            test_setup_local_git_repository
            ;;
        "push_git")
            test_push_to_gitlab
            ;;
        "create_repo")
            test_create_gitlab_repository_from_folder
            ;;
        *)
            echo "Unknown test: $test_name" >&2
            echo "Available tests: detect_token, detect_project, create_project, setup_git, push_git, create_repo" >&2
            return 1
            ;;
    esac
}

# ==============================================================================
# MAIN EXECUTION
# ==============================================================================

main() {
    local test_name="${1:-all}"
    
    if [ "$test_name" = "all" ]; then
        run_all_tests
    else
        run_specific_test "$test_name"
    fi
}

# Handle script being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
