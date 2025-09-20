#!/bin/bash

# ==============================================================================
# Integration Tests for Complete GitLab Repository Creation Workflow
# ==============================================================================
#
# This script contains integration tests that verify the complete workflow
# from creating a GitLab repository from a local folder to pushing code.
# These tests simulate real-world scenarios with proper mocking.
#
# USAGE:
#   bash tests/test-integration-workflow.sh [test_name]
#
# TEST SCENARIOS:
#   - Complete repository creation workflow
#   - Error handling and recovery
#   - Token detection and project detection
#   - Git operations integration
#   - Cache integration
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
CYAN='\033[0;36m'
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
# INTEGRATION TEST UTILITIES
# ==============================================================================

# Create a comprehensive test environment
setup_integration_test_env() {
    local test_name="$1"
    local test_dir
    test_dir=$(mktemp -d -t "gitlab-integration-test-$test_name-XXXXXX")
    
    # Set up environment
    export HOME="$test_dir"
    export GIT_BRANCH="${2:-main}"
    
    # Create mock .env file with multiple tokens
    cat > "$test_dir/.env" << 'EOF'
GITLAB_API_TOKEN="glpat-api-token-12345"
GITLAB_DEV_TOKEN="glpat-dev-token-67890"
GITLAB_PROD_TOKEN="glpat-prod-token-abcdef"
GITLAB_CI_TOKEN="glpat-ci-token-xyz789"
EOF
    
    # Create mock cache directory and file
    mkdir -p "$test_dir/.local/share/gitlab-api-helper"
    cat > "$test_dir/.local/share/gitlab-api-helper/projects-cache.json" << 'EOF'
[
  {
    "id": 12345,
    "name": "Existing Project",
    "path_with_namespace": "testuser/existing-project",
    "web_url": "https://gitlab.com/testuser/existing-project",
    "ssh_url_to_repo": "git@gitlab.com:testuser/existing-project.git",
    "last_activity_at": "2025-01-15T10:30:00.000Z"
  },
  {
    "id": 67890,
    "name": "Another Project",
    "path_with_namespace": "testuser/another-project",
    "web_url": "https://gitlab.com/testuser/another-project",
    "ssh_url_to_repo": "git@gitlab.com:testuser/another-project.git",
    "last_activity_at": "2025-01-14T15:45:00.000Z"
  }
]
EOF
    
    # Create mock cache metadata
    cat > "$test_dir/.local/share/gitlab-api-helper/cache-metadata.json" << 'EOF'
{
  "cache_timestamp": 1737028800,
  "version": "1.0",
  "project_count": 2
}
EOF
    
    echo "$test_dir"
}

# Create comprehensive mock tools
create_mock_tools() {
    local test_dir="$1"
    
    # Mock git with comprehensive functionality
    cat > "$test_dir/git" << 'EOF'
#!/bin/bash
# Comprehensive mock git implementation

case "$1" in
    --version)
        echo "git version 2.30.0"
        ;;
    rev-parse)
        if [ "$2" = "--git-dir" ]; then
            if [ -d ".git" ]; then
                echo ".git"
                exit 0
            else
                exit 1
            fi
        elif [ "$2" = "HEAD" ]; then
            if [ -f ".git/HEAD" ]; then
                cat .git/HEAD
            else
                exit 1
            fi
        fi
        ;;
    branch)
        if [ "$2" = "--show-current" ]; then
            echo "${GIT_BRANCH:-main}"
        fi
        ;;
    init)
        mkdir -p .git
        echo "Initialized empty Git repository in $(pwd)/.git"
        ;;
    remote)
        case "$2" in
            add)
                echo "origin $4" > .git/remote_origin
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
                echo "origin $4" > .git/remote_origin
                echo "Remote 'origin' updated"
                ;;
        esac
        ;;
    config)
        case "$2" in
            --local)
                echo "$4" > ".git/config_$3"
                ;;
        esac
        ;;
    add)
        echo "Added files to staging area"
        ;;
    commit)
        local commit_msg="$2"
        echo "Committed changes: $commit_msg"
        echo "ref: refs/heads/${GIT_BRANCH:-main}" > .git/HEAD
        ;;
    push)
        if [ "$3" = "origin" ]; then
            echo "Pushed to origin/${4:-main}"
            echo "Branch '${4:-main}' set up to track remote branch '${4:-main}' from 'origin'"
        else
            echo "Error: failed to push some refs" >&2
            exit 1
        fi
        ;;
    status)
        echo "On branch ${GIT_BRANCH:-main}"
        echo "nothing to commit, working tree clean"
        ;;
    log)
        echo "commit abc123def456"
        echo "Author: Test User <test@example.com>"
        echo "Date: $(date)"
        echo ""
        echo "    Initial commit"
        ;;
    *)
        echo "Mock git: $*"
        ;;
esac
EOF
    chmod +x "$test_dir/git"
    
    # Mock curl with different response scenarios
    cat > "$test_dir/curl" << 'EOF'
#!/bin/bash
# Mock curl that can simulate different API responses

# Check if this is a project creation request
if echo "$*" | grep -q "api/v4/projects" && echo "$*" | grep -q "POST"; then
    # Check if project already exists (simulate by checking project name)
    if echo "$*" | grep -q '"name": "existing-project"'; then
        echo '{"message": "Project already exists"}'
        echo -n "409"
    else
        # Return successful project creation
        echo '{
            "id": 99999,
            "name": "Test Project",
            "path": "test-project",
            "path_with_namespace": "testuser/test-project",
            "web_url": "https://gitlab.com/testuser/test-project",
            "ssh_url_to_repo": "git@gitlab.com:testuser/test-project.git",
            "http_url_to_repo": "https://gitlab.com/testuser/test-project.git",
            "visibility": "private",
            "created_at": "2025-01-15T12:00:00.000Z"
        }'
        echo -n "201"
    fi
else
    # Default response for other requests
    echo '{"message": "Mock response"}'
    echo -n "200"
fi
EOF
    chmod +x "$test_dir/curl"
    
    # Mock jq with comprehensive JSON processing
    cat > "$test_dir/jq" << 'EOF'
#!/bin/bash
# Comprehensive mock jq implementation

case "$1" in
    -n)
        # Handle jq -n with --arg parameters
        if [ "$2" = "--arg" ] && [ "$3" = "name" ] && [ "$4" = "--arg" ] && [ "$5" = "description" ] && [ "$6" = "--arg" ] && [ "$7" = "visibility" ]; then
            echo "{\"name\": \"$8\", \"description\": \"$9\", \"visibility\": \"${10}\"}"
        fi
        ;;
    -r)
        case "$2" in
            '.id')
                echo "99999"
                ;;
            '.name')
                echo "Test Project"
                ;;
            '.web_url')
                echo "https://gitlab.com/testuser/test-project"
                ;;
            '.ssh_url_to_repo')
                echo "git@gitlab.com:testuser/test-project.git"
                ;;
            '.path_with_namespace')
                echo "testuser/test-project"
                ;;
            '.message')
                echo "Project already exists"
                ;;
        esac
        ;;
    '.')
        # Return the input as-is for basic processing
        cat
        ;;
    *)
        echo "Mock jq: $*"
        ;;
esac
EOF
    chmod +x "$test_dir/jit"
}

# Clean up test environment
cleanup_integration_test() {
    local test_dir="$1"
    if [ -d "$test_dir" ]; then
        rm -rf "$test_dir"
    fi
}

# ==============================================================================
# INTEGRATION TEST CASES
# ==============================================================================

test_complete_repository_creation_workflow() {
    test_log "Testing complete repository creation workflow"
    
    local test_dir
    test_dir=$(setup_integration_test_env "complete_workflow" "main")
    create_mock_tools "$test_dir"
    
    # Set up PATH to use mock tools
    export PATH="$test_dir:$PATH"
    
    # Create test project files
    echo "Test project content" > "$test_dir/README.md"
    echo "console.log('Hello World');" > "$test_dir/app.js"
    echo "package.json" > "$test_dir/package.json"
    
    cd "$test_dir"
    
    test_info "Test 1: Complete workflow with new project"
    if create_gitlab_repository_from_folder "new-test-project" "glpat-api-token-12345" "Test project description" "private" "main" >/dev/null 2>&1; then
        test_success "Complete workflow succeeded for new project"
    else
        test_failure "Complete workflow failed for new project"
    fi
    
    # Verify git repository was created
    if [ -d ".git" ]; then
        test_success "Git repository was initialized"
    else
        test_failure "Git repository was not initialized"
    fi
    
    # Verify remote was added
    if [ -f ".git/remote_origin" ] && grep -q "git@gitlab.com:testuser/test-project.git" .git/remote_origin; then
        test_success "Git remote was configured correctly"
    else
        test_failure "Git remote was not configured correctly"
    fi
    
    cleanup_integration_test "$test_dir"
}

test_error_handling_and_recovery() {
    test_log "Testing error handling and recovery"
    
    local test_dir
    test_dir=$(setup_integration_test_env "error_handling" "main")
    create_mock_tools "$test_dir"
    
    export PATH="$test_dir:$PATH"
    
    cd "$test_dir"
    
    test_info "Test 1: Project already exists error"
    if create_gitlab_repository_from_folder "existing-project" "glpat-api-token-12345" >/dev/null 2>&1; then
        test_failure "Should fail when project already exists"
    else
        test_success "Correctly failed when project already exists"
    fi
    
    test_info "Test 2: Missing project name error"
    if create_gitlab_repository_from_folder "" "glpat-api-token-12345" >/dev/null 2>&1; then
        test_failure "Should fail with missing project name"
    else
        test_success "Correctly failed with missing project name"
    fi
    
    test_info "Test 3: Invalid visibility level error"
    if create_gitlab_repository_from_folder "test-project" "glpat-api-token-12345" "Test" "invalid-visibility" >/dev/null 2>&1; then
        test_failure "Should fail with invalid visibility level"
    else
        test_success "Correctly failed with invalid visibility level"
    fi
    
    cleanup_integration_test "$test_dir"
}

test_token_detection_integration() {
    test_log "Testing token detection integration"
    
    local test_dir
    test_dir=$(setup_integration_test_env "token_detection" "develop")
    create_mock_tools "$test_dir"
    
    export PATH="$test_dir:$PATH"
    
    cd "$test_dir"
    
    test_info "Test 1: Development branch token detection"
    local detected_token
    if detected_token=$(detect_active_gitlab_token 2>/dev/null); then
        if [ "$detected_token" = "GITLAB_DEV_TOKEN" ]; then
            test_success "Correctly detected DEV token for develop branch"
        else
            test_failure "Wrong token detected for develop branch: $detected_token"
        fi
    else
        test_failure "Token detection failed for develop branch"
    fi
    
    # Test production branch
    export GIT_BRANCH="main"
    if detected_token=$(detect_active_gitlab_token 2>/dev/null); then
        if [ "$detected_token" = "GITLAB_PROD_TOKEN" ]; then
            test_success "Correctly detected PROD token for main branch"
        else
            test_failure "Wrong token detected for main branch: $detected_token"
        fi
    else
        test_failure "Token detection failed for main branch"
    fi
    
    cleanup_integration_test "$test_dir"
}

test_project_detection_integration() {
    test_log "Testing project detection integration"
    
    local test_dir
    test_dir=$(setup_integration_test_env "project_detection" "main")
    create_mock_tools "$test_dir"
    
    export PATH="$test_dir:$PATH"
    
    # Create a mock git repository with GitLab remote
    mkdir -p "$test_dir/.git"
    echo "git@gitlab.com:testuser/existing-project.git" > "$test_dir/.git/remote_origin"
    
    cd "$test_dir"
    
    test_info "Test 1: Project detection with cache lookup"
    local detected_project
    if detected_project=$(detect_current_project 2>/dev/null); then
        if [ "$detected_project" = "12345" ]; then
            test_success "Correctly detected project ID from cache"
        else
            test_failure "Wrong project ID detected: $detected_project"
        fi
    else
        test_failure "Project detection failed"
    fi
    
    cleanup_integration_test "$test_dir"
}

test_git_operations_integration() {
    test_log "Testing Git operations integration"
    
    local test_dir
    test_dir=$(setup_integration_test_env "git_operations" "main")
    create_mock_tools "$test_dir"
    
    export PATH="$test_dir:$PATH"
    
    # Create test files
    echo "Test content" > "$test_dir/test.txt"
    echo "Another file" > "$test_dir/README.md"
    
    cd "$test_dir"
    
    test_info "Test 1: Git repository setup"
    if setup_local_git_repository "git@gitlab.com:testuser/test-project.git" "main" >/dev/null 2>&1; then
        test_success "Git repository setup succeeded"
    else
        test_failure "Git repository setup failed"
    fi
    
    # Verify git repository was created
    if [ -d ".git" ]; then
        test_success "Git repository was initialized"
    else
        test_failure "Git repository was not initialized"
    fi
    
    # Verify remote was configured
    if [ -f ".git/remote_origin" ] && grep -q "git@gitlab.com:testuser/test-project.git" .git/remote_origin; then
        test_success "Git remote was configured"
    else
        test_failure "Git remote was not configured"
    fi
    
    test_info "Test 2: Git push operation"
    if push_to_gitlab "main" >/dev/null 2>&1; then
        test_success "Git push operation succeeded"
    else
        test_failure "Git push operation failed"
    fi
    
    cleanup_integration_test "$test_dir"
}

test_cache_integration() {
    test_log "Testing cache integration"
    
    local test_dir
    test_dir=$(setup_integration_test_env "cache_integration" "main")
    create_mock_tools "$test_dir"
    
    export PATH="$test_dir:$PATH"
    
    cd "$test_dir"
    
    test_info "Test 1: Cache file detection"
    if [ -f "$HOME/.local/share/gitlab-api-helper/projects-cache.json" ]; then
        test_success "Cache file exists"
    else
        test_failure "Cache file not found"
    fi
    
    test_info "Test 2: Project existence check"
    if check_project_exists "existing-project" >/dev/null 2>&1; then
        test_success "Existing project correctly detected in cache"
    else
        test_failure "Existing project not detected in cache"
    fi
    
    if check_project_exists "nonexistent-project" >/dev/null 2>&1; then
        test_failure "Nonexistent project incorrectly detected in cache"
    else
        test_success "Nonexistent project correctly not found in cache"
    fi
    
    cleanup_integration_test "$test_dir"
}

test_end_to_end_workflow() {
    test_log "Testing end-to-end workflow with all components"
    
    local test_dir
    test_dir=$(setup_integration_test_env "end_to_end" "feature-branch")
    create_mock_tools "$test_dir"
    
    export PATH="$test_dir:$PATH"
    
    # Create a realistic project structure
    mkdir -p "$test_dir/src" "$test_dir/docs"
    echo "# My Awesome Project" > "$test_dir/README.md"
    echo "console.log('Hello World');" > "$test_dir/src/app.js"
    echo '{"name": "my-project", "version": "1.0.0"}' > "$test_dir/package.json"
    echo "# Documentation" > "$test_dir/docs/README.md"
    
    cd "$test_dir"
    
    test_info "Test 1: Complete end-to-end workflow"
    
    # Step 1: Token detection
    local token
    if ! token=$(detect_active_gitlab_token 2>/dev/null); then
        test_failure "Token detection failed in end-to-end test"
        cleanup_integration_test "$test_dir"
        return 1
    fi
    
    # Step 2: Create repository
    if ! create_gitlab_repository_from_folder "my-awesome-project" "$token" "My awesome project description" "private" "main" >/dev/null 2>&1; then
        test_failure "Repository creation failed in end-to-end test"
        cleanup_integration_test "$test_dir"
        return 1
    fi
    
    # Step 3: Verify all components
    local all_good=true
    
    # Check git repository
    if [ ! -d ".git" ]; then
        test_failure "Git repository not created in end-to-end test"
        all_good=false
    fi
    
    # Check remote configuration
    if [ ! -f ".git/remote_origin" ] || ! grep -q "git@gitlab.com:testuser/my-awesome-project.git" .git/remote_origin; then
        test_failure "Git remote not configured correctly in end-to-end test"
        all_good=false
    fi
    
    # Check project files are still there
    if [ ! -f "README.md" ] || [ ! -f "src/app.js" ] || [ ! -f "package.json" ]; then
        test_failure "Project files missing in end-to-end test"
        all_good=false
    fi
    
    if [ "$all_good" = true ]; then
        test_success "End-to-end workflow completed successfully"
    else
        test_failure "End-to-end workflow had issues"
    fi
    
    cleanup_integration_test "$test_dir"
}

# ==============================================================================
# TEST RUNNER
# ==============================================================================

run_all_integration_tests() {
    echo "🧪 Running GitLab Repository Creation Integration Tests"
    echo "======================================================="
    echo
    
    test_complete_repository_creation_workflow
    test_error_handling_and_recovery
    test_token_detection_integration
    test_project_detection_integration
    test_git_operations_integration
    test_cache_integration
    test_end_to_end_workflow
    
    echo
    echo "📊 Integration Test Results"
    echo "=========================="
    echo "Total tests run: $TESTS_RUN"
    echo -e "Passed: ${GREEN}$TESTS_PASSED${NC}"
    echo -e "Failed: ${RED}$TESTS_FAILED${NC}"
    
    if [ $TESTS_FAILED -eq 0 ]; then
        echo -e "\n${GREEN}🎉 All integration tests passed!${NC}"
        return 0
    else
        echo -e "\n${RED}❌ Some integration tests failed!${NC}"
        return 1
    fi
}

run_specific_integration_test() {
    local test_name="$1"
    
    case "$test_name" in
        "complete_workflow")
            test_complete_repository_creation_workflow
            ;;
        "error_handling")
            test_error_handling_and_recovery
            ;;
        "token_detection")
            test_token_detection_integration
            ;;
        "project_detection")
            test_project_detection_integration
            ;;
        "git_operations")
            test_git_operations_integration
            ;;
        "cache_integration")
            test_cache_integration
            ;;
        "end_to_end")
            test_end_to_end_workflow
            ;;
        *)
            echo "Unknown integration test: $test_name" >&2
            echo "Available tests: complete_workflow, error_handling, token_detection, project_detection, git_operations, cache_integration, end_to_end" >&2
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
        run_all_integration_tests
    else
        run_specific_integration_test "$test_name"
    fi
}

# Handle script being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
