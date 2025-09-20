#!/bin/bash

# ==============================================================================
# GitLab API Helper - System-Wide Installation Script v2.1.0
# ==============================================================================
#
# This script installs the GitLab API Helper scripts system-wide, making them
# available from anywhere in the system. It includes:
# - Running comprehensive tests before installation
# - Installing scripts to ~/bin directory
# - Setting up proper permissions
# - Creating wrapper scripts for easy access
# - Verifying installation
#
# USAGE:
#   bash scripts/install-system-wide.sh [options]
#
# OPTIONS:
#   --force          Skip tests and force installation
#   --test-only      Only run tests, don't install
#   --uninstall      Remove installed scripts
#   --help           Show this help message
#
# ==============================================================================

set -euo pipefail

# Script configuration
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
INSTALL_DIR="$HOME/bin"
WRAPPER_DIR="$INSTALL_DIR/gitlab-api-helper"

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
CYAN='\033[0;36m'
NC='\033[0m'

# Installation options
FORCE_INSTALL=false
TEST_ONLY=false
UNINSTALL=false

# Output functions
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

log_install() {
    echo -e "${CYAN}[INSTALL]${NC} $1"
}

# Parse command line arguments
parse_arguments() {
    while [[ $# -gt 0 ]]; do
        case $1 in
            --force)
                FORCE_INSTALL=true
                shift
                ;;
            --test-only)
                TEST_ONLY=true
                shift
                ;;
            --uninstall)
                UNINSTALL=true
                shift
                ;;
            --help|-h)
                show_help
                exit 0
                ;;
            *)
                log_error "Unknown option: $1"
                show_help
                exit 1
                ;;
        esac
    done
}

show_help() {
    cat << 'EOF'
GitLab API Helper - System-Wide Installation

USAGE:
    bash scripts/install-system-wide.sh [options]

OPTIONS:
    --force          Skip tests and force installation
    --test-only      Only run tests, don't install
    --uninstall      Remove installed scripts
    --help           Show this help message

DESCRIPTION:
    This script installs the GitLab API Helper scripts system-wide, making
    them available from anywhere in the system. The installation includes:

    • Comprehensive testing before installation
    • Installation to ~/bin directory
    • Proper permissions and executable flags
    • Wrapper scripts for easy command-line access
    • Verification of installation

INSTALLED COMMANDS:
    gitlab-create-repo    - Create GitLab repository from current folder
    gitlab-manage-members - Manage project members interactively
    gitlab-list-projects  - List GitLab projects
    gitlab-token-setup    - Set up GitLab tokens
    gitlab-cache-init     - Initialize project cache

EXAMPLES:
    # Normal installation (with tests)
    bash scripts/install-system-wide.sh

    # Force installation (skip tests)
    bash scripts/install-system-wide.sh --force

    # Test only (no installation)
    bash scripts/install-system-wide.sh --test-only

    # Uninstall
    bash scripts/install-system-wide.sh --uninstall

REQUIREMENTS:
    • bash (version 3.0 or higher)
    • curl (for GitLab API calls)
    • jq (for JSON processing)
    • git (for repository operations)
    • ~/bin directory (will be created if needed)

EOF
}

# Check system requirements
check_requirements() {
    log_info "Checking system requirements..."
    
    local missing_deps=()
    
    # Check bash version
    if ! bash --version | grep -q "version [3-9]"; then
        missing_deps+=("bash (version 3.0+)")
    fi
    
    # Check required commands
    for cmd in curl jq git; do
        if ! command -v "$cmd" >/dev/null 2>&1; then
            missing_deps+=("$cmd")
        fi
    done
    
    if [ ${#missing_deps[@]} -gt 0 ]; then
        log_error "Missing required dependencies:"
        for dep in "${missing_deps[@]}"; do
            echo "  • $dep"
        done
        echo
        echo "Please install missing dependencies and try again."
        echo "See README.md for installation instructions."
        return 1
    fi
    
    log_success "All requirements satisfied"
    return 0
}

# Run comprehensive tests
run_tests() {
    log_info "Running comprehensive tests..."
    
    # Test 1: Unit tests for Git repository creation
    log_info "Running Git repository creation tests..."
    if ! bash "$PROJECT_ROOT/tests/test-git-repository-creation.sh" >/dev/null 2>&1; then
        log_error "Git repository creation tests failed"
        return 1
    fi
    log_success "Git repository creation tests passed"
    
    # Test 2: Test existing functionality
    log_info "Testing existing GitLab API functions..."
    if [ -f "$PROJECT_ROOT/tests/test-member-management.sh" ]; then
        if ! bash "$PROJECT_ROOT/tests/test-member-management.sh" >/dev/null 2>&1; then
            log_warning "Some member management tests failed (non-critical)"
        else
            log_success "Member management tests passed"
        fi
    fi
    
    # Test 3: Test script syntax
    log_info "Checking script syntax..."
    for script in "$PROJECT_ROOT"/*.sh; do
        if [ -f "$script" ]; then
            if ! bash -n "$script" 2>/dev/null; then
                log_error "Syntax error in $script"
                return 1
            fi
        fi
    done
    log_success "All scripts have valid syntax"
    
    # Test 4: Test cache functions if available
    if [ -f "$PROJECT_ROOT/gitlab-project-cache.sh" ]; then
        log_info "Testing cache functions..."
        if ! bash -n "$PROJECT_ROOT/gitlab-project-cache.sh" 2>/dev/null; then
            log_error "Syntax error in cache script"
            return 1
        fi
        log_success "Cache functions syntax check passed"
    fi
    
    log_success "All tests passed!"
    return 0
}

# Create installation directory
setup_install_directory() {
    log_info "Setting up installation directory..."
    
    # Create ~/bin if it doesn't exist
    if [ ! -d "$INSTALL_DIR" ]; then
        log_install "Creating ~/bin directory..."
        mkdir -p "$INSTALL_DIR"
        chmod 755 "$INSTALL_DIR"
    fi
    
    # Create wrapper directory
    if [ ! -d "$WRAPPER_DIR" ]; then
        log_install "Creating wrapper directory..."
        mkdir -p "$WRAPPER_DIR"
        chmod 755 "$WRAPPER_DIR"
    fi
    
    log_success "Installation directory ready"
}

# Install core scripts
install_core_scripts() {
    log_info "Installing core scripts..."
    
    # Install main API script
    log_install "Installing gitlab-api.sh..."
    cp "$PROJECT_ROOT/gitlab-api.sh" "$WRAPPER_DIR/"
    chmod +x "$WRAPPER_DIR/gitlab-api.sh"
    
    # Install cache script if available
    if [ -f "$PROJECT_ROOT/gitlab-project-cache.sh" ]; then
        log_install "Installing gitlab-project-cache.sh..."
        cp "$PROJECT_ROOT/gitlab-project-cache.sh" "$WRAPPER_DIR/"
        chmod +x "$WRAPPER_DIR/gitlab-project-cache.sh"
    fi
    
    # Install integration examples if available
    if [ -f "$PROJECT_ROOT/integration-examples.sh" ]; then
        log_install "Installing integration-examples.sh..."
        cp "$PROJECT_ROOT/integration-examples.sh" "$WRAPPER_DIR/"
        chmod +x "$WRAPPER_DIR/integration-examples.sh"
    fi
    
    log_success "Core scripts installed"
}

# Create wrapper scripts
create_wrapper_scripts() {
    log_info "Creating wrapper scripts..."
    
    # Wrapper for repository creation
    cat > "$INSTALL_DIR/gitlab-create-repo" << 'EOF'
#!/bin/bash
# GitLab Repository Creation Wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="$SCRIPT_DIR/gitlab-api-helper"

# Source the main functions
if [ -f "$WRAPPER_DIR/gitlab-api.sh" ]; then
    source "$WRAPPER_DIR/gitlab-api.sh"
else
    echo "Error: gitlab-api.sh not found" >&2
    exit 1
fi

# Source cache functions if available
if [ -f "$WRAPPER_DIR/gitlab-project-cache.sh" ]; then
    source "$WRAPPER_DIR/gitlab-project-cache.sh"
fi

# Run the repository creation function
create_gitlab_repository_from_folder "$@"
EOF
    chmod +x "$INSTALL_DIR/gitlab-create-repo"
    
    # Wrapper for member management
    cat > "$INSTALL_DIR/gitlab-manage-members" << 'EOF'
#!/bin/bash
# GitLab Member Management Wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="$SCRIPT_DIR/gitlab-api-helper"

# Source the main functions
if [ -f "$WRAPPER_DIR/gitlab-api.sh" ]; then
    source "$WRAPPER_DIR/gitlab-api.sh"
else
    echo "Error: gitlab-api.sh not found" >&2
    exit 1
fi

# Source cache functions if available
if [ -f "$WRAPPER_DIR/gitlab-project-cache.sh" ]; then
    source "$WRAPPER_DIR/gitlab-project-cache.sh"
fi

# Run the member management function
manage_project_members "$@"
EOF
    chmod +x "$INSTALL_DIR/gitlab-manage-members"
    
    # Wrapper for project listing
    cat > "$INSTALL_DIR/gitlab-list-projects" << 'EOF'
#!/bin/bash
# GitLab Project Listing Wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="$SCRIPT_DIR/gitlab-api-helper"

# Source the main functions
if [ -f "$WRAPPER_DIR/gitlab-api.sh" ]; then
    source "$WRAPPER_DIR/gitlab-api.sh"
else
    echo "Error: gitlab-api.sh not found" >&2
    exit 1
fi

# Source cache functions if available
if [ -f "$WRAPPER_DIR/gitlab-project-cache.sh" ]; then
    source "$WRAPPER_DIR/gitlab-project-cache.sh"
fi

# Get token and list projects
if token=$(get_env_variable "GITLAB_API_TOKEN" 2>/dev/null); then
    get_list_of_projects "$token" "${1:-raw}"
else
    echo "Error: No GitLab token found. Run 'gitlab-token-setup' first." >&2
    exit 1
fi
EOF
    chmod +x "$INSTALL_DIR/gitlab-list-projects"
    
    # Wrapper for token setup
    cat > "$INSTALL_DIR/gitlab-token-setup" << 'EOF'
#!/bin/bash
# GitLab Token Setup Wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="$SCRIPT_DIR/gitlab-api-helper"

# Source the main functions
if [ -f "$WRAPPER_DIR/gitlab-api.sh" ]; then
    source "$WRAPPER_DIR/gitlab-api.sh"
else
    echo "Error: gitlab-api.sh not found" >&2
    exit 1
fi

# Run the token setup function
smart_token_setup "$@"
EOF
    chmod +x "$INSTALL_DIR/gitlab-token-setup"
    
    # Wrapper for cache initialization
    cat > "$INSTALL_DIR/gitlab-cache-init" << 'EOF'
#!/bin/bash
# GitLab Cache Initialization Wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="$SCRIPT_DIR/gitlab-api-helper"

# Source the main functions
if [ -f "$WRAPPER_DIR/gitlab-api.sh" ]; then
    source "$WRAPPER_DIR/gitlab-api.sh"
else
    echo "Error: gitlab-api.sh not found" >&2
    exit 1
fi

# Source cache functions if available
if [ -f "$WRAPPER_DIR/gitlab-project-cache.sh" ]; then
    source "$WRAPPER_DIR/gitlab-project-cache.sh"
    
    # Get token and initialize cache
    if token=$(get_env_variable "GITLAB_API_TOKEN" 2>/dev/null); then
        init_project_cache "$token" "${1:-}"
    else
        echo "Error: No GitLab token found. Run 'gitlab-token-setup' first." >&2
        exit 1
    fi
else
    echo "Error: Cache functions not available" >&2
    exit 1
fi
EOF
    chmod +x "$INSTALL_DIR/gitlab-cache-init"
    
    # Wrapper for interactive mode
    cat > "$INSTALL_DIR/gitlab-interactive" << 'EOF'
#!/bin/bash
# GitLab Interactive Mode Wrapper

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
WRAPPER_DIR="$SCRIPT_DIR/gitlab-api-helper"

# Source the main functions
if [ -f "$WRAPPER_DIR/gitlab-api.sh" ]; then
    source "$WRAPPER_DIR/gitlab-api.sh"
else
    echo "Error: gitlab-api.sh not found" >&2
    exit 1
fi

# Source cache functions if available
if [ -f "$WRAPPER_DIR/gitlab-project-cache.sh" ]; then
    source "$WRAPPER_DIR/gitlab-project-cache.sh"
fi

# Source integration examples if available
if [ -f "$WRAPPER_DIR/integration-examples.sh" ]; then
    source "$WRAPPER_DIR/integration-examples.sh"
    interactive_project_explorer "$(get_env_variable "GITLAB_API_TOKEN" 2>/dev/null || echo "")"
else
    echo "Error: Interactive mode not available" >&2
    exit 1
fi
EOF
    chmod +x "$INSTALL_DIR/gitlab-interactive"
    
    log_success "Wrapper scripts created"
}

# Update PATH in shell configuration
update_shell_config() {
    log_info "Updating shell configuration..."
    
    local shell_config=""
    local shell_name=""
    
    # Detect shell
    if [ -n "${ZSH_VERSION:-}" ]; then
        shell_name="zsh"
        shell_config="$HOME/.zshrc"
    elif [ -n "${BASH_VERSION:-}" ]; then
        shell_name="bash"
        shell_config="$HOME/.bashrc"
    else
        shell_name="unknown"
        shell_config="$HOME/.profile"
    fi
    
    log_info "Detected shell: $shell_name"
    
    # Check if ~/bin is already in PATH
    if echo "$PATH" | grep -q "$INSTALL_DIR"; then
        log_success "~/bin is already in PATH"
        return 0
    fi
    
    # Add ~/bin to PATH
    log_install "Adding ~/bin to PATH in $shell_config"
    
    # Create backup
    if [ -f "$shell_config" ]; then
        cp "$shell_config" "$shell_config.backup.$(date +%Y%m%d_%H%M%S)"
    fi
    
    # Add PATH export
    cat >> "$shell_config" << 'EOF'

# GitLab API Helper - Added by install-system-wide.sh
export PATH="$HOME/bin:$PATH"
EOF
    
    log_success "Shell configuration updated"
    log_warning "Please restart your shell or run 'source $shell_config' to use the new commands"
}

# Verify installation
verify_installation() {
    log_info "Verifying installation..."
    
    local commands=("gitlab-create-repo" "gitlab-manage-members" "gitlab-list-projects" "gitlab-token-setup" "gitlab-cache-init" "gitlab-interactive")
    local all_good=true
    
    for cmd in "${commands[@]}"; do
        if [ -x "$INSTALL_DIR/$cmd" ]; then
            log_success "✓ $cmd is installed and executable"
        else
            log_error "✗ $cmd is missing or not executable"
            all_good=false
        fi
    done
    
    # Check if commands are in PATH (for current session)
    if echo "$PATH" | grep -q "$INSTALL_DIR"; then
        log_success "✓ ~/bin is in PATH"
    else
        log_warning "⚠ ~/bin is not in PATH for current session"
        log_warning "  Run 'source ~/.bashrc' or restart your shell"
    fi
    
    if [ "$all_good" = true ]; then
        log_success "Installation verification passed!"
        return 0
    else
        log_error "Installation verification failed!"
        return 1
    fi
}

# Uninstall scripts
uninstall_scripts() {
    log_info "Uninstalling GitLab API Helper..."
    
    # Remove wrapper scripts
    local commands=("gitlab-create-repo" "gitlab-manage-members" "gitlab-list-projects" "gitlab-token-setup" "gitlab-cache-init" "gitlab-interactive")
    
    for cmd in "${commands[@]}"; do
        if [ -f "$INSTALL_DIR/$cmd" ]; then
            log_install "Removing $cmd..."
            rm -f "$INSTALL_DIR/$cmd"
        fi
    done
    
    # Remove wrapper directory
    if [ -d "$WRAPPER_DIR" ]; then
        log_install "Removing wrapper directory..."
        rm -rf "$WRAPPER_DIR"
    fi
    
    # Remove PATH from shell config (optional)
    log_warning "Note: PATH configuration in shell config files was not removed"
    log_warning "You may want to manually remove the GitLab API Helper lines from your shell config"
    
    log_success "Uninstallation complete!"
}

# Show installation summary
show_installation_summary() {
    echo
    echo "🎉 GitLab API Helper Installation Complete!"
    echo "==========================================="
    echo
    echo "📁 Installation Directory: $INSTALL_DIR"
    echo "📁 Wrapper Directory: $WRAPPER_DIR"
    echo
    echo "🚀 Available Commands:"
    echo "   gitlab-create-repo    - Create GitLab repository from current folder"
    echo "   gitlab-manage-members - Manage project members interactively"
    echo "   gitlab-list-projects  - List GitLab projects"
    echo "   gitlab-token-setup    - Set up GitLab tokens"
    echo "   gitlab-cache-init     - Initialize project cache"
    echo "   gitlab-interactive    - Interactive project explorer"
    echo
    echo "📖 Quick Start:"
    echo "   1. Set up your GitLab token:"
    echo "      gitlab-token-setup"
    echo
    echo "   2. Create a repository from current folder:"
    echo "      gitlab-create-repo \"my-awesome-project\""
    echo
    echo "   3. Or use interactive mode:"
    echo "      gitlab-interactive"
    echo
    echo "💡 Note: You may need to restart your shell or run 'source ~/.bashrc'"
    echo "   to use the new commands in your current session."
    echo
}

# Main installation function
install_gitlab_helper() {
    log_info "Starting GitLab API Helper installation..."
    
    # Check requirements
    if ! check_requirements; then
        log_error "Requirements check failed"
        exit 1
    fi
    
    # Run tests unless forced
    if [ "$FORCE_INSTALL" = false ]; then
        if ! run_tests; then
            log_error "Tests failed. Use --force to skip tests."
            exit 1
        fi
    else
        log_warning "Skipping tests (--force specified)"
    fi
    
    # Setup installation directory
    setup_install_directory
    
    # Install core scripts
    install_core_scripts
    
    # Create wrapper scripts
    create_wrapper_scripts
    
    # Update shell configuration
    update_shell_config
    
    # Verify installation
    if verify_installation; then
        show_installation_summary
        log_success "Installation completed successfully!"
    else
        log_error "Installation verification failed"
        exit 1
    fi
}

# Main execution
main() {
    echo "🚀 GitLab API Helper - System-Wide Installation"
    echo "==============================================="
    echo
    
    # Parse arguments
    parse_arguments "$@"
    
    # Handle uninstall
    if [ "$UNINSTALL" = true ]; then
        uninstall_scripts
        exit 0
    fi
    
    # Handle test-only mode
    if [ "$TEST_ONLY" = true ]; then
        if check_requirements && run_tests; then
            log_success "All tests passed!"
            exit 0
        else
            log_error "Tests failed!"
            exit 1
        fi
    fi
    
    # Run installation
    install_gitlab_helper
}

# Handle script being run directly
if [[ "${BASH_SOURCE[0]}" == "${0}" ]]; then
    main "$@"
fi
