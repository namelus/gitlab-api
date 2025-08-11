#!/bin/bash

# ==============================================================================
# GitLab API Member Management Demo Script
# ==============================================================================
#
# This script demonstrates how to use the GitLab API member management functions
# to add, list, and remove members from GitLab projects.
#
# USAGE:
#   bash examples/member-management-demo.sh [demo_mode]
#
# DEMO MODES:
#   interactive  - Interactive demo with user prompts
#   automated    - Automated demo with sample data
#   help         - Show usage information
#
# REQUIREMENTS:
#   - Valid GitLab Personal Access Token stored in ~/.env
#   - GitLab project ID or path to work with
#   - User email addresses to add as members
#
# ==============================================================================

set -euo pipefail

# Get script directory and project root
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(cd "$SCRIPT_DIR/.." && pwd)"
cd "$PROJECT_ROOT"

# Source the main GitLab API functions
source "./gitlab-api.sh"

# Demo configuration
DEMO_MODE="${1:-interactive}"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
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

log_demo() {
    echo -e "${CYAN}[DEMO]${NC} $1"
}

print_header() {
    echo "=============================================="
    echo -e "${CYAN}🚀 GitLab API Member Management Demo${NC}"
    echo "=============================================="
    echo
}

print_section() {
    echo
    echo -e "${YELLOW}📋 $1${NC}"
    echo "----------------------------------------------"
}

# ============================================================================
# DEMO FUNCTIONS
# ============================================================================

demo_setup() {
    print_section "Setup and Prerequisites"
    
    log_info "Checking for GitLab API token..."
    
    local token
    if token=$(get_env_variable "GITLAB_API_TOKEN" 2>/dev/null); then
        log_success "GitLab API token found"
    else
        log_error "GitLab API token not found!"
        echo
        echo "To set up your token, run:"
        echo "  source ./gitlab-api.sh"
        echo "  input_token \"GITLAB_API_TOKEN\""
        echo
        return 1
    fi
    
    log_info "Testing API connectivity..."
    if timeout 10 get_list_of_projects_simple "$token" >/dev/null 2>&1; then
        log_success "API connectivity verified"
    else
        log_warning "API connectivity test failed (this may be normal)"
    fi
    
    echo
    log_demo "Prerequisites checked successfully!"
}

demo_list_members() {
    print_section "Listing Project Members"
    
    local token
    token=$(get_env_variable "GITLAB_API_TOKEN")
    
    echo "This function lists all members of a GitLab project."
    echo
    echo "Usage examples:"
    echo "  list_project_members \"123\" \"\$GITLAB_API_TOKEN\""
    echo "  list_project_members \"mygroup%2Fmyproject\" \"\$GITLAB_API_TOKEN\" \"csv\""
    echo
    
    if [ "$DEMO_MODE" = "interactive" ]; then
        read -p "Enter a project ID to list members (or press Enter to skip): " project_id
        
        if [ -n "$project_id" ]; then
            log_demo "Listing members for project: $project_id"
            echo
            
            if list_project_members "$project_id" "$token" "table"; then
                log_success "Members listed successfully!"
            else
                log_error "Failed to list members (project may not exist or you may not have access)"
            fi
        else
            log_info "Skipping member listing demo"
        fi
    else
        log_demo "In automated mode - skipping actual API call"
        echo "Sample output format:"
        echo
        printf "%-20s %-15s %-12s %-12s\n" "Name" "Username" "Role" "Expires"
        echo "------------------------------------------------------------"
        printf "%-20s %-15s %-12s %-12s\n" "John Doe" "johndoe" "Developer" "Never"
        printf "%-20s %-15s %-12s %-12s\n" "Jane Smith" "janesmith" "Maintainer" "2025-12-31"
    fi
}

demo_add_member() {
    print_section "Adding Project Members"
    
    local token
    token=$(get_env_variable "GITLAB_API_TOKEN")
    
    echo "This function adds a member to a GitLab project with interactive prompts."
    echo
    echo "The function will prompt for:"
    echo "  1. User's email address"
    echo "  2. Role selection (Guest, Reporter, Developer, Maintainer, Owner)"
    echo "  3. Optional expiry date (YYYY-MM-DD format)"
    echo
    echo "Usage example:"
    echo "  add_project_member \"123\" \"\$GITLAB_API_TOKEN\""
    echo
    
    if [ "$DEMO_MODE" = "interactive" ]; then
        read -p "Would you like to try adding a member? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            read -p "Enter project ID: " project_id
            
            if [ -n "$project_id" ]; then
                log_demo "Starting interactive member addition for project: $project_id"
                echo
                
                if add_project_member "$project_id" "$token"; then
                    log_success "Member addition completed!"
                else
                    log_error "Member addition failed"
                fi
            else
                log_warning "No project ID provided, skipping"
            fi
        else
            log_info "Skipping member addition demo"
        fi
    else
        log_demo "In automated mode - showing sample interaction"
        echo
        echo "Sample interaction:"
        echo "=== Add Member to GitLab Project ==="
        echo
        echo "Enter user's email address: user@example.com"
        echo "Looking up user by email..."
        echo "Found user: John Doe (@johndoe)"
        echo
        echo "Select user role:"
        echo "1) Guest (10) - Can view project, create issues and comments"
        echo "2) Reporter (20) - Can pull project, download artifacts, create issues/merge requests"
        echo "3) Developer (30) - Can push to non-protected branches, manage issues/merge requests"
        echo "4) Maintainer (40) - Can push to protected branches, manage project settings"
        echo "5) Owner (50) - Full access including project deletion"
        echo
        echo "Enter choice (1-5): 3"
        echo
        echo "Enter expiry date (YYYY-MM-DD) or press Enter for no expiry: 2025-12-31"
        echo
        echo "Adding member to project..."
        echo "✅ Member added successfully!"
        echo "User: John Doe (@johndoe)"
        echo "Role: Developer"
        echo "Expires: 2025-12-31"
    fi
}

demo_remove_member() {
    print_section "Removing Project Members"
    
    local token
    token=$(get_env_variable "GITLAB_API_TOKEN")
    
    echo "This function removes a member from a GitLab project."
    echo
    echo "You can specify the user by:"
    echo "  - Email address (e.g., user@example.com)"
    echo "  - User ID (e.g., 12345)"
    echo
    echo "Usage examples:"
    echo "  remove_project_member \"123\" \"user@example.com\" \"\$GITLAB_API_TOKEN\""
    echo "  remove_project_member \"123\" \"12345\" \"\$GITLAB_API_TOKEN\""
    echo
    
    if [ "$DEMO_MODE" = "interactive" ]; then
        read -p "Would you like to try removing a member? (y/N): " confirm
        
        if [[ "$confirm" =~ ^[Yy]$ ]]; then
            read -p "Enter project ID: " project_id
            read -p "Enter user email or ID to remove: " user_identifier
            
            if [ -n "$project_id" ] && [ -n "$user_identifier" ]; then
                log_demo "Starting member removal for project: $project_id"
                echo
                
                if remove_project_member "$project_id" "$user_identifier" "$token"; then
                    log_success "Member removal completed!"
                else
                    log_error "Member removal failed"
                fi
            else
                log_warning "Missing project ID or user identifier, skipping"
            fi
        else
            log_info "Skipping member removal demo"
        fi
    else
        log_demo "In automated mode - showing sample interaction"
        echo
        echo "Sample interaction:"
        echo "Looking up user by email..."
        echo "Found user: John Doe (@johndoe)"
        echo
        echo "Are you sure you want to remove this member? (y/N): y"
        echo "Removing member from project..."
        echo "✅ Member removed successfully!"
    fi
}

demo_role_management() {
    print_section "Understanding GitLab Roles"
    
    echo "GitLab has 5 standard access levels for project members:"
    echo
    echo "🔍 Guest (10):"
    echo "   - Can view project"
    echo "   - Can create issues and comments"
    echo "   - Cannot access code or download artifacts"
    echo
    echo "📊 Reporter (20):"
    echo "   - All Guest permissions"
    echo "   - Can pull project code"
    echo "   - Can download artifacts"
    echo "   - Can create merge requests"
    echo
    echo "💻 Developer (30):"
    echo "   - All Reporter permissions"
    echo "   - Can push to non-protected branches"
    echo "   - Can manage issues and merge requests"
    echo "   - Can create and manage project labels"
    echo
    echo "🔧 Maintainer (40):"
    echo "   - All Developer permissions"
    echo "   - Can push to protected branches"
    echo "   - Can manage project settings"
    echo "   - Can add/remove project members"
    echo
    echo "👑 Owner (50):"
    echo "   - All Maintainer permissions"
    echo "   - Full project access including deletion"
    echo "   - Can transfer project ownership"
    echo
    
    log_demo "Role conversion function test:"
    echo "get_role_name 10 = $(get_role_name 10)"
    echo "get_role_name 20 = $(get_role_name 20)"
    echo "get_role_name 30 = $(get_role_name 30)"
    echo "get_role_name 40 = $(get_role_name 40)"
    echo "get_role_name 50 = $(get_role_name 50)"
}

demo_best_practices() {
    print_section "Best Practices for Member Management"
    
    echo "🔐 Security Best Practices:"
    echo "   - Use principle of least privilege (start with lower roles)"
    echo "   - Set expiry dates for temporary access"
    echo "   - Regularly audit project members"
    echo "   - Remove inactive members promptly"
    echo
    echo "📋 Operational Best Practices:"
    echo "   - Document member roles and responsibilities"
    echo "   - Use consistent role assignments across projects"
    echo "   - Automate member management where possible"
    echo "   - Monitor member activity and access patterns"
    echo
    echo "🚀 Automation Tips:"
    echo "   - Use CSV export to analyze member data"
    echo "   - Script bulk member operations"
    echo "   - Integrate with HR systems for automatic provisioning"
    echo "   - Set up alerts for role changes"
    echo
    echo "Example automation script:"
    echo '```bash'
    echo '#!/bin/bash'
    echo 'source ./gitlab-api.sh'
    echo 'token=$(get_env_variable "GITLAB_API_TOKEN")'
    echo ''
    echo '# Bulk add developers to multiple projects'
    echo 'projects=("123" "456" "789")'
    echo 'developers=("dev1@company.com" "dev2@company.com")'
    echo ''
    echo 'for project in "${projects[@]}"; do'
    echo '    for dev in "${developers[@]}"; do'
    echo '        echo "Adding $dev to project $project"'
    echo '        # Note: This would require non-interactive version'
    echo '        # add_project_member_batch "$project" "$dev" "30" "$token"'
    echo '    done'
    echo 'done'
    echo '```'
}

demo_troubleshooting() {
    print_section "Troubleshooting Common Issues"
    
    echo "❌ Common Error Scenarios:"
    echo
    echo "1. 'User not found in GitLab'"
    echo "   - Verify the email address is correct"
    echo "   - Ensure the user has a GitLab account"
    echo "   - Check if the user's account is active"
    echo
    echo "2. 'Project not found'"
    echo "   - Verify the project ID or path is correct"
    echo "   - Ensure you have access to the project"
    echo "   - For project paths, use URL encoding (e.g., group%2Fproject)"
    echo
    echo "3. 'Forbidden - insufficient permissions'"
    echo "   - Ensure your token has 'api' scope"
    echo "   - Verify you have Maintainer or Owner role in the project"
    echo "   - Check if the project allows member additions"
    echo
    echo "4. 'Member already exists'"
    echo "   - The user is already a member of the project"
    echo "   - Use list_project_members to check current members"
    echo "   - Consider updating the member's role instead"
    echo
    echo "🔧 Debugging Tips:"
    echo "   - Test with get_list_of_projects_simple first"
    echo "   - Use list_project_members to verify project access"
    echo "   - Check GitLab's API documentation for error codes"
    echo "   - Enable verbose curl output for detailed debugging"
}

show_usage() {
    echo "Usage: $0 [demo_mode]"
    echo
    echo "Demo modes:"
    echo "  interactive  - Interactive demo with user prompts (default)"
    echo "  automated    - Automated demo with sample data"
    echo "  help         - Show this usage information"
    echo
    echo "Examples:"
    echo "  $0 interactive"
    echo "  $0 automated"
    echo "  $0 help"
}

# ============================================================================
# MAIN DEMO EXECUTION
# ============================================================================

main() {
    case "$DEMO_MODE" in
        interactive|automated)
            print_header
            
            if ! demo_setup; then
                log_error "Setup failed. Please configure your GitLab token first."
                exit 1
            fi
            
            demo_role_management
            demo_list_members
            demo_add_member
            demo_remove_member
            demo_best_practices
            demo_troubleshooting
            
            echo
            echo "=============================================="
            log_success "🎉 Member Management Demo Complete!"
            echo "=============================================="
            echo
            echo "Next steps:"
            echo "  1. Try the functions with your own projects"
            echo "  2. Run the test suite: bash tests/test-member-management.sh"
            echo "  3. Check the comprehensive tests: bash hooks/test-runner.sh comprehensive"
            echo
            ;;
        help|--help|-h)
            show_usage
            ;;
        *)
            log_error "Invalid demo mode: $DEMO_MODE"
            show_usage
            exit 1
            ;;
    esac
}

# Handle script being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
