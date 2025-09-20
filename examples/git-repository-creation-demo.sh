#!/bin/bash

# ==============================================================================
# GitLab Repository Creation Demo
# ==============================================================================
#
# This script demonstrates the new Git repository creation functionality.
# It shows how to turn any local folder into a GitLab repository with
# a single command.
#
# USAGE:
#   bash examples/git-repository-creation-demo.sh [mode]
#
# MODES:
#   demo     - Show demonstration of features
#   test     - Test the functionality
#   usage    - Show usage examples
#
# ==============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
cd "$PROJECT_ROOT"

# Load the functions
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
    echo -e "${CYAN}🚀 GitLab Repository Creation Demo${NC}"
    echo "=================================================="
    echo
}

demo_basic_usage() {
    echo -e "${YELLOW}📖 Basic Usage Demo${NC}"
    echo "------------------------------------"
    echo
    
    log_demo "The new create_gitlab_repository_from_folder function provides a complete workflow:"
    echo
    echo "1️⃣  Auto-detects your GitLab token based on git branch"
    echo "2️⃣  Checks if project name is available"
    echo "3️⃣  Creates GitLab project with description and visibility"
    echo "4️⃣  Initializes local Git repository (if needed)"
    echo "5️⃣  Adds GitLab remote"
    echo "6️⃣  Creates initial commit with all files"
    echo "7️⃣  Pushes code to GitLab"
    echo
    
    log_demo "Basic usage:"
    echo "  create_gitlab_repository_from_folder \"my-awesome-project\""
    echo
    
    log_demo "With custom options:"
    echo "  create_gitlab_repository_from_folder \"my-project\" \"glpat-token\" \"Description\" \"private\" \"main\""
    echo
}

demo_smart_features() {
    echo -e "${YELLOW}🧠 Smart Features Demo${NC}"
    echo "------------------------------------"
    echo
    
    log_demo "Smart Token Detection:"
    echo "• Detects best token based on current git branch"
    echo "• main/master/prod → GITLAB_PROD_TOKEN"
    echo "• develop/dev → GITLAB_DEV_TOKEN"
    echo "• other branches → GITLAB_API_TOKEN"
    echo
    
    log_demo "Project Detection:"
    echo "• Parses git remote URL to identify GitLab project"
    echo "• Looks up project in cache for additional metadata"
    echo "• Provides project ID and details"
    echo
    
    log_demo "Error Handling:"
    echo "• Validates project name availability"
    echo "• Checks Git installation and permissions"
    echo "• Provides helpful error messages and suggestions"
    echo "• Handles network issues and API errors gracefully"
    echo
}

demo_workflow_example() {
    echo -e "${YELLOW}🔄 Complete Workflow Example${NC}"
    echo "------------------------------------"
    echo
    
    log_demo "Here's what happens when you run the command:"
    echo
    
    cat << 'EOF'
🚀 Creating GitLab Repository from Current Folder
=================================================
Project: my-awesome-project
Description: Created from local folder via GitLab API Helper
Visibility: private
Initial Branch: main

Step 1: Detecting GitLab token...
✅ Using token: GITLAB_API_TOKEN

Step 2: Checking if project already exists...
✅ Project name is available

Step 3: Creating GitLab project...
Creating project 'my-awesome-project' with visibility 'private'...
Project 'my-awesome-project' created successfully.
✅ GitLab project created successfully!
   Project ID: 12345
   Project URL: https://gitlab.com/username/my-awesome-project
   SSH URL: git@gitlab.com:username/my-awesome-project.git

Step 4: Setting up local Git repository...
Initializing Git repository...
Adding GitLab remote...
Setting default branch to 'main'...
Creating initial commit...
✅ Local Git repository configured

Step 5: Pushing code to GitLab...
Pushing code to GitLab...
✅ Code successfully pushed to GitLab!

🎉 Repository Creation Complete!
================================
Project Name: my-awesome-project
Project URL: https://gitlab.com/username/my-awesome-project
SSH Clone URL: git@gitlab.com:username/my-awesome-project.git
Local Branch: main

Next steps:
  • Visit: https://gitlab.com/username/my-awesome-project
  • Clone elsewhere: git clone git@gitlab.com:username/my-awesome-project.git
  • Continue development: git add . && git commit -m 'Update' && git push
EOF
    echo
}

demo_system_wide_installation() {
    echo -e "${YELLOW}🌐 System-Wide Installation Demo${NC}"
    echo "------------------------------------"
    echo
    
    log_demo "Install the GitLab API Helper system-wide:"
    echo
    echo "1️⃣  Run the installation script:"
    echo "   bash scripts/install-system-wide.sh"
    echo
    echo "2️⃣  Use commands from anywhere:"
    echo "   gitlab-create-repo \"my-project\""
    echo "   gitlab-manage-members"
    echo "   gitlab-list-projects"
    echo "   gitlab-token-setup"
    echo "   gitlab-cache-init"
    echo "   gitlab-interactive"
    echo
    echo "3️⃣  Commands are installed to ~/bin directory"
    echo "4️⃣  PATH is automatically updated in your shell config"
    echo
}

test_functionality() {
    echo -e "${YELLOW}🧪 Testing Functionality${NC}"
    echo "------------------------------------"
    echo
    
    log_info "Running unit tests..."
    if bash "$PROJECT_ROOT/tests/test-git-repository-creation.sh" >/dev/null 2>&1; then
        log_success "Unit tests passed!"
    else
        log_warning "Some unit tests failed (this is expected in demo mode)"
    fi
    
    log_info "Running integration tests..."
    if bash "$PROJECT_ROOT/tests/test-integration-workflow.sh" >/dev/null 2>&1; then
        log_success "Integration tests passed!"
    else
        log_warning "Some integration tests failed (this is expected in demo mode)"
    fi
    
    log_info "Testing token detection..."
    if detect_active_gitlab_token >/dev/null 2>&1; then
        log_success "Token detection works"
    else
        log_warning "Token detection failed (no tokens in ~/.env)"
    fi
    
    log_info "Testing project detection..."
    if detect_current_project >/dev/null 2>&1; then
        log_success "Project detection works"
    else
        log_warning "Project detection failed (not in GitLab repo)"
    fi
    
    echo
}

show_usage_examples() {
    echo -e "${YELLOW}📚 Usage Examples${NC}"
    echo "------------------------------------"
    echo
    
    echo "🚀 Quick Start:"
    echo "   # Set up your GitLab token first"
    echo "   input_token \"GITLAB_API_TOKEN\""
    echo
    echo "   # Create repository from current folder"
    echo "   create_gitlab_repository_from_folder \"my-project\""
    echo
    
    echo "🎯 Advanced Usage:"
    echo "   # With custom options"
    echo "   create_gitlab_repository_from_folder \"my-project\" \"glpat-token\" \"Description\" \"private\" \"main\""
    echo
    echo "   # Auto-detect token and project"
    echo "   token=\$(detect_active_gitlab_token)"
    echo "   project_id=\$(detect_current_project)"
    echo
    
    echo "🌐 System-Wide Installation:"
    echo "   # Install with tests"
    echo "   bash scripts/install-system-wide.sh"
    echo
    echo "   # Use from anywhere"
    echo "   gitlab-create-repo \"my-project\""
    echo
    
    echo "🧪 Testing:"
    echo "   # Run unit tests"
    echo "   bash tests/test-git-repository-creation.sh"
    echo
    echo "   # Run integration tests"
    echo "   bash tests/test-integration-workflow.sh"
    echo
    echo "   # Test only (no installation)"
    echo "   bash scripts/install-system-wide.sh --test-only"
    echo
}

show_prerequisites() {
    echo -e "${YELLOW}📋 Prerequisites${NC}"
    echo "------------------------------------"
    echo
    
    echo "✅ Required:"
    echo "   • bash (version 3.0+)"
    echo "   • curl (for GitLab API calls)"
    echo "   • jq (for JSON processing)"
    echo "   • git (for repository operations)"
    echo
    echo "✅ GitLab Setup:"
    echo "   • GitLab.com account or self-hosted GitLab"
    echo "   • Personal Access Token with 'api' scope"
    echo "   • SSH keys configured for Git operations"
    echo
    echo "✅ Optional but Recommended:"
    echo "   • Projects cache initialized"
    echo "   • Multiple tokens for different environments"
    echo
}

main() {
    print_header
    
    case "$MODE" in
        demo)
            demo_basic_usage
            demo_smart_features
            demo_workflow_example
            demo_system_wide_installation
            ;;
        test)
            test_functionality
            ;;
        usage)
            show_usage_examples
            show_prerequisites
            ;;
        *)
            echo "Usage: $0 [mode]"
            echo
            echo "Modes:"
            echo "  demo        - Show demonstration of features"
            echo "  test        - Test the functionality"
            echo "  usage       - Show usage examples"
            echo
            exit 1
            ;;
    esac
    
    echo "=============================================="
    log_success "🎉 GitLab Repository Creation Demo Complete!"
    echo
    echo "Next steps:"
    echo "  1. Set up your GitLab token: input_token \"GITLAB_API_TOKEN\""
    echo "  2. Try creating a repository: create_gitlab_repository_from_folder \"test-project\""
    echo "  3. Install system-wide: bash scripts/install-system-wide.sh"
    echo "  4. Run tests: bash tests/test-git-repository-creation.sh"
    echo
}

# Handle script being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
