#!/usr/bin/env bash
# commands/config.sh - Configuration management

cmd_config() {
    local subcmd="${1:-show}"
    shift || true

    case "$subcmd" in
        show)
            config_show
            ;;
        set)
            [[ -n "${1:-}" && -n "${2:-}" ]] || die "Usage: claude-agent config set <KEY> <VALUE>"
            config_set "$1" "$2"
            ;;
        path)
            echo "$CLAUDE_AGENT_CONFIG_FILE"
            ;;
        help|--help|-h)
            cmd_config_help
            ;;
        *)
            die "Unknown config command: $subcmd"
            ;;
    esac
}

cmd_config_help() {
    cat <<'EOF'
Usage: claude-agent config <COMMAND>

Manage configuration.

Commands:
  show                  Show resolved configuration
  set <KEY> <VALUE>     Set a persistent config value
  path                  Print config file path

Environment Variables:
  ANTHROPIC_API_KEY                 API key (required)
  CLAUDE_AGENT_MODEL                Model (sonnet, opus, haiku)
  CLAUDE_AGENT_EFFORT               Reasoning effort (low, medium, high, max)
  CLAUDE_AGENT_OUTPUT               Output format (text, json, stream-json)
  CLAUDE_AGENT_TOOLS                Comma-separated allowed tools
  CLAUDE_AGENT_DISALLOWED_TOOLS     Comma-separated disallowed tools
  CLAUDE_AGENT_MAX_TURNS            Max agentic turns
  CLAUDE_AGENT_MAX_BUDGET_USD       Max budget in USD
  CLAUDE_AGENT_TIMEOUT              Timeout in seconds
  CLAUDE_AGENT_SKIP_PERMISSIONS     Skip permission prompts (true/false)
  CLAUDE_AGENT_PERMISSION_MODE      Permission mode
  CLAUDE_AGENT_WORKDIR              Working directory
  CLAUDE_AGENT_VERBOSE              Verbose logging (true/false)
  CLAUDE_AGENT_COWORK_RETRIES       Cowork max retries

Examples:
  claude-agent config show
  claude-agent config set CLAUDE_AGENT_MODEL opus
  claude-agent config set ANTHROPIC_API_KEY sk-ant-...
EOF
}
