#!/usr/bin/env bash
# tests/test_core.sh - Core utility tests (JSON safety, sanitization)
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")/.." && pwd)"
source "$SCRIPT_DIR/lib/core.sh"

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

echo "=== Core Tests ==="

TMPDIR=$(mktemp -d)

# ── JSON safety tests ────────────────────────────────────────────

# json_create + json_get
json_create "$TMPDIR/test1.json" "name=hello" "count=42" "path=/usr/local"
val=$(json_get "$TMPDIR/test1.json" "name")
assert_eq "json_create and json_get string" "hello" "$val"

val=$(json_get "$TMPDIR/test1.json" "count")
assert_eq "json_get numeric" "42" "$val"

# json_set
json_set "$TMPDIR/test1.json" "name" "world"
val=$(json_get "$TMPDIR/test1.json" "name")
assert_eq "json_set updates value" "world" "$val"

# json_get missing key returns empty
val=$(json_get "$TMPDIR/test1.json" "nonexistent")
assert_eq "json_get missing key" "" "$val"

# JSON injection attempt - single quotes in value
json_create "$TMPDIR/inject1.json" "name=test'; import os; os.system('id'); #"
val=$(json_get "$TMPDIR/inject1.json" "name")
assert_eq "json_create blocks injection" "test'; import os; os.system('id'); #" "$val"

# JSON injection attempt - special characters in key
json_set "$TMPDIR/inject1.json" "key with spaces" "value"
val=$(json_get "$TMPDIR/inject1.json" "key with spaces")
assert_eq "json handles special chars in key" "value" "$val"

# ── Sanitize tests ───────────────────────────────────────────────
assert_eq "sanitize normal string" "hello-world_1.0" "$(sanitize 'hello-world_1.0')"
assert_eq "sanitize removes quotes" "test" "$(sanitize "te'st")"
assert_eq "sanitize removes semicolons" "testrm-rf" "$(sanitize "test;rm -rf /")"
assert_eq "sanitize empty input" "" "$(sanitize "")"

# ── UUID test ────────────────────────────────────────────────────
UUID=$(gen_uuid)
assert_eq "gen_uuid returns 36 chars" "36" "${#UUID}"
assert_eq "gen_uuid has dashes" "true" "$([[ "$UUID" == *-* ]] && echo true || echo false)"

# ── json_parse from stdin ────────────────────────────────────────
val=$(echo '{"result":"hello world","cost_usd":0.05}' | json_parse "result")
assert_eq "json_parse extracts result" "hello world" "$val"

val=$(echo '{"result":"hello","cost_usd":0.05}' | json_parse "cost_usd")
assert_eq "json_parse extracts number" "0.05" "$val"

# ── json_is_error ────────────────────────────────────────────────
rc=0
echo '{"is_error":true}' | json_is_error || rc=$?
assert_eq "json_is_error detects error" "0" "$rc"

rc=0
echo '{"is_error":false}' | json_is_error || rc=$?
assert_eq "json_is_error detects non-error" "1" "$rc"

# Cleanup
rm -rf "$TMPDIR"

echo ""
echo "Results: ${PASS} passed, ${FAIL} failed"
[[ $FAIL -eq 0 ]] && exit 0 || exit 1
