#!/usr/bin/env bash
# commands/run.sh - One-shot prompt execution

cmd_run() {
    local prompt=""
    local positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -f|--file)
                [[ -n "${2:-}" ]] || die "Missing argument for --file"
                [[ -f "$2" ]] || die "File not found: $2"
                [[ -r "$2" ]] || die "File not readable: $2"
                prompt="$(cat "$2")" || die "Failed to read file: $2"
                shift 2
                ;;
            -)
                prompt="$(cat)"
                shift
                ;;
            -h|--help|help)
                cmd_run_help
                return 0
                ;;
            --)
                shift
                positional+=("$@")
                break
                ;;
            -*)
                die "Unknown flag for 'run': $1. Use 'claude-agent run --help' for usage."
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    # Prompt from positional args or piped stdin
    if [[ -z "$prompt" ]]; then
        if [[ ${#positional[@]} -gt 0 ]]; then
            prompt="${positional[*]}"
        elif [[ ! -t 0 ]]; then
            prompt="$(cat)"
        fi
    fi

    [[ -n "$prompt" ]] || die "No prompt provided. Usage: claude-agent run <prompt> | claude-agent run -f <file> | echo 'prompt' | claude-agent run -"

    claude_check
    config_validate

    claude_exec "$prompt"
}

cmd_run_help() {
    cat <<'EOF'
Usage: claude-agent run [OPTIONS] <PROMPT>

Execute a one-shot prompt with Claude Code.

Arguments:
  <PROMPT>              The prompt/task for Claude (can be multiple words)

Options:
  -f, --file <PATH>     Read prompt from a file
  -                     Read prompt from stdin
  -h, --help            Show this help

Examples:
  claude-agent run "fix the bug in main.py"
  claude-agent run -f task.md
  echo "explain this code" | claude-agent run -
  git diff | claude-agent run "review this diff"
  claude-agent --model opus run "refactor the auth module"
  claude-agent --output json run "list all functions" | jq '.result'
EOF
}
