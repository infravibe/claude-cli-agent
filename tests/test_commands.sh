#!/usr/bin/env bash
# tests/test_commands.sh - CLI integration tests (no API key needed)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
CLAUDE_AGENT="$SCRIPT_DIR/claude-agent"

PASS=0
FAIL=0

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "  \033[0;32mPASS\033[0m $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  \033[0;31mFAIL\033[0m $desc: output does not contain '$expected'"
        FAIL=$((FAIL + 1))
    fi
}

assert_exit() {
    local desc="$1" expected="$2"
    shift 2
    local rc=0
    "$@" </dev/null &>/dev/null || rc=$?
    if [[ "$rc" == "$expected" ]]; then
        echo -e "  \033[0;32mPASS\033[0m $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  \033[0;31mFAIL\033[0m $desc: expected exit $expected, got $rc"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Command Tests ==="

# Help
OUTPUT=$("$CLAUDE_AGENT" --help 2>&1)
assert_contains "help shows USAGE" "USAGE" "$OUTPUT"
assert_contains "help shows run command" "run" "$OUTPUT"
assert_contains "help shows cowork command" "cowork" "$OUTPUT"
assert_contains "help shows model options" "--model" "$OUTPUT"
assert_contains "help shows max-budget" "--max-budget" "$OUTPUT"
assert_contains "help shows effort" "--effort" "$OUTPUT"

# Version
OUTPUT=$("$CLAUDE_AGENT" version 2>&1)
assert_contains "version shows tool name" "claude-agent" "$OUTPUT"
assert_contains "version shows v2" "v2.0.0" "$OUTPUT"

# Config
OUTPUT=$("$CLAUDE_AGENT" config show 2>&1)
assert_contains "config shows model section" "Model" "$OUTPUT"
assert_contains "config shows permissions" "Skip Permissions" "$OUTPUT"
assert_contains "config shows budget" "Max Budget" "$OUTPUT"

# Run without prompt
assert_exit "run without prompt exits 1" 1 "$CLAUDE_AGENT" run

# Cowork without prompt
assert_exit "cowork without prompt exits 1" 1 "$CLAUDE_AGENT" cowork

# Cowork help
OUTPUT=$("$CLAUDE_AGENT" cowork --help 2>&1)
assert_contains "cowork help shows workflow" "PLAN" "$OUTPUT"
assert_contains "cowork help shows retries" "--retries" "$OUTPUT"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
