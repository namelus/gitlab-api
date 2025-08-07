#!/bin/bash

# Validation functions for GitLab API Helper Git hooks
# Provides reusable validation logic for testing

set -euo pipefail

# Colors for output
RED='\033[0;31m'
GREEN='\033[0;32m'
YELLOW='\033[1;33m'
BLUE='\033[0;34m'
NC='\033[0m'

# Logging functions
log_info() {
    echo -e "${BLUE}[VALIDATION]${NC} $1"
}

log_success() {
    echo -e "${GREEN}[VALIDATION]${NC} $1"
}

log_warning() {
    echo -e "${YELLOW}[VALIDATION]${NC} $1"
}

log_error() {
    echo -e "${RED}[VALIDATION]${NC} $1"
}

# ============================================================================
# DEPENDENCY VALIDATION
# ============================================================================

validate_system_dependencies() {
    local missing_deps=0
    local required_commands=("bash" "curl" "jq" "sed" "grep" "timeout")
    
    log_info "Checking system dependencies..."
    
    for cmd in "${required_commands[@]}"; do
        if command -v "$cmd" >/dev/null 2>&1; then
            log_success "✓ $cmd: $(command -v "$cmd")"
        else
            log_error "✗ $cmd: NOT FOUND"
            ((missing_deps++))
        fi
    done
    
    if [ $missing_deps -eq 0 ]; then
        log_success "All system dependencies available"
        return 0
    else
        log_error "$missing_deps missing dependencies"
        return 1
    fi
}

validate_shell_version() {
    log_info "Checking Bash version..."
    
    if [ -z "${BASH_VERSION:-}" ]; then
        log_error "Not running in Bash shell"
        return 1
    fi
    
    local major_version="${BASH_VERSION%%.*}"
    if [ "$major_version" -lt 3 ]; then
        log_error "Bash version $BASH_VERSION is too old (require 3.0+)"
        return 1
    fi
    
    log_success "Bash version $BASH_VERSION is compatible"
    return 0
}

# ============================================================================
# SCRIPT VALIDATION
# ============================================================================

validate_script_syntax() {
    local script_file="$1"
    
    log_info "Validating syntax: $script_file"
    
    if [ ! -f "$script_file" ]; then
        log_error "Script file not found: $script_file"
        return 1
    fi
    
    if ! bash -n "$script_file"; then
        log_error "Syntax errors found in $script_file"
        return 1
    fi
    
    log_success "Syntax valid: $script_file"
    return 0
}

validate_script_permissions() {
    local script_file="$1"
    
    log_info "Checking permissions: $script_file"
    
    if [ ! -x "$script_file" ]; then
        log_warning "Script not executable: $script_file"
        chmod +x "$script_file"
        log_success "Made executable: $script_file"
    else
        log_success "Already executable: $script_file"
    fi
    
    return 0
}

validate_all_scripts() {
    local project_root="${1:-$(pwd)}"
    local validation_failed=0
    
    log_info "Validating all shell scripts in $project_root"
    
    # Main library script
    if [ -f "$project_root/gitlab-api.sh" ]; then
        validate_script_syntax "$project_root/gitlab-api.sh" || ((validation_failed++))
        validate_script_permissions "$project_root/gitlab-api.sh"
    fi
    
    # Hook scripts
    for script in "$project_root/hooks"/*.sh; do
        if [ -f "$script" ]; then
            validate_script_syntax "$script" || ((validation_failed++))
            validate_script_permissions "$script"
        fi
    done
    
    # Test scripts
    for script in "$project_root/tests"/*.sh; do
        if [ -f "$script" ]; then
            validate_script_syntax "$script" || ((validation_failed++))
            validate_script_permissions "$script"
        fi
    done
    
    # Git hooks
    for script in "$project_root/.githooks"/*; do
        if [ -f "$script" ]; then
            validate_script_syntax "$script" || ((validation_failed++))
            validate_script_permissions "$script"
        fi
    done
    
    if [ $validation_failed -eq 0 ]; then
        log_success "All scripts validated successfully"
        return 0
    else
        log_error "$validation_failed scripts failed validation"
        return 1
    fi
}

# ============================================================================
# FUNCTION VALIDATION
# ============================================================================

validate_function_exists() {
    local function_name="$1"
    
    if declare -f "$function_name" > /dev/null; then
        log_success "Function exists: $function_name"
        return 0
    else
        log_error "Function not found: $function_name"
        return 1
    fi
}

validate_gitlab_api_functions() {
    local project_root="${1:-$(pwd)}"
    
    log_info "Validating GitLab API function definitions..."
    
    # Source the main library
    if ! source "$project_root/gitlab-api.sh"; then
        log_error "Failed to source gitlab-api.sh"
        return 1
    fi
    
    # Check required functions
    local required_functions=(
        "input_token"
        "update_env_file"
        "get_env_variable"
        "make_new_project"
        "get_list_of_projects"
        "get_list_of_projects_simple"
    )
    
    local missing_functions=0
    for func in "${required_functions[@]}"; do
        if ! validate_function_exists "$func"; then
            ((missing_functions++))
        fi
    done
    
    if [ $missing_functions -eq 0 ]; then
        log_success "All required functions are defined"
        return 0
    else
        log_error "$missing_functions required functions are missing"
        return 1
    fi
}

# ============================================================================
# SECURITY VALIDATION
# ============================================================================

validate_no_hardcoded_secrets() {
    local project_root="${1:-$(pwd)}"
    
    log_info "Scanning for hardcoded secrets..."
    
    # Check for GitLab tokens (excluding documentation)
    local token_files
    token_files=$(find "$project_root" -name "*.sh" -o -name "*.bash" | xargs grep -l "glpat-" 2>/dev/null | grep -v README || true)
    
    if [ -n "$token_files" ]; then
        log_error "Found potential hardcoded GitLab tokens in:"
        echo "$token_files" | while read -r file; do
            log_error "  $file"
        done
        return 1
    fi
    
    # Check for other common secrets
    local secret_patterns=("password=" "secret=" "key=" "token=" "api_key=")
    local secret_found=0
    
    for pattern in "${secret_patterns[@]}"; do
        if find "$project_root" -name "*.sh" -exec grep -l "$pattern" {} \; 2>/dev/null | grep -v README | head -1 >/dev/null; then
            log_warning "Found potential hardcoded secret pattern: $pattern"
            ((secret_found++))
        fi
    done
    
    if [ $secret_found -eq 0 ]; then
        log_success "No hardcoded secrets detected"
        return 0
    else
        log_warning "Found $secret_found potential secret patterns (review manually)"
        return 0  # Warning, not error
    fi
}

validate_file_permissions() {
    local project_root="${1:-$(pwd)}"
    
    log_info "Checking file permissions..."
    
    # Check .env file permissions if it exists
    if [ -f "$HOME/.env" ]; then
        local perms
        perms=$(stat -c %a "$HOME/.env" 2>/dev/null || stat -f %A "$HOME/.env" 2>/dev/null || echo "unknown")
        
        if [ "$perms" = "600" ]; then
            log_success ".env file has correct permissions (600)"
        else
            log_warning ".env file permissions are $perms (should be 600)"
        fi
    fi
    
    return 0
}

# ============================================================================
# ENVIRONMENT VALIDATION
# ============================================================================

validate_git_repository() {
    local project_root="${1:-$(pwd)}"
    
    log_info "Validating Git repository..."
    
    if [ ! -d "$project_root/.git" ]; then
        log_error "Not a Git repository: $project_root"
        return 1
    fi
    
    if ! git rev-parse --git-dir >/dev/null 2>&1; then
        log_error "Invalid Git repository"
        return 1
    fi
    
    log_success "Valid Git repository"
    return 0
}

validate_hook_installation() {
    local project_root="${1:-$(pwd)}"
    local hooks_dir="$project_root/.git/hooks"
    
    log_info "Validating Git hook installation..."
    
    local expected_hooks=("pre-commit" "pre-push" "commit-msg" "post-checkout")
    local missing_hooks=0
    
    for hook in "${expected_hooks[@]}"; do
        if [ -x "$hooks_dir/$hook" ]; then
            log_success "Hook installed: $hook"
        else
            log_warning "Hook missing or not executable: $hook"
            ((missing_hooks++))
        fi
    done
    
    if [ $missing_hooks -eq 0 ]; then
        log_success "All Git hooks properly installed"
        return 0
    else
        log_warning "$missing_hooks hooks are missing (run scripts/setup-hooks.sh)"
        return 0  # Warning, not error
    fi
}

# ============================================================================
# MAIN VALIDATION FUNCTION
# ============================================================================

run_full_validation() {
    local project_root="${1:-$(pwd)}"
    local validation_errors=0
    
    log_info "Starting full validation suite..."
    echo "=============================================="
    
    # System validation
    validate_system_dependencies || ((validation_errors++))
    validate_shell_version || ((validation_errors++))
    
    # Script validation  
    validate_all_scripts "$project_root" || ((validation_errors++))
    validate_gitlab_api_functions "$project_root" || ((validation_errors++))
    
    # Security validation
    validate_no_hardcoded_secrets "$project_root" || ((validation_errors++))
    validate_file_permissions "$project_root"
    
    # Environment validation
    validate_git_repository "$project_root" || ((validation_errors++))
    validate_hook_installation "$project_root"
    
    echo "=============================================="
    
    if [ $validation_errors -eq 0 ]; then
        log_success "🎉 Full validation completed successfully!"
        return 0
    else
        log_error "💥 Validation failed with $validation_errors errors"
        return 1
    fi
}

# Allow running this script directly
if [ "${BASH_SOURCE[0]}" = "${0}" ]; then
    run_full_validation "$@"
fi
