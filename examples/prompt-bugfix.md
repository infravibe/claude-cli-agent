# Task: Find and fix bugs

Scan the entire /workspace/ directory for:

1. Syntax errors in any Python/JavaScript/TypeScript files
2. Broken imports or missing dependencies
3. Failing tests — run them and fix whatever fails
4. Linting errors — install and run the appropriate linter (ruff for Python, eslint for JS/TS)

For each issue found:
- Fix the actual bug (don't just suppress warnings)
- Run the tests again to confirm the fix works

Verify: all tests pass, no linting errors remain
