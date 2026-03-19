#!/usr/bin/env bash
# commands/session.sh - Session lifecycle management

cmd_session() {
    local subcmd="${1:-list}"
    shift || true

    case "$subcmd" in
        list|ls)
            session_list
            ;;
        show|info)
            [[ -n "${1:-}" ]] || die "Usage: claude-agent session show <SESSION_ID>"
            session_get "$1"
            ;;
        delete|rm)
            [[ -n "${1:-}" ]] || die "Usage: claude-agent session delete <SESSION_ID>"
            session_delete "$1"
            ;;
        help|--help|-h)
            cmd_session_help
            ;;
        *)
            die "Unknown session command: $subcmd. Use 'claude-agent session help' for usage."
            ;;
    esac
}

cmd_session_help() {
    cat <<'EOF'
Usage: claude-agent session <COMMAND>

Manage conversation sessions.

Commands:
  list (ls)             List all sessions
  show (info) <ID>      Show session details
  delete (rm) <ID>      Delete a session

Examples:
  claude-agent session list
  claude-agent session show abc-123-def
  claude-agent session delete abc-123-def
EOF
}
