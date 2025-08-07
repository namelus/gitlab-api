#!/bin/bash

# Git Hooks Setup Script for GitLab API Helper
# Run this script to install Git hooks in your repository

set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
PROJECT_ROOT="$(dirname "$SCRIPT_DIR")"
HOOKS_SOURCE_DIR="$PROJECT_ROOT/.githooks"
HOOKS_TARGET_DIR="$PROJECT_ROOT/.git/hooks"

echo "🚀 Setting up Git hooks for GitLab API Helper..."

# Check if we're in a Git repository
if [ ! -d "$PROJECT_ROOT/.git" ]; then
    echo "❌ Error: Not in a Git repository root directory"
    exit 1
fi

# Create hooks source directory if it doesn't exist
mkdir -p "$HOOKS_SOURCE_DIR"

# Create the hooks directory structure
mkdir -p "$PROJECT_ROOT/hooks"
mkdir -p "$PROJECT_ROOT/tests"

# Function to create or update a hook
setup_hook() {
    local hook_name="$1"
    local source_file="$HOOKS_SOURCE_DIR/$hook_name"
    local target_file="$HOOKS_TARGET_DIR/$hook_name"
    
    if [ -f "$source_file" ]; then
        echo "📋 Installing $hook_name hook..."
        
        # Remove existing hook if it exists
        [ -f "$target_file" ] && rm "$target_file"
        
        # Create symlink to our hook
        ln -s "../../.githooks/$hook_name" "$target_file"
        
        # Make hook executable
        chmod +x "$source_file"
        
        echo "✅ $hook_name hook installed"
    else
        echo "⚠️  $hook_name hook not found at $source_file"
    fi
}

# Install all available hooks
echo "📦 Installing Git hooks..."
for hook_file in "$HOOKS_SOURCE_DIR"/*; do
    if [ -f "$hook_file" ]; then
        hook_name=$(basename "$hook_file")
        setup_hook "$hook_name"
    fi
done

# Make helper scripts executable
echo "🔧 Setting up helper scripts..."
chmod +x "$PROJECT_ROOT"/hooks/*.sh 2>/dev/null || true
chmod +x "$PROJECT_ROOT"/tests/*.sh 2>/dev/null || true
chmod +x "$PROJECT_ROOT"/gitlab-api.sh 2>/dev/null || true

# Test the setup
echo "🧪 Testing hook setup..."
if [ -x "$HOOKS_TARGET_DIR/pre-commit" ]; then
    echo "✅ Hooks are properly installed and executable"
else
    echo "❌ Hook installation may have failed"
    exit 1
fi

echo ""
echo "🎉 Git hooks setup completed successfully!"
echo ""
echo "📋 Installed hooks:"
ls -la "$HOOKS_TARGET_DIR"/ | grep "^l" | awk '{print "  - " $9}' || echo "  - No hooks found"
echo ""
echo "💡 To test hooks manually:"
echo "  - Test pre-commit: bash .githooks/pre-commit"
echo "  - Test pre-push: bash .githooks/pre-push origin main"
echo "  - Run all tests: bash hooks/test-runner.sh"
echo ""
echo "🚨 Important: These hooks will run automatically before commits and pushes!"

