#!/usr/bin/env bash
# Example: Batch refactoring across multiple files
set -euo pipefail

WORKDIR="${1:-.}"

claude-agent --workdir "$WORKDIR" run "Find all Python files that use the old 'requests' library
for HTTP calls and migrate them to use 'httpx' with async support.
Update imports, function signatures, and add async/await where needed.
Run the tests after to verify nothing is broken."
