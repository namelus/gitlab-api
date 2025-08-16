#!/bin/bash

# ==============================================================================
# Smart Member Addition Demo
# ==============================================================================
#
# This script demonstrates the new smart_add_project_member function that
# automatically detects GitLab tokens, current project, and uses cache data.
#
# USAGE:
#   bash smart_member_demo.sh [mode]
#
# MODES:
#   demo     - Show demonstration of features
#   test     - Test detection functions
#   usage    - Show usage examples
#
# ==============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR" && pwd)"
cd "$PROJECT_ROOT"

# Load the original functions
if [ -f "./gitlab-api.sh" ]; then
    source "./gitlab-api.sh"
else
    echo "❌ gitlab-api.sh not found. Make sure you're in the project directory."
    exit 1
fi

# Load cache functions if available
if [ -f "./gitlab-project-cache.sh" ]; then
    source "./gitlab-project-cache.sh"
fi

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

MODE="${1:-demo}"

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

log_demo() {
    echo -e "${CYAN}[DEMO]${NC} $1"
}

print_header() {
    echo "=================================================="
    echo -e "${CYAN}🚀 Smart Member Addition Demo${NC}"
    echo "=================================================="
    echo
}

demo_token_detection() {
    echo -e "${YELLOW}🔍 Token Detection Demo${NC}"
    echo "------------------------------------"
    echo
    
    log_demo "Checking for existing GitLab tokens in ~/.env..."
    
    # Check if .env exists
    if [ ! -f "$HOME/.env" ]; then
        log_warning "No ~/.env file found"
        echo "Creating sample .env for demo..."
        
        # Create a sample .env file for demonstration
        cat > "$HOME/.env.demo" << 'EOF'
GITLAB_API_TOKEN="glpat-xxxxxxxxxxxxxxxxxxxx"
GITLAB_PROD_TOKEN="glpat-yyyyyyyyyyyyyyyyyyyy"
GITLAB_DEV_TOKEN="glpat-zzzzzzzzzzzzzzzzzzzz"
GITLAB_GMAIL_API_TOKEN="glpat-aaaaaaaaaaaaaaaaaaaaa"
OTHER_TOKEN="not-a-gitlab-token"
EOF
        echo "📝 Sample tokens created in ~/.env.demo"
        echo
        echo "Sample tokens that would be detected:"
        grep "^GITLAB_.*_TOKEN=" "$HOME/.env.demo" | while IFS='=' read -r name value; do
            preview="${value:1:10}..."  # Remove quotes and show preview
            echo "  ✅ $name - $preview"
        done
        echo
    else
        echo "📋 Existing tokens in ~/.env:"
        if gitlab_tokens=$(grep -E '^GITLAB_.*_TOKEN=' "$HOME/.env" 2>/dev/null); then
            echo "$gitlab_tokens" | while IFS='=' read -r name value; do
                # Remove quotes and create preview
                clean_value=$(echo "$value" | sed 's/^"//; s/"$//')
                preview="${clean_value:0:10}..."
                echo "  ✅ $name - $preview"
            done
        else
            log_warning "No GitLab tokens found in ~/.env"
            echo "Expected pattern: GITLAB_*_TOKEN"
        fi
        echo
    fi
    
    log_demo "Token selection priority:"
    echo "  1️⃣  GITLAB_API_TOKEN (general purpose - highest priority)"
    echo "  2️⃣  Environment-based (GITLAB_PROD_TOKEN for main branch)"
    echo "  3️⃣  Interactive selection if multiple suitable tokens"
    echo
}

demo_project_detection() {
    echo -e "${YELLOW}📁 Project Detection Demo${NC}"
    echo "------------------------------------"
    echo
    
    log_demo "Analyzing current directory for GitLab project..."
    
    # Check if we're in a git repository
    if ! command -v git >/dev/null 2>&1; then
        log_error "Git not available"
        return 1
    fi
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_warning "Not in a git repository"
        echo "📝 For demonstration, here's what would happen in a GitLab repo:"
        echo
        echo "Sample git remote URLs that would be detected:"
        echo "  ✅ https://gitlab.com/username/project-name.git"
        echo "  ✅ git@gitlab.com:username/project-name.git"
        echo "  ✅ https://custom-gitlab.com/group/subgroup/project.git"
        echo
        echo "Extracted project paths:"
        echo "  📁 username/project-name"
        echo "  📁 group/subgroup/project"
        echo
        echo "💡 The function would then:"
        echo "  1. Look up project in projects-cache.json"
        echo "  2. Extract project ID for API calls"
        echo "  3. Validate user has access to project"
        return 0
    fi
    
    echo "✅ Git repository detected"
    
    # Get git remote
    local remote_url
    if remote_url=$(git remote get-url origin 2>/dev/null); then
        echo "📡 Git remote URL: $remote_url"
        
        # Parse project path
        local project_path=""
        case "$remote_url" in
            *gitlab.com*)
                if [[ "$remote_url" =~ gitlab\.com[:/]([^/]+/[^/]+) ]]; then
                    project_path="${BASH_REMATCH[1]}"
                    project_path="${project_path%.git}"
                    echo "📁 Detected project path: $project_path"
                fi
                ;;
            *gitlab*)
                echo "🏢 Custom GitLab instance detected"
                ;;
            *)
                log_warning "Remote doesn't appear to be GitLab"
                ;;
        esac
        
        if [ -n "$project_path" ]; then
            # Check if we have project cache
            local cache_found=false
            if command -v get_cache_dir >/dev/null 2>&1; then
                local cache_dir
                cache_dir=$(get_cache_dir)
                local cache_file="$cache_dir/projects-cache.json"
                
                if [ -f "$cache_file" ]; then
                    cache_found=true
                    echo "🗄️  Projects cache found: $cache_file"
                    
                    if command -v jq >/dev/null 2>&1; then
                        local project_count
                        project_count=$(jq length "$cache_file" 2>/dev/null)
                        echo "📊 Projects in cache: $project_count"
                        
                        # Try to find current project in cache
                        local project_info
                        project_info=$(jq -r --arg path "$project_path" '
                            .[] | select(.path_with_namespace == $path) |
                            {id: .id, name: .name, path: .path_with_namespace}
                        ' "$cache_file" 2>/dev/null | head -1)
                        
                        if [ -n "$project_info" ] && [ "$project_info" != "null" ]; then
                            echo "✅ Project found in cache!"
                            local project_id=$(echo "$project_info" | jq -r '.id')
                            local project_name=$(echo "$project_info" | jq -r '.name')
                            echo "🆔 Project ID: $project_id"
                            echo "📛 Project Name: $project_name"
                        else
                            log_warning "Project not found in cache"
                            echo "💡 Try refreshing cache: init_project_cache \"\$GITLAB_API_TOKEN\""
                        fi
                    else
                        log_warning "jq not available for cache parsing"
                    fi
                fi
            fi
            
            if [ "$cache_found" = false ]; then
                log_warning "No projects cache found"
                echo "💡 Initialize cache with: init_project_cache \"\$GITLAB_API_TOKEN\""
            fi
        fi
    else
        log_warning "No git remote 'origin' found"
    fi
    
    echo
}

demo_smart_workflow() {
    echo -e "${YELLOW}🧠 Smart Workflow Demo${NC}"
    echo "------------------------------------"
    echo
    
    log_demo "Smart workflow process:"
    echo
    echo "1️⃣  Token Detection:"
    echo "   • Scan ~/.env for GITLAB_*_TOKEN patterns"
    echo "   • Apply priority-based selection"
    echo "   • Consider git branch for environment matching"
    echo
    echo "2️⃣  Project Detection:"
    echo "   • Parse git remote URL"
    echo "   • Look up project in cache"
    echo "   • Extract project ID and metadata"
    echo
    echo "3️⃣  Validation:"
    echo "   • Test token and project access"
    echo "   • Show current member count"
    echo "   • Confirm project details"
    echo
    echo "4️⃣  Member Addition:"
    echo "   • Use existing interactive flow"
    echo "   • All original features preserved"
    echo "   • Enhanced with context information"
    echo
    
    log_demo "Example smart_add_project_member execution:"
    echo
    cat << 'EOF'
🚀 Smart GitLab Member Addition
===============================

Step 1: GitLab Token Detection
------------------------------
🔍 Multiple GitLab tokens found, applying smart selection...
📋 Current git branch: develop
🛠️  Using development token for dev branch: GITLAB_DEV_TOKEN
✅ Auto-detected token: GITLAB_DEV_TOKEN

Step 2: Project Detection
------------------------
🔍 Auto-detecting current project...
📡 Git remote URL: git@gitlab.com:myteam/awesome-project.git
📁 Detected project path: myteam/awesome-project
🗄️  Looking up project in cache...
✅ Found project in cache!
📛 Project Name: Awesome Project
🆔 Project ID: 12345

Step 3: Project Access Validation
---------------------------------
🔐 Validating project access...
✅ Project access confirmed
👥 Current members: 8

Step 4: Member Addition
----------------------
🔄 Starting member addition process...
Project: 12345
Token: GITLAB_DEV_TOKEN

=== Add Member to GitLab Project ===

Enter user's email address: [user input follows...]
EOF
    echo
}

demo_cache_integration() {
    echo -e "${YELLOW}🗄️  Cache Integration Demo${NC}"
    echo "------------------------------------"
    echo
    
    log_demo "Projects cache integration features:"
    echo
    echo "📊 Cache Benefits:"
    echo "   ✅ Fast project lookups (no API calls needed)"
    echo "   ✅ Project ID resolution from git remote"
    echo "   ✅ Additional project metadata (name, URL, etc.)"
    echo "   ✅ Member count and access validation"
    echo
    echo "🔄 Cache Usage in Smart Workflow:"
    echo "   1. Parse project path from git remote"
    echo "   2. Look up project in projects-cache.json"
    echo "   3. Extract project ID for API operations"
    echo "   4. Show project context before adding members"
    echo
    echo "💾 Cache File Location:"
    
    if command -v get_cache_dir >/dev/null 2>&1; then
        local cache_dir
        cache_dir=$(get_cache_dir)
        echo "   📁 $cache_dir/projects-cache.json"
        
        if [ -f "$cache_dir/projects-cache.json" ]; then
            log_success "Cache file exists"
            if command -v jq >/dev/null 2>&1; then
                local project_count
                project_count=$(jq length "$cache_dir/projects-cache.json" 2>/dev/null)
                echo "   📊 Projects cached: $project_count"
                
                echo "   📋 Sample cache entry:"
                jq -r '.[0] | {id: .id, name: .name, path: .path_with_namespace}' "$cache_dir/projects-cache.json" 2>/dev/null | sed 's/^/      /'
            fi
        else
            log_warning "Cache file not found"
            echo "   💡 Initialize with: init_project_cache \"\$GITLAB_API_TOKEN\""
        fi
    else
        echo "   ⚠️  Cache directory function not available"
        echo "   💡 Source gitlab-project-cache.sh first"
    fi
    
    echo
}

test_detection_functions() {
    echo -e "${YELLOW}🧪 Testing Detection Functions${NC}"
    echo "------------------------------------"
    echo
    
    # Test token detection
    log_info "Testing detect_active_gitlab_token()..."
    
    # Mock function for demo
    demo_detect_active_gitlab_token() {
        if [ -f "$HOME/.env" ] && grep -q "^GITLAB_.*_TOKEN=" "$HOME/.env"; then
            echo "🎯 Auto-detected token: GITLAB_API_TOKEN" >&2
            echo "GITLAB_API_TOKEN"
            return 0
        else
            echo "Error: No GitLab tokens found" >&2
            return 1
        fi
    }
    
    if demo_detect_active_gitlab_token >/dev/null; then
        log_success "Token detection would work"
    else
        log_warning "Token detection would fail - no GitLab tokens in ~/.env"
    fi
    
    echo
    
    # Test project detection
    log_info "Testing detect_current_project()..."
    
    if git rev-parse --git-dir >/dev/null 2>&1; then
        if git remote get-url origin >/dev/null 2>&1; then
            local remote_url
            remote_url=$(git remote get-url origin)
            if [[ "$remote_url" == *gitlab* ]]; then
                log_success "Project detection would work"
                echo "  📡 Remote: $remote_url"
            else
                log_warning "Project detection would fail - not a GitLab remote"
            fi
        else
            log_warning "Project detection would fail - no git remote"
        fi
    else
        log_warning "Project detection would fail - not in git repository"
    fi
    
    echo
    
    # Test cache integration
    log_info "Testing cache integration..."
    
    if command -v get_cache_dir >/dev/null 2>&1; then
        local cache_dir
        cache_dir=$(get_cache_dir)
        if [ -f "$cache_dir/projects-cache.json" ]; then
            log_success "Cache integration would work"
            echo "  📁 Cache: $cache_dir/projects-cache.json"
        else
            log_warning "Cache integration would be limited - no cache file"
            echo "  💡 Run: init_project_cache \"\$GITLAB_API_TOKEN\""
        fi
    else
        log_warning "Cache integration not available - gitlab-project-cache.sh not loaded"
    fi
    
    echo
}

show_usage_examples() {
    echo -e "${YELLOW}📖 Usage Examples${NC}"
    echo "------------------------------------"
    echo
    
    echo "🚀 Basic Usage (recommended):"
    echo "   cd /path/to/your/gitlab/project"
    echo "   source ./gitlab-api.sh"
    echo "   # Load smart functions (add to gitlab-api.sh or source separately)"
    echo "   smart_add_project_member"
    echo
    
    echo "🎯 Override Project:"
    echo "   smart_add_project_member \"123\""
    echo "   # Uses specified project, auto-detects token"
    echo
    
    echo "🔧 Override Token and Project:"
    echo "   smart_add_project_member \"123\" \"GITLAB_PROD_TOKEN\""
    echo "   # Uses both specified values"
    echo
    
    echo "🔍 Test Detection Functions:"
    echo "   detect_active_gitlab_token"
    echo "   detect_current_project"
    echo
    
    echo "📋 Prerequisites Checklist:"
    echo "   ✅ Be in a GitLab repository directory"
    echo "   ✅ Have GitLab tokens in ~/.env (GITLAB_*_TOKEN pattern)"
    echo "   ✅ Git remote 'origin' pointing to GitLab"
    echo "   ✅ Projects cache initialized (optional but recommended)"
    echo
    
    echo "💡 Setup Steps:"
    echo "   1. Set up GitLab tokens:"
    echo "      echo 'GITLAB_API_TOKEN=\"glpat-your-token\"' >> ~/.env"
    echo "      chmod 600 ~/.env"
    echo
    echo "   2. Initialize projects cache:"
    echo "      source ./gitlab-api.sh"
    echo "      source ./gitlab-project-cache.sh"
    echo "      init_project_cache \"\$(get_env_variable 'GITLAB_API_TOKEN')\""
    echo
    echo "   3. Use smart member addition:"
    echo "      cd /path/to/gitlab/repo"
    echo "      smart_add_project_member"
    echo
}

show_integration_guide() {
    echo -e "${YELLOW}🔧 Integration Guide${NC}"
    echo "------------------------------------"
    echo
    
    echo "To integrate smart member addition into your gitlab-api.sh:"
    echo
    echo "1️⃣  Add the smart functions to gitlab-api.sh:"
    echo "   • Copy detect_active_gitlab_token()"
    echo "   • Copy detect_current_project()"
    echo "   • Copy smart_add_project_member()"
    echo "   • Copy utility functions"
    echo
    echo "2️⃣  Update the workflow in README.md:"
    echo "   Replace:"
    echo "     # 3. Add a member interactively"
    echo "     token=\$(get_env_variable \"GITLAB_API_TOKEN\")"
    echo "     add_project_member \"YOUR_PROJECT_ID\" \"\$token\""
    echo
    echo "   With:"
    echo "     # 3. Add a member with smart detection"
    echo "     smart_add_project_member"
    echo
    echo "3️⃣  Add new demo examples:"
    echo "   • Create examples/smart-member-demo.sh"
    echo "   • Update member-management-demo.sh"
    echo "   • Add test cases for detection functions"
    echo
    echo "4️⃣  Update tests:"
    echo "   • Add tests for token detection"
    echo "   • Add tests for project detection"
    echo "   • Add cache integration tests"
    echo
}

main() {
    print_header
    
    case "$MODE" in
        demo)
            demo_token_detection
            demo_project_detection
            demo_smart_workflow
            demo_cache_integration
            ;;
        test)
            test_detection_functions
            ;;
        usage)
            show_usage_examples
            ;;
        integration)
            show_integration_guide
            ;;
        *)
            echo "Usage: $0 [mode]"
            echo
            echo "Modes:"
            echo "  demo        - Show demonstration of smart features"
            echo "  test        - Test detection functions"
            echo "  usage       - Show usage examples"
            echo "  integration - Show integration guide"
            echo
            exit 1
            ;;
    esac
    
    echo "=============================================="
    log_success "🎉 Smart Member Addition Demo Complete!"
    echo
    echo "Next steps:"
    echo "  1. Add smart functions to gitlab-api.sh"
    echo "  2. Test in your GitLab repository: smart_add_project_member"
    echo "  3. Try: bash $0 test"
    echo "  4. See integration guide: bash $0 integration"
    echo
}

# Handle script being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi