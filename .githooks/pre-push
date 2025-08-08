#!/bin/bash

# Pre-push Git hook for GitLab API Helper
# Runs comprehensive tests before pushing to remote repository

set -euo pipefail

# Hook parameters
remote="$1"
url="$2"

# Get project root
PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

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

log_error() {
    echo -e "${RED}[ERROR]${NC} $1"
}

# Check if we should skip hooks
if [ "${SKIP_HOOKS:-}" = "true" ] || [ "${NO_VERIFY:-}" = "true" ]; then
    log_info "Push hooks skipped"
    exit 0
fi

log_info "🚀 Running pre-push hook for GitLab API Helper..."
log_info "Remote: $remote"
log_info "URL: $url"

# Read stdin to get the refs being pushed
while read local_ref local_sha remote_ref remote_sha; do
    if [ "$local_sha" = "0000000000000000000000000000000000000000" ]; then
        # Branch is being deleted, nothing to test
        continue
    fi
    
    log_info "Testing push to $remote_ref ($local_sha)"
    
    # Run comprehensive tests
    if [ -x "./hooks/test-runner.sh" ]; then
        log_info "Running full test suite..."
        if ! ./hooks/test-runner.sh; then
            log_error "Test suite failed - push blocked"
            exit 1
        fi
    else
        # Fallback to basic tests
        log_info "Running basic validation..."
        
        # Source and test main functions
        if ! source ./gitlab-api.sh; then
            log_error "Failed to source main library"
            exit 1
        fi
        
        # Test function availability
        for func in input_token get_list_of_projects make_new_project; do
            if ! declare -f "$func" > /dev/null; then
                log_error "Required function '$func' not found"
                exit 1
            fi
        done
    fi
done

log_success "🎉 Pre-push validation completed successfully!"
log_success "✅ Push is ready to proceed"
exit 0

