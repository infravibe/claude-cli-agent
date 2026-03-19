#!/usr/bin/env bash
# claude.sh - Claude CLI wrapper
# Reference: https://docs.anthropic.com/en/docs/claude-code/cli-reference

# Exit codes from Claude CLI:
#   0 = success
#   1 = generic error (invalid prompt, network, execution, max turns, budget exceeded)
#   2 = authentication error (missing/invalid API key)
CLAUDE_EXIT_SUCCESS=0
CLAUDE_EXIT_ERROR=1
CLAUDE_EXIT_AUTH_ERROR=2

# Build the claude command argument array from resolved CFG_* variables.
# Sets global CLAUDE_CMD array. Caller must read it after calling.
_claude_build_cmd() {
    local prompt="$1"
    shift || true

    CLAUDE_CMD=(claude -p "$prompt")

    # ── Permissions ────────────────────────────────────────────
    if [[ "$CFG_SKIP_PERMISSIONS" == "true" ]]; then
        CLAUDE_CMD+=(--dangerously-skip-permissions)
    fi

    if [[ -n "${CFG_PERMISSION_MODE:-}" ]]; then
        CLAUDE_CMD+=(--permission-mode "$CFG_PERMISSION_MODE")
    fi

    # ── Model ──────────────────────────────────────────────────
    [[ -n "${CFG_MODEL:-}" ]]          && CLAUDE_CMD+=(--model "$CFG_MODEL")
    [[ -n "${CFG_EFFORT:-}" ]]         && CLAUDE_CMD+=(--effort "$CFG_EFFORT")
    [[ -n "${CFG_FALLBACK_MODEL:-}" ]] && CLAUDE_CMD+=(--fallback-model "$CFG_FALLBACK_MODEL")

    # ── Output ─────────────────────────────────────────────────
    if [[ -n "${CFG_OUTPUT:-}" && "$CFG_OUTPUT" != "text" ]]; then
        CLAUDE_CMD+=(--output-format "$CFG_OUTPUT")
    fi

    [[ -n "${CFG_JSON_SCHEMA:-}" ]] && CLAUDE_CMD+=(--json-schema "$CFG_JSON_SCHEMA")
    [[ -n "${CFG_INPUT_FORMAT:-}" ]] && CLAUDE_CMD+=(--input-format "$CFG_INPUT_FORMAT")

    # ── Tools ──────────────────────────────────────────────────
    if [[ -n "${CFG_TOOLS:-}" ]]; then
        IFS=',' read -ra tools <<< "$CFG_TOOLS"
        for tool in "${tools[@]}"; do
            tool=$(echo "$tool" | xargs)  # trim whitespace
            [[ -n "$tool" ]] && CLAUDE_CMD+=(--allowedTools "$tool")
        done
    fi

    if [[ -n "${CFG_DISALLOWED_TOOLS:-}" ]]; then
        IFS=',' read -ra dtools <<< "$CFG_DISALLOWED_TOOLS"
        for tool in "${dtools[@]}"; do
            tool=$(echo "$tool" | xargs)
            [[ -n "$tool" ]] && CLAUDE_CMD+=(--disallowedTools "$tool")
        done
    fi

    # ── Execution limits ───────────────────────────────────────
    [[ -n "${CFG_MAX_TURNS:-}" ]]      && CLAUDE_CMD+=(--max-turns "$CFG_MAX_TURNS")
    [[ -n "${CFG_MAX_BUDGET_USD:-}" ]] && CLAUDE_CMD+=(--max-budget-usd "$CFG_MAX_BUDGET_USD")

    # ── System prompt ──────────────────────────────────────────
    # --system-prompt and --system-prompt-file are mutually exclusive
    if [[ -n "${CFG_SYSTEM_PROMPT:-}" ]]; then
        CLAUDE_CMD+=(--system-prompt "$CFG_SYSTEM_PROMPT")
    elif [[ -n "${CFG_SYSTEM_PROMPT_FILE:-}" ]]; then
        CLAUDE_CMD+=(--system-prompt-file "$CFG_SYSTEM_PROMPT_FILE")
    fi

    if [[ -n "${CFG_APPEND_SYSTEM_PROMPT:-}" ]]; then
        CLAUDE_CMD+=(--append-system-prompt "$CFG_APPEND_SYSTEM_PROMPT")
    fi

    if [[ -n "${CFG_APPEND_SYSTEM_PROMPT_FILE:-}" ]]; then
        CLAUDE_CMD+=(--append-system-prompt-file "$CFG_APPEND_SYSTEM_PROMPT_FILE")
    fi

    # ── Session ────────────────────────────────────────────────
    [[ -n "${CFG_RESUME:-}" ]]     && CLAUDE_CMD+=(--resume "$CFG_RESUME")
    [[ -n "${CFG_SESSION_ID:-}" ]] && CLAUDE_CMD+=(--session-id "$CFG_SESSION_ID")
    [[ "${CFG_CONTINUE:-}" == "true" ]] && CLAUDE_CMD+=(--continue)
    [[ "${CFG_FORK_SESSION:-}" == "true" ]] && CLAUDE_CMD+=(--fork-session)
    [[ "${CFG_NO_SESSION_PERSISTENCE:-}" == "true" ]] && CLAUDE_CMD+=(--no-session-persistence)
    [[ -n "${CFG_SESSION_NAME:-}" ]] && CLAUDE_CMD+=(--name "$CFG_SESSION_NAME")

    # ── MCP ────────────────────────────────────────────────────
    [[ -n "${CFG_MCP_CONFIG:-}" ]] && CLAUDE_CMD+=(--mcp-config "$CFG_MCP_CONFIG")

    # ── Working directories ────────────────────────────────────
    if [[ -n "${CFG_ADD_DIRS:-}" ]]; then
        IFS=',' read -ra dirs <<< "$CFG_ADD_DIRS"
        for dir in "${dirs[@]}"; do
            dir=$(echo "$dir" | xargs)
            [[ -n "$dir" ]] && CLAUDE_CMD+=(--add-dir "$dir")
        done
    fi

    # ── Settings ───────────────────────────────────────────────
    [[ -n "${CFG_SETTINGS:-}" ]] && CLAUDE_CMD+=(--settings "$CFG_SETTINGS")

    # ── Debug ──────────────────────────────────────────────────
    [[ "${CFG_VERBOSE:-}" == "true" ]] && CLAUDE_CMD+=(--verbose)
    [[ -n "${CFG_DEBUG:-}" ]] && CLAUDE_CMD+=(--debug "$CFG_DEBUG")
}

# Execute claude with the resolved config.
# Returns claude's exit code. Output goes to stdout.
claude_exec() {
    local prompt="$1"
    shift || true

    _claude_build_cmd "$prompt"

    log_debug "Executing: ${CLAUDE_CMD[*]}"
    log_debug "Working directory: $CFG_WORKDIR"

    local rc=0
    if [[ -n "${CFG_TIMEOUT:-}" ]]; then
        (cd "$CFG_WORKDIR" && run_with_timeout "$CFG_TIMEOUT" "${CLAUDE_CMD[@]}") || rc=$?
    else
        (cd "$CFG_WORKDIR" && "${CLAUDE_CMD[@]}") || rc=$?
    fi

    # Log exit code semantics
    case $rc in
        0) log_debug "Claude exited successfully" ;;
        1) log_warn "Claude exited with error (code 1)" ;;
        2) log_error "Claude authentication error (code 2) - check ANTHROPIC_API_KEY" ;;
        124) log_error "Claude timed out after ${CFG_TIMEOUT}s" ;;
        *) log_warn "Claude exited with code $rc" ;;
    esac

    return $rc
}

# Execute claude and capture output + exit code.
# Sets CLAUDE_OUTPUT and CLAUDE_EXIT_CODE globals.
claude_exec_capture() {
    local prompt="$1"
    shift || true

    _claude_build_cmd "$prompt"

    log_debug "Executing (captured): ${CLAUDE_CMD[*]}"

    CLAUDE_OUTPUT=""
    CLAUDE_EXIT_CODE=0

    local tmpfile
    tmpfile=$(mktemp) || die "Cannot create temp file"

    if [[ -n "${CFG_TIMEOUT:-}" ]]; then
        (cd "$CFG_WORKDIR" && run_with_timeout "$CFG_TIMEOUT" "${CLAUDE_CMD[@]}") > "$tmpfile" 2>&1 || CLAUDE_EXIT_CODE=$?
    else
        (cd "$CFG_WORKDIR" && "${CLAUDE_CMD[@]}") > "$tmpfile" 2>&1 || CLAUDE_EXIT_CODE=$?
    fi

    CLAUDE_OUTPUT=$(cat "$tmpfile")
    rm -f "$tmpfile"

    case $CLAUDE_EXIT_CODE in
        0) log_debug "Claude exited successfully (captured)" ;;
        2) log_error "Authentication error - check ANTHROPIC_API_KEY" ;;
        124) log_error "Claude timed out" ;;
    esac
}

# Execute claude with JSON output and parse the result.
# Sets CLAUDE_RESULT, CLAUDE_SESSION_ID, CLAUDE_COST, CLAUDE_TURNS, CLAUDE_IS_ERROR.
claude_exec_json() {
    local prompt="$1"
    shift || true

    # Force JSON output for this call
    local saved_output="$CFG_OUTPUT"
    CFG_OUTPUT="json"

    _claude_build_cmd "$prompt"
    CFG_OUTPUT="$saved_output"

    log_debug "Executing (JSON): ${CLAUDE_CMD[*]}"

    local tmpfile
    tmpfile=$(mktemp) || die "Cannot create temp file"

    local rc=0
    if [[ -n "${CFG_TIMEOUT:-}" ]]; then
        (cd "$CFG_WORKDIR" && run_with_timeout "$CFG_TIMEOUT" "${CLAUDE_CMD[@]}") > "$tmpfile" 2>&1 || rc=$?
    else
        (cd "$CFG_WORKDIR" && "${CLAUDE_CMD[@]}") > "$tmpfile" 2>&1 || rc=$?
    fi

    # Parse JSON fields
    CLAUDE_RESULT=$(json_parse "result" < "$tmpfile" 2>/dev/null || true)
    CLAUDE_SESSION_ID=$(json_parse "session_id" < "$tmpfile" 2>/dev/null || true)
    CLAUDE_COST=$(json_parse "cost_usd" < "$tmpfile" 2>/dev/null || true)
    CLAUDE_TURNS=$(json_parse "num_turns" < "$tmpfile" 2>/dev/null || true)
    CLAUDE_IS_ERROR="false"
    if cat "$tmpfile" | json_is_error 2>/dev/null; then
        CLAUDE_IS_ERROR="true"
    fi
    CLAUDE_RAW_JSON=$(cat "$tmpfile")

    rm -f "$tmpfile"

    log_debug "Claude JSON result: cost=\$${CLAUDE_COST:-?}, turns=${CLAUDE_TURNS:-?}, error=${CLAUDE_IS_ERROR}"

    return $rc
}

# Check that claude CLI is installed and accessible
claude_check() {
    if ! command -v claude &>/dev/null; then
        die "Claude CLI (claude) is not installed. Run: npm install -g @anthropic-ai/claude-code"
    fi
    log_debug "Claude CLI found: $(command -v claude)"
}

# Verify API key is configured
claude_auth_check() {
    if [[ -z "${CFG_API_KEY:-}" && -z "${ANTHROPIC_API_KEY:-}" ]]; then
        die "ANTHROPIC_API_KEY is not set. Export it or run: claude-agent config set ANTHROPIC_API_KEY <key>" 2
    fi
}
