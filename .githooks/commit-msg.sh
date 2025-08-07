#!/bin/bash

# Commit message validation hook
# Ensures commit messages follow conventional format

commit_regex='^(feat|fix|docs|style|refactor|test|chore)(\(.+\))?: .{1,50}'

if ! grep -qE "$commit_regex" "$1"; then
    echo "❌ Invalid commit message format!"
    echo ""
    echo "Expected format: type(scope): description"
    echo ""
    echo "Types: feat, fix, docs, style, refactor, test, chore"
    echo "Examples:"
    echo "  feat(api): add project creation function"
    echo "  fix(auth): handle token expiration properly"
    echo "  docs: update README with new examples"
    echo ""
    exit 1
fi
