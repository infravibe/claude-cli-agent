#!/usr/bin/env bash
# tests/test_claude_flags.sh - Verify claude command is built correctly
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/session.sh"
source "$SCRIPT_DIR/lib/claude.sh"

PASS=0
FAIL=0

assert_contains() {
    local desc="$1" expected="$2" actual="$3"
    if [[ "$actual" == *"$expected"* ]]; then
        echo -e "  ${GREEN}PASS${RESET} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${RESET} $desc: does not contain '$expected'"
        echo -e "         got: $actual"
        FAIL=$((FAIL + 1))
    fi
}

assert_not_contains() {
    local desc="$1" unexpected="$2" actual="$3"
    if [[ "$actual" != *"$unexpected"* ]]; then
        echo -e "  ${GREEN}PASS${RESET} $desc"
        PASS=$((PASS + 1))
    else
        echo -e "  ${RED}FAIL${RESET} $desc: should not contain '$unexpected'"
        FAIL=$((FAIL + 1))
    fi
}

# Helper: build command and return as string
build_cmd() {
    _claude_build_cmd "$@"
    echo "${CLAUDE_CMD[*]}"
}

echo "=== Claude Flag Tests ==="

# ── Base command ─────────────────────────────────────────────────
load_config
CMD=$(build_cmd "test prompt")
assert_contains "base has claude -p" "claude -p test prompt" "$CMD"
assert_contains "default skip permissions" "--dangerously-skip-permissions" "$CMD"

# ── Model flags ──────────────────────────────────────────────────
CFG_MODEL="opus"
CMD=$(build_cmd "test")
assert_contains "model flag" "--model opus" "$CMD"
CFG_MODEL=""

CFG_EFFORT="high"
CMD=$(build_cmd "test")
assert_contains "effort flag" "--effort high" "$CMD"
CFG_EFFORT=""

CFG_FALLBACK_MODEL="sonnet"
CMD=$(build_cmd "test")
assert_contains "fallback model flag" "--fallback-model sonnet" "$CMD"
CFG_FALLBACK_MODEL=""

# ── Output flags ─────────────────────────────────────────────────
CFG_OUTPUT="json"
CMD=$(build_cmd "test")
assert_contains "json output format" "--output-format json" "$CMD"
CFG_OUTPUT="text"

CFG_OUTPUT="text"
CMD=$(build_cmd "test")
assert_not_contains "text output omits flag" "--output-format" "$CMD"

CFG_JSON_SCHEMA='{"type":"object"}'
CMD=$(build_cmd "test")
assert_contains "json schema flag" "--json-schema" "$CMD"
CFG_JSON_SCHEMA=""

# ── Tool flags ───────────────────────────────────────────────────
CFG_TOOLS="Bash,Read,Edit"
CMD=$(build_cmd "test")
assert_contains "allowedTools Bash" "--allowedTools Bash" "$CMD"
assert_contains "allowedTools Read" "--allowedTools Read" "$CMD"
assert_contains "allowedTools Edit" "--allowedTools Edit" "$CMD"
CFG_TOOLS=""

CFG_DISALLOWED_TOOLS="WebSearch"
CMD=$(build_cmd "test")
assert_contains "disallowedTools" "--disallowedTools WebSearch" "$CMD"
CFG_DISALLOWED_TOOLS=""

# ── Execution limits ─────────────────────────────────────────────
CFG_MAX_TURNS="5"
CMD=$(build_cmd "test")
assert_contains "max turns flag" "--max-turns 5" "$CMD"
CFG_MAX_TURNS=""

CFG_MAX_BUDGET_USD="10.00"
CMD=$(build_cmd "test")
assert_contains "max budget usd flag" "--max-budget-usd 10.00" "$CMD"
assert_not_contains "no max-turns for budget" "--max-turns 10.00" "$CMD"
CFG_MAX_BUDGET_USD=""

# ── System prompt ────────────────────────────────────────────────
CFG_SYSTEM_PROMPT="You are helpful"
CMD=$(build_cmd "test")
assert_contains "system prompt flag" "--system-prompt" "$CMD"
CFG_SYSTEM_PROMPT=""

CFG_SYSTEM_PROMPT_FILE="/tmp/prompt.txt"
CMD=$(build_cmd "test")
assert_contains "system prompt file flag" "--system-prompt-file /tmp/prompt.txt" "$CMD"
CFG_SYSTEM_PROMPT_FILE=""

CFG_APPEND_SYSTEM_PROMPT="Extra instructions"
CMD=$(build_cmd "test")
assert_contains "append system prompt" "--append-system-prompt" "$CMD"
CFG_APPEND_SYSTEM_PROMPT=""

# ── Session flags ────────────────────────────────────────────────
CFG_RESUME="abc-123"
CMD=$(build_cmd "test")
assert_contains "resume flag" "--resume abc-123" "$CMD"
CFG_RESUME=""

CFG_SESSION_ID="550e8400-e29b-41d4-a716-446655440000"
CMD=$(build_cmd "test")
assert_contains "session-id flag" "--session-id 550e8400" "$CMD"
CFG_SESSION_ID=""

CFG_CONTINUE="true"
CMD=$(build_cmd "test")
assert_contains "continue flag" "--continue" "$CMD"
CFG_CONTINUE=""

CFG_FORK_SESSION="true"
CMD=$(build_cmd "test")
assert_contains "fork session flag" "--fork-session" "$CMD"
CFG_FORK_SESSION=""

CFG_NO_SESSION_PERSISTENCE="true"
CMD=$(build_cmd "test")
assert_contains "no session persistence" "--no-session-persistence" "$CMD"
CFG_NO_SESSION_PERSISTENCE=""

CFG_SESSION_NAME="my-task"
CMD=$(build_cmd "test")
assert_contains "session name flag" "--name my-task" "$CMD"
CFG_SESSION_NAME=""

# ── Permission modes ─────────────────────────────────────────────
CFG_SKIP_PERMISSIONS="false"
CMD=$(build_cmd "test")
assert_not_contains "no skip when disabled" "--dangerously-skip-permissions" "$CMD"
CFG_SKIP_PERMISSIONS="true"

CFG_PERMISSION_MODE="plan"
CMD=$(build_cmd "test")
assert_contains "permission mode flag" "--permission-mode plan" "$CMD"
CFG_PERMISSION_MODE=""

# ── Verbose/debug ────────────────────────────────────────────────
CFG_VERBOSE="true"
CMD=$(build_cmd "test")
assert_contains "verbose flag" "--verbose" "$CMD"
CFG_VERBOSE="false"

CFG_VERBOSE="false"
CMD=$(build_cmd "test")
assert_not_contains "no verbose when false" "--verbose" "$CMD"

CFG_DEBUG="api,hooks"
CMD=$(build_cmd "test")
assert_contains "debug flag" "--debug api,hooks" "$CMD"
CFG_DEBUG=""

# ── MCP and settings ────────────────────────────────────────────
CFG_MCP_CONFIG="/tmp/mcp.json"
CMD=$(build_cmd "test")
assert_contains "mcp config flag" "--mcp-config /tmp/mcp.json" "$CMD"
CFG_MCP_CONFIG=""

CFG_SETTINGS="/tmp/settings.json"
CMD=$(build_cmd "test")
assert_contains "settings flag" "--settings /tmp/settings.json" "$CMD"
CFG_SETTINGS=""

# ── Additional dirs ──────────────────────────────────────────────
CFG_ADD_DIRS="/app,/lib"
CMD=$(build_cmd "test")
assert_contains "add-dir /app" "--add-dir /app" "$CMD"
assert_contains "add-dir /lib" "--add-dir /lib" "$CMD"
CFG_ADD_DIRS=""

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
