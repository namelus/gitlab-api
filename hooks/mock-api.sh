#!/bin/bash

# Mock GitLab API responses for testing GitLab API Helper
# Provides realistic API responses without making real network calls

set -euo pipefail

# Mock API configuration
MOCK_API_VERSION="v4"
MOCK_BASE_URL="https://gitlab.com/api/$MOCK_API_VERSION"

# Colors
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
RED='\033[0;31m'
NC='\033[0m'

log_mock() {
    echo -e "${YELLOW}[MOCK API]${NC} $1" >&2
}

# ============================================================================
# MOCK RESPONSE DATA
# ============================================================================

generate_mock_projects_list() {
    cat << 'EOF'
[
  {
    "id": 1,
    "name": "awesome-project",
    "path": "awesome-project",
    "description": "An awesome test project for development",
    "visibility": "private",
    "web_url": "https://gitlab.com/testuser/awesome-project",
    "ssh_url_to_repo": "git@gitlab.com:testuser/awesome-project.git",
    "http_url_to_repo": "https://gitlab.com/testuser/awesome-project.git",
    "last_activity_at": "2025-08-07T10:30:00.000Z",
    "created_at": "2025-08-01T09:00:00.000Z",
    "updated_at": "2025-08-07T10:30:00.000Z",
    "default_branch": "main",
    "namespace": {
      "id": 100,
      "name": "testuser",
      "path": "testuser",
      "kind": "user"
    },
    "owner": {
      "id": 200,
      "username": "testuser",
      "name": "Test User"
    }
  },
  {
    "id": 2,
    "name": "gitlab-api-helper",
    "path": "gitlab-api-helper",
    "description": "Helper library for GitLab API interactions",
    "visibility": "public",
    "web_url": "https://gitlab.com/testuser/gitlab-api-helper",
    "ssh_url_to_repo": "git@gitlab.com:testuser/gitlab-api-helper.git",
    "http_url_to_repo": "https://gitlab.com/testuser/gitlab-api-helper.git",
    "last_activity_at": "2025-08-06T15:45:00.000Z",
    "created_at": "2025-07-15T12:00:00.000Z",
    "updated_at": "2025-08-06T15:45:00.000Z",
    "default_branch": "main",
    "namespace": {
      "id": 100,
      "name": "testuser",
      "path": "testuser", 
      "kind": "user"
    },
    "owner": {
      "id": 200,
      "username": "testuser",
      "name": "Test User"
    }
  },
  {
    "id": 3,
    "name": "old-legacy-project",
    "path": "old-legacy-project",
    "description": "Legacy project with minimal activity",
    "visibility": "private",
    "web_url": "https://gitlab.com/testuser/old-legacy-project",
    "ssh_url_to_repo": "git@gitlab.com:testuser/old-legacy-project.git",
    "http_url_to_repo": "https://gitlab.com/testuser/old-legacy-project.git",
    "last_activity_at": "2024-12-15T08:20:00.000Z",
    "created_at": "2024-06-01T10:00:00.000Z",
    "updated_at": "2024-12-15T08:20:00.000Z",
    "default_branch": "master",
    "namespace": {
      "id": 100,
      "name": "testuser",
      "path": "testuser",
      "kind": "user"
    },
    "owner": {
      "id": 200,
      "username": "testuser",
      "name": "Test User"
    }
  }
]
EOF
}

generate_mock_project_creation_success() {
    local project_name="$1"
    cat << EOF
{
  "id": 999,
  "name": "$project_name",
  "path": "$project_name",
  "description": "Test project created via GitLab API Helper",
  "visibility": "private",
  "web_url": "https://gitlab.com/testuser/$project_name",
  "ssh_url_to_repo": "git@gitlab.com:testuser/$project_name.git",
  "http_url_to_repo": "https://gitlab.com/testuser/$project_name.git",
  "last_activity_at": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
  "created_at": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
  "updated_at": "$(date -u +%Y-%m-%dT%H:%M:%S.000Z)",
  "default_branch": "main",
  "namespace": {
    "id": 100,
    "name": "testuser",
    "path": "testuser",
    "kind": "user"
  },
  "owner": {
    "id": 200,
    "username": "testuser",
    "name": "Test User"
  },
  "permissions": {
    "project_access": {
      "access_level": 50,
      "notification_level": 3
    }
  }
}
EOF
}

generate_mock_error_401() {
    cat << 'EOF'
{
  "message": "401 Unauthorized"
}
EOF
}

generate_mock_error_409() {
    local project_name="$1"
    cat << EOF
{
  "message": {
    "name": ["has already been taken"]
  },
  "error": "Project '$project_name' already exists"
}
EOF
}

generate_mock_error_422() {
    cat << 'EOF'
{
  "message": {
    "name": ["can contain only letters, digits, '_', '-' and '.'. Cannot start with '-', end in '.git' or end in '.atom'"]
  }
}
EOF
}

# ============================================================================
# MOCK API FUNCTIONS
# ============================================================================

mock_gitlab_api_call() {
    local method="$1"
    local endpoint="$2"
    local token="${3:-}"
    local data="${4:-}"
    
    log_mock "Intercepting API call: $method $endpoint"
    
    # Simulate authentication check
    if [ -z "$token" ] || [[ "$token" != glpat-* ]]; then
        log_mock "Authentication failed - invalid token format"
        echo '{"message":"401 Unauthorized"}'
        return 1
    fi
    
    # Route the API call
    case "$endpoint" in
        "/projects")
            handle_projects_endpoint "$method" "$token" "$data"
            ;;
        "/projects?membership=true&per_page="*)
            handle_projects_list_endpoint "$method" "$token" "$endpoint"
            ;;
        *)
            log_mock "Unknown endpoint: $endpoint"
            echo '{"message":"404 Not Found"}'
            return 1
            ;;
    esac
}

handle_projects_endpoint() {
    local method="$1"
    local token="$2"
    local data="$3"
    
    case "$method" in
        "POST")
            # Project creation
            if [ -n "$data" ]; then
                local project_name
                project_name=$(echo "$data" | jq -r '.name // empty')
                
                if [ -n "$project_name" ]; then
                    # Simulate different responses based on project name
                    case "$project_name" in
                        *"existing"*|*"taken"*)
                            log_mock "Simulating project name conflict"
                            generate_mock_error_409 "$project_name"
                            return 1
                            ;;
                        *"invalid"*|*"bad"*)
                            log_mock "Simulating invalid project name"
                            generate_mock_error_422
                            return 1
                            ;;
                        *)
                            log_mock "Simulating successful project creation: $project_name"
                            generate_mock_project_creation_success "$project_name"
                            return 0
                            ;;
                    esac
                else
                    log_mock "Missing project name in request"
                    generate_mock_error_422
                    return 1
                fi
            else
                log_mock "Missing request data for project creation"
                generate_mock_error_422
                return 1
            fi
            ;;
        *)
            log_mock "Unsupported method for /projects: $method"
            echo '{"message":"405 Method Not Allowed"}'
            return 1
            ;;
    esac
}

handle_projects_list_endpoint() {
    local method="$1"
    local token="$2"
    local endpoint="$3"
    
    case "$method" in
        "GET")
            log_mock "Simulating project list retrieval"
            
            # Parse query parameters for filtering
            if echo "$endpoint" | grep -q "last_activity_after="; then
                local date_filter
                date_filter=$(echo "$endpoint" | sed -n 's/.*last_activity_after=\([^&]*\).*/\1/p')
                log_mock "Filtering by date: $date_filter"
                # For simplicity, return fewer projects when date filter is applied
                generate_mock_projects_list | jq '.[:2]'
            elif echo "$endpoint" | grep -q "visibility="; then
                local visibility_filter  
                visibility_filter=$(echo "$endpoint" | sed -n 's/.*visibility=\([^&]*\).*/\1/p')
                log_mock "Filtering by visibility: $visibility_filter"
                # Filter projects by visibility
                generate_mock_projects_list | jq --arg vis "$visibility_filter" '[.[] | select(.visibility == $vis)]'
            else
                generate_mock_projects_list
            fi
            return 0
            ;;
        *)
            log_mock "Unsupported method for projects list: $method"
            echo '{"message":"405 Method Not Allowed"}'
            return 1
            ;;
    esac
}

# ============================================================================
# CURL WRAPPER FUNCTIONS
# ============================================================================

mock_curl() {
    local args=("$@")
    local method="GET"
    local url=""
    local token=""
    local data=""
    local write_out=""
    
    # Parse curl arguments
    for i in "${!args[@]}"; do
        case "${args[$i]}" in
            "--request")
                method="${args[$((i+1))]}"
                ;;
            "--header")
                local header="${args[$((i+1))]}"
                if [[ "$header" == "PRIVATE-TOKEN:"* ]]; then
                    token="${header#PRIVATE-TOKEN: }"
                fi
                ;;
            "--data")
                data="${args[$((i+1))]}"
                ;;
            "--url")
                url="${args[$((i+1))]}"
                ;;
            "--write-out")
                write_out="${args[$((i+1))]}"
                ;;
        esac
    done
    
    # Extract endpoint from URL
    local endpoint="${url#$MOCK_BASE_URL}"
    
    # Handle write-out format for HTTP status codes
    if [ -n "$write_out" ] && [[ "$write_out" == *"%{http_code}"* ]]; then
        local response
        if response=$(mock_gitlab_api_call "$method" "$endpoint" "$token" "$data"); then
            echo "${response}201"  # Append success status code
        else
            local exit_code=$?
            case $exit_code in
                1) echo "${response}401" ;;  # Unauthorized
                *) echo "${response}500" ;;  # Server error
            esac
        fi
    else
        mock_gitlab_api_call "$method" "$endpoint" "$token" "$data"
    fi
}

# ============================================================================
# TEST HELPER FUNCTIONS
# ============================================================================

test_mock_projects_list() {
    log_mock "Testing mock projects list..."
    
    local token="glpat-test-token-123"
    local response
    
    response=$(mock_gitlab_api_call "GET" "/projects?membership=true&per_page=100" "$token")
    echo "$response" | jq -r '.[] | "\(.name) - \(.last_activity_at)"'
}

test_mock_project_creation() {
    log_mock "Testing mock project creation..."
    
    local token="glpat-test-token-123"
    local project_data='{"name":"test-project-mock"}'
    local response
    
    if response=$(mock_gitlab_api_call "POST" "/projects" "$token" "$project_data"); then
        echo "✅ Project creation successful"
        echo "$response" | jq '.name, .web_url'
    else
        echo "❌ Project creation failed"
        echo "$response"
    fi
}

test_mock_csv_output() {
    log_mock "Testing mock CSV output simulation..."
    
    local token="glpat-test-token-123"
    local response
    
    response=$(mock_gitlab_api_call "GET" "/projects?membership=true&per_page=100" "$token")
    
    echo "name,last_activity_at,visibility,web_url"
    echo "$response" | jq -r '.[] | [.name, .last_activity_at, .visibility, .web_url] | @csv'
}

# ============================================================================
# INTEGRATION WITH REAL FUNCTIONS
# ============================================================================

setup_mock_environment() {
    log_mock "Setting up mock environment for testing..."
    
    # Override curl command to use our mock
    alias curl='mock_curl'
    
    # Set mock token
    export GITLAB_GMAIL_API_TOKEN="glpat-mock-token-for-testing"
    
    log_mock "Mock environment ready!"
    log_mock "  - curl command overridden"
    log_mock "  - Mock token set: ${GITLAB_GMAIL_API_TOKEN:0:20}..."
}

teardown_mock_environment() {
    log_mock "Tearing down mock environment..."
    
    unalias curl 2>/dev/null || true
    unset GITLAB_GMAIL_API_TOKEN
    
    log_mock "Mock environment cleaned up"
}

# ============================================================================
# MAIN FUNCTION FOR TESTING
# ============================================================================

if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    echo "🧪 GitLab API Mock Testing"
    echo "=========================="
    
    case "${1:-demo}" in
        "demo")
            setup_mock_environment
            echo ""
            echo "📋 Mock Projects List:"
            test_mock_projects_list
            echo ""
            echo "🏗️ Mock Project Creation:"
            test_mock_project_creation
            echo ""
            echo "📊 Mock CSV Output:"
            test_mock_csv_output
            teardown_mock_environment
            ;;
        "setup")
            setup_mock_environment
            echo "Mock environment is now active. Run your GitLab API Helper functions normally."
            ;;
        "teardown")
            teardown_mock_environment
            ;;
        *)
            echo "Usage: $0 [demo|setup|teardown]"
            exit 1
            ;;
    esac
fi
