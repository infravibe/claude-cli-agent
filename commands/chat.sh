#!/usr/bin/env bash
# commands/chat.sh - Multi-turn session-based conversations

cmd_chat() {
    local session_name=""
    local prompt=""
    local positional=()

    while [[ $# -gt 0 ]]; do
        case "$1" in
            -s|--session)
                session_name="$2"
                shift 2
                ;;
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
                cmd_chat_help
                return 0
                ;;
            --)
                shift
                positional+=("$@")
                break
                ;;
            -*)
                die "Unknown flag for 'chat': $1. Use 'claude-agent chat --help' for usage."
                ;;
            *)
                positional+=("$1")
                shift
                ;;
        esac
    done

    if [[ -z "$prompt" && ${#positional[@]} -gt 0 ]]; then
        prompt="${positional[*]}"
    fi

    [[ -n "$prompt" ]] || die "No prompt provided. Usage: claude-agent chat [--session <name>] <prompt>"

    claude_check
    config_validate

    # Resolve or create session
    local session_id
    if [[ -n "$session_name" ]]; then
        session_id=$(session_resolve "$session_name" 2>/dev/null) || true
        if [[ -n "$session_id" ]]; then
            log_info "Resuming session: $session_name ($session_id)"
            CFG_RESUME="$session_id"
        else
            log_info "Creating new session: $session_name"
            session_id=$(session_create "$session_name")
            CFG_SESSION_NAME="$session_name"
        fi
    else
        session_id=$(session_create)
        log_info "Created session: $session_id"
    fi

    local rc=0
    claude_exec "$prompt" || rc=$?

    # Update session metadata
    session_increment_turns "$session_id"
    if [[ $rc -ne 0 ]]; then
        session_update "$session_id" "status" "error"
    fi

    log_info "Session: $session_id (use --session to continue)"
    return $rc
}

cmd_chat_help() {
    cat <<'EOF'
Usage: claude-agent chat [OPTIONS] <PROMPT>

Multi-turn conversation with session persistence.

Options:
  -s, --session <NAME>  Name for the session (creates new or resumes existing)
  -f, --file <PATH>     Read prompt from a file
  -                     Read prompt from stdin
  -h, --help            Show this help

Examples:
  claude-agent chat --session myproject "set up the project structure"
  claude-agent chat --session myproject "now add tests for the api"
  claude-agent chat "quick one-off question"

Session Management:
  claude-agent session list              List all sessions
  claude-agent session show <ID>         Show session details
  claude-agent session delete <ID>       Delete a session
EOF
}
