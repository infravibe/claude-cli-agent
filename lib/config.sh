#!/usr/bin/env bash
# config.sh - Configuration management
# Precedence: CLI flags > env vars > config file > defaults

CLAUDE_AGENT_CONFIG_DIR="${CLAUDE_AGENT_CONFIG_DIR:-$HOME/.config/claude-agent}"
CLAUDE_AGENT_CONFIG_FILE="${CLAUDE_AGENT_CONFIG:-$CLAUDE_AGENT_CONFIG_DIR/config.env}"

# Set defaults
config_defaults() {
    CFG_API_KEY=""
    CFG_MODEL=""
    CFG_OUTPUT="text"
    CFG_TOOLS=""
    CFG_DISALLOWED_TOOLS=""
    CFG_MAX_TURNS=""
    CFG_MAX_BUDGET_USD=""
    CFG_SYSTEM_PROMPT=""
    CFG_SYSTEM_PROMPT_FILE=""
    CFG_APPEND_SYSTEM_PROMPT=""
    CFG_APPEND_SYSTEM_PROMPT_FILE=""
    CFG_SESSION_DIR="$CLAUDE_AGENT_CONFIG_DIR/sessions"
    CFG_SKIP_PERMISSIONS="true"
    CFG_PERMISSION_MODE=""
    CFG_WORKDIR="$(pwd)"
    CFG_ADD_DIRS=""
    CFG_VERBOSE="false"
    CFG_DEBUG=""
    CFG_MCP_CONFIG=""
    CFG_CONTINUE=""
    CFG_RESUME=""
    CFG_SESSION_ID=""
    CFG_SESSION_NAME=""
    CFG_FORK_SESSION=""
    CFG_NO_SESSION_PERSISTENCE=""
    CFG_EFFORT=""
    CFG_FALLBACK_MODEL=""
    CFG_JSON_SCHEMA=""
    CFG_INPUT_FORMAT=""
    CFG_SETTINGS=""
    CFG_TIMEOUT=""
    CFG_COWORK_RETRIES="3"
}

# Load config file (simple KEY=VALUE format)
config_load_file() {
    if [[ -f "$CLAUDE_AGENT_CONFIG_FILE" ]]; then
        log_debug "Loading config from $CLAUDE_AGENT_CONFIG_FILE"
        # Only load lines that match CFG_* or ANTHROPIC_* or CLAUDE_AGENT_* patterns
        while IFS='=' read -r key value; do
            # Skip comments and empty lines
            [[ "$key" =~ ^[[:space:]]*# ]] && continue
            [[ -z "$key" ]] && continue
            # Strip leading/trailing whitespace
            key=$(echo "$key" | xargs)
            value=$(echo "$value" | sed 's/^["'"'"']//;s/["'"'"']$//')
            case "$key" in
                CFG_*|ANTHROPIC_API_KEY|CLAUDE_AGENT_*)
                    export "$key=$value" 2>/dev/null || true
                    ;;
            esac
        done < "$CLAUDE_AGENT_CONFIG_FILE"
    fi
}

# Load env vars (override config file)
config_load_env() {
    [[ -n "${ANTHROPIC_API_KEY:-}" ]]                    && CFG_API_KEY="$ANTHROPIC_API_KEY" || true
    [[ -n "${CLAUDE_AGENT_MODEL:-}" ]]                   && CFG_MODEL="$CLAUDE_AGENT_MODEL" || true
    [[ -n "${CLAUDE_AGENT_OUTPUT:-}" ]]                  && CFG_OUTPUT="$CLAUDE_AGENT_OUTPUT" || true
    [[ -n "${CLAUDE_AGENT_TOOLS:-}" ]]                   && CFG_TOOLS="$CLAUDE_AGENT_TOOLS" || true
    [[ -n "${CLAUDE_AGENT_DISALLOWED_TOOLS:-}" ]]        && CFG_DISALLOWED_TOOLS="$CLAUDE_AGENT_DISALLOWED_TOOLS" || true
    [[ -n "${CLAUDE_AGENT_MAX_TURNS:-}" ]]               && CFG_MAX_TURNS="$CLAUDE_AGENT_MAX_TURNS" || true
    [[ -n "${CLAUDE_AGENT_MAX_BUDGET_USD:-}" ]]          && CFG_MAX_BUDGET_USD="$CLAUDE_AGENT_MAX_BUDGET_USD" || true
    [[ -n "${CLAUDE_AGENT_SYSTEM_PROMPT:-}" ]]           && CFG_SYSTEM_PROMPT="$CLAUDE_AGENT_SYSTEM_PROMPT" || true
    [[ -n "${CLAUDE_AGENT_SESSION_DIR:-}" ]]             && CFG_SESSION_DIR="$CLAUDE_AGENT_SESSION_DIR" || true
    [[ -n "${CLAUDE_AGENT_SKIP_PERMISSIONS:-}" ]]        && CFG_SKIP_PERMISSIONS="$CLAUDE_AGENT_SKIP_PERMISSIONS" || true
    [[ -n "${CLAUDE_AGENT_PERMISSION_MODE:-}" ]]         && CFG_PERMISSION_MODE="$CLAUDE_AGENT_PERMISSION_MODE" || true
    [[ -n "${CLAUDE_AGENT_WORKDIR:-}" ]]                 && CFG_WORKDIR="$CLAUDE_AGENT_WORKDIR" || true
    [[ -n "${CLAUDE_AGENT_VERBOSE:-}" ]]                 && CFG_VERBOSE="$CLAUDE_AGENT_VERBOSE" || true
    [[ -n "${CLAUDE_AGENT_MCP_CONFIG:-}" ]]              && CFG_MCP_CONFIG="$CLAUDE_AGENT_MCP_CONFIG" || true
    [[ -n "${CLAUDE_AGENT_EFFORT:-}" ]]                  && CFG_EFFORT="$CLAUDE_AGENT_EFFORT" || true
    [[ -n "${CLAUDE_AGENT_FALLBACK_MODEL:-}" ]]          && CFG_FALLBACK_MODEL="$CLAUDE_AGENT_FALLBACK_MODEL" || true
    [[ -n "${CLAUDE_AGENT_TIMEOUT:-}" ]]                 && CFG_TIMEOUT="$CLAUDE_AGENT_TIMEOUT" || true
    [[ -n "${CLAUDE_AGENT_COWORK_RETRIES:-}" ]]          && CFG_COWORK_RETRIES="$CLAUDE_AGENT_COWORK_RETRIES" || true
    [[ -n "${CLAUDE_AGENT_NO_SESSION_PERSISTENCE:-}" ]]  && CFG_NO_SESSION_PERSISTENCE="$CLAUDE_AGENT_NO_SESSION_PERSISTENCE" || true
}

# Full config load pipeline
load_config() {
    config_defaults
    config_load_file
    config_load_env
}

# Validate critical config before execution
config_validate() {
    # Validate output format
    case "${CFG_OUTPUT}" in
        text|json|stream-json) ;;
        *) die "Invalid output format: $CFG_OUTPUT (must be text, json, or stream-json)" ;;
    esac

    # Validate effort if set
    if [[ -n "$CFG_EFFORT" ]]; then
        case "$CFG_EFFORT" in
            low|medium|high|max) ;;
            *) die "Invalid effort: $CFG_EFFORT (must be low, medium, high, or max)" ;;
        esac
    fi

    # Validate permission mode if set
    if [[ -n "$CFG_PERMISSION_MODE" ]]; then
        case "$CFG_PERMISSION_MODE" in
            default|acceptEdits|plan|dontAsk|bypassPermissions) ;;
            *) die "Invalid permission mode: $CFG_PERMISSION_MODE" ;;
        esac
    fi
}

# Save a config value persistently
config_set() {
    local key="$1" value="$2"
    mkdir -p "$(dirname "$CLAUDE_AGENT_CONFIG_FILE")" || die "Cannot create config directory"

    # Remove existing line for this key, then append
    if [[ -f "$CLAUDE_AGENT_CONFIG_FILE" ]]; then
        local tmp
        tmp=$(grep -vF "${key}=" "$CLAUDE_AGENT_CONFIG_FILE" 2>/dev/null || true)
        printf '%s\n' "$tmp" > "$CLAUDE_AGENT_CONFIG_FILE"
    fi
    printf '%s=%s\n' "$key" "$value" >> "$CLAUDE_AGENT_CONFIG_FILE"
    log_info "Set ${key} in $CLAUDE_AGENT_CONFIG_FILE"
}

# Print resolved configuration
config_show() {
    local masked_key
    if [[ -n "$CFG_API_KEY" ]]; then
        masked_key="${CFG_API_KEY:0:8}...${CFG_API_KEY: -4}"
    else
        masked_key="(not set)"
    fi

    cat >&2 <<EOF
${BOLD}claude-agent v${CLAUDE_AGENT_VERSION} configuration${RESET}

  ${BOLD}Authentication${RESET}
    API Key:              $masked_key

  ${BOLD}Model${RESET}
    Model:                ${CFG_MODEL:-"(default)"}
    Effort:               ${CFG_EFFORT:-"(default)"}
    Fallback Model:       ${CFG_FALLBACK_MODEL:-"(none)"}

  ${BOLD}Output${RESET}
    Format:               $CFG_OUTPUT
    JSON Schema:          ${CFG_JSON_SCHEMA:+(set)}${CFG_JSON_SCHEMA:-(none)}

  ${BOLD}Tools & Permissions${RESET}
    Allowed Tools:        ${CFG_TOOLS:-"(all)"}
    Disallowed Tools:     ${CFG_DISALLOWED_TOOLS:-"(none)"}
    Skip Permissions:     $CFG_SKIP_PERMISSIONS
    Permission Mode:      ${CFG_PERMISSION_MODE:-"(default)"}

  ${BOLD}Execution${RESET}
    Max Turns:            ${CFG_MAX_TURNS:-"(unlimited)"}
    Max Budget USD:       ${CFG_MAX_BUDGET_USD:-"(unlimited)"}
    Timeout:              ${CFG_TIMEOUT:-"(none)"}
    Cowork Retries:       $CFG_COWORK_RETRIES

  ${BOLD}Context${RESET}
    System Prompt:        ${CFG_SYSTEM_PROMPT:+(set)}${CFG_SYSTEM_PROMPT:-(none)}
    System Prompt File:   ${CFG_SYSTEM_PROMPT_FILE:-"(none)"}
    MCP Config:           ${CFG_MCP_CONFIG:-"(none)"}

  ${BOLD}Session${RESET}
    Session Dir:          $CFG_SESSION_DIR
    No Persistence:       ${CFG_NO_SESSION_PERSISTENCE:-"false"}

  ${BOLD}Paths${RESET}
    Working Dir:          $CFG_WORKDIR
    Additional Dirs:      ${CFG_ADD_DIRS:-"(none)"}
    Config File:          $CLAUDE_AGENT_CONFIG_FILE

  ${BOLD}Debug${RESET}
    Verbose:              $CFG_VERBOSE
    Debug:                ${CFG_DEBUG:-"(off)"}
EOF
}
