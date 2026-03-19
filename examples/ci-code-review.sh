#!/usr/bin/env bash
# Example: Automated code review in CI pipeline
# Add this to your CI workflow (GitHub Actions, GitLab CI, etc.)
set -euo pipefail

# Get the diff for the current PR/MR
DIFF=$(git diff origin/main...HEAD)

if [[ -z "$DIFF" ]]; then
    echo "No changes to review."
    exit 0
fi

# Run code review
echo "$DIFF" | claude-agent --model sonnet run "Review this git diff. Focus on:
1. Bugs and logic errors
2. Security vulnerabilities
3. Performance issues
4. Code style violations

Be concise. Only flag real issues, not style preferences."
