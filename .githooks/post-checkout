#!/bin/bash

# Post-checkout hook - runs after checkout
# Ensures dependencies and setup are current

PROJECT_ROOT="$(git rev-parse --show-toplevel)"
cd "$PROJECT_ROOT"

echo "🔄 Post-checkout setup for GitLab API Helper..."

# Make scripts executable
chmod +x gitlab-api.sh 2>/dev/null || true
chmod +x hooks/*.sh 2>/dev/null || true
chmod +x tests/*.sh 2>/dev/null || true

echo "✅ Post-checkout setup completed"
