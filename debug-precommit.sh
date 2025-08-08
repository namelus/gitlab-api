#!/bin/bash

# Debug script to test what's happening with your pre-commit hook

echo "🔍 Testing pre-commit hook behavior..."

# Test 1: Run the hook manually with debug output
echo "=========================================="
echo "Test 1: Running pre-commit hook manually"
echo "=========================================="
DEBUG_MODE=true bash .githooks/pre-commit

# Test 2: Check if the hook is actually the issue
echo ""
echo "=========================================="
echo "Test 2: Git commit status check"  
echo "=========================================="
echo "Git status:"
git status --porcelain

echo ""
echo "Staged files:"
git diff --cached --name-only

# Test 3: Try a quick commit with no-verify to see what happens
echo ""
echo "=========================================="
echo "Test 3: Testing commit without hooks"
echo "=========================================="
echo "This would commit without running hooks:"
echo "git commit --no-verify -m 'test commit'"

echo ""
echo "🤔 Analysis:"
echo "- If Test 1 completes fully, the hook itself works"
echo "- If Test 1 hangs, there's an issue in the hook logic"
echo "- Check the staged files to make sure they're what you expect"