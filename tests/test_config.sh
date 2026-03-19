#!/usr/bin/env bash
# tests/test_config.sh - Configuration tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/config.sh"

PASS=0
FAIL=0

assert_eq() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$expected" == "$actual" ]]; then
        echo -e "  ${GREEN}PASS${RESET} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${RESET} $desc: expected '$expected', got '$actual'"
        FAIL=$((FAIL + 1))
    fi
}

echo "=== Config Tests ==="

# Test defaults
config_defaults
assert_eq "default output is text" "text" "$CFG_OUTPUT"
assert_eq "default skip_permissions is true" "true" "$CFG_SKIP_PERMISSIONS"
assert_eq "default verbose is false" "false" "$CFG_VERBOSE"
assert_eq "default cowork retries is 3" "3" "$CFG_COWORK_RETRIES"
assert_eq "default effort is empty" "" "$CFG_EFFORT"
assert_eq "default max_budget_usd is empty" "" "$CFG_MAX_BUDGET_USD"

# Test env override
export CLAUDE_AGENT_MODEL="opus"
export CLAUDE_AGENT_OUTPUT="json"
export CLAUDE_AGENT_EFFORT="high"
export CLAUDE_AGENT_MAX_BUDGET_USD="10.00"
config_load_env
assert_eq "env override model" "opus" "$CFG_MODEL"
assert_eq "env override output" "json" "$CFG_OUTPUT"
assert_eq "env override effort" "high" "$CFG_EFFORT"
assert_eq "env override max_budget_usd" "10.00" "$CFG_MAX_BUDGET_USD"
unset CLAUDE_AGENT_MODEL CLAUDE_AGENT_OUTPUT CLAUDE_AGENT_EFFORT CLAUDE_AGENT_MAX_BUDGET_USD

# Test config validation - valid
CFG_OUTPUT="json"
CFG_EFFORT="high"
CFG_PERMISSION_MODE=""
config_validate  # should not die
assert_eq "validation passes for valid config" "0" "0"

# Test config file
TMPDIR=$(mktemp -d)
CLAUDE_AGENT_CONFIG_FILE="$TMPDIR/config.env"
echo 'CFG_MODEL=haiku' > "$CLAUDE_AGENT_CONFIG_FILE"
echo 'CFG_VERBOSE=true' >> "$CLAUDE_AGENT_CONFIG_FILE"
config_defaults
config_load_file
assert_eq "file override model" "haiku" "$CFG_MODEL"
assert_eq "file override verbose" "true" "$CFG_VERBOSE"
rm -rf "$TMPDIR"

# Test config set
TMPDIR=$(mktemp -d)
CLAUDE_AGENT_CONFIG_FILE="$TMPDIR/config.env"
config_set "CLAUDE_AGENT_MODEL" "opus" 2>/dev/null
file_check="false"
[[ -f "$CLAUDE_AGENT_CONFIG_FILE" ]] && file_check="true"
assert_eq "config set creates file" "true" "$file_check"

# Verify content
content=$(cat "$CLAUDE_AGENT_CONFIG_FILE")
assert_eq "config set writes value" "true" "$([[ "$content" == *"CLAUDE_AGENT_MODEL=opus"* ]] && echo true || echo false)"
rm -rf "$TMPDIR"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
