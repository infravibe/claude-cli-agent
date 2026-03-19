#!/usr/bin/env bash
# tests/test_session.sh - Session management tests
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"
source "$SCRIPT_DIR/lib/config.sh"
source "$SCRIPT_DIR/lib/session.sh"

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

echo "=== Session Tests ==="

# Setup temp session dir
TMPDIR=$(mktemp -d)
CFG_SESSION_DIR="$TMPDIR/sessions"
CFG_WORKDIR="/tmp"

# Test create
SESSION_ID=$(session_create "test-session")
assert_eq "create returns UUID" "true" "$([[ ${#SESSION_ID} -ge 36 ]] && echo true || echo false)"

file_exists="false"
[[ -f "$CFG_SESSION_DIR/$SESSION_ID.json" ]] && file_exists="true"
assert_eq "session file created" "true" "$file_exists"

# Test get
OUTPUT=$(session_get "$SESSION_ID")
is_json="false"
echo "$OUTPUT" | python3 -c 'import json,sys; json.load(sys.stdin)' 2>/dev/null && is_json="true"
assert_eq "get returns valid JSON" "true" "$is_json"

# Test name sanitization (no semicolons, quotes, spaces, slashes)
SAFE_ID=$(session_create "evil';rm -rf /;'name")
safe_name=$(json_get "$CFG_SESSION_DIR/$SAFE_ID.json" "name")
assert_eq "name has no semicolons" "true" "$([[ "$safe_name" != *";"* ]] && echo true || echo false)"
assert_eq "name has no quotes" "true" "$([[ "$safe_name" != *"'"* ]] && echo true || echo false)"
assert_eq "name has no slashes" "true" "$([[ "$safe_name" != *"/"* ]] && echo true || echo false)"

# Test resolve by name
RESOLVED=$(session_resolve "test-session")
assert_eq "resolve by name" "$SESSION_ID" "$RESOLVED"

# Test resolve by ID
RESOLVED=$(session_resolve "$SESSION_ID")
assert_eq "resolve by ID" "$SESSION_ID" "$RESOLVED"

# Test increment turns
session_increment_turns "$SESSION_ID"
TURNS=$(json_get "$CFG_SESSION_DIR/$SESSION_ID.json" "turns")
assert_eq "increment turns to 1" "1" "$TURNS"

session_increment_turns "$SESSION_ID"
TURNS=$(json_get "$CFG_SESSION_DIR/$SESSION_ID.json" "turns")
assert_eq "increment turns to 2" "2" "$TURNS"

# Test update
session_update "$SESSION_ID" "status" "completed"
STATUS=$(json_get "$CFG_SESSION_DIR/$SESSION_ID.json" "status")
assert_eq "update sets status" "completed" "$STATUS"

# Test delete
session_delete "$SESSION_ID" 2>/dev/null
file_gone="true"
[[ -f "$CFG_SESSION_DIR/$SESSION_ID.json" ]] && file_gone="false"
assert_eq "delete removes file" "true" "$file_gone"

# Cleanup
rm -rf "$TMPDIR"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
