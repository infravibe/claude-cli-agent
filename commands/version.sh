#!/usr/bin/env bash
# commands/version.sh - Version information

cmd_version() {
    echo "claude-agent v${CLAUDE_AGENT_VERSION}"
    if command -v claude &>/dev/null; then
        local claude_ver
        claude_ver=$(claude --version 2>/dev/null || echo 'unknown')
        echo "claude-code: $claude_ver"
    else
        echo "claude-code: not installed"
    fi
    echo "bash: ${BASH_VERSION}"
    echo "python3: $(python3 --version 2>/dev/null | awk '{print $2}' || echo 'not installed')"
    echo "node: $(node --version 2>/dev/null || echo 'not installed')"
}
