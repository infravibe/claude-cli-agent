#!/usr/bin/env bash
# install.sh - One-command installer for claude-agent
# Usage: curl -fsSL https://raw.githubusercontent.com/akash/claude-cli-agent/main/install.sh | bash
set -euo pipefail

REPO_URL="https://raw.githubusercontent.com/akash/claude-cli-agent/main"
VERSION="2.0.0"

# Colors
if [[ -t 1 ]]; then
    RED='\033[0;31m' GREEN='\033[0;32m' YELLOW='\033[0;33m'
    BOLD='\033[1m' RESET='\033[0m'
else
    RED='' GREEN='' YELLOW='' BOLD='' RESET=''
fi

info()  { echo -e "${GREEN}[+]${RESET} $*"; }
warn()  { echo -e "${YELLOW}[!]${RESET} $*"; }
error() { echo -e "${RED}[x]${RESET} $*"; exit 1; }

# ── Determine install prefix ─────────────────────────────────────
if [[ -w /usr/local/lib ]]; then
    INSTALL_DIR="${CLAUDE_AGENT_INSTALL_DIR:-/usr/local/lib/claude-agent}"
    BIN_DIR="/usr/local/bin"
else
    INSTALL_DIR="${CLAUDE_AGENT_INSTALL_DIR:-$HOME/.local/lib/claude-agent}"
    BIN_DIR="$HOME/.local/bin"
    mkdir -p "$BIN_DIR"
    if [[ ":$PATH:" != *":$BIN_DIR:"* ]]; then
        warn "$BIN_DIR is not in your PATH. Add it:"
        warn "  export PATH=\"$BIN_DIR:\$PATH\""
        # Try to add to shell profile
        for rc_file in "$HOME/.bashrc" "$HOME/.profile"; do
            if [[ -f "$rc_file" ]]; then
                if ! grep -qF "$BIN_DIR" "$rc_file" 2>/dev/null; then
                    echo "export PATH=\"$BIN_DIR:\$PATH\"" >> "$rc_file"
                    info "Added to $rc_file"
                fi
                break
            fi
        done
    fi
fi

echo ""
echo -e "${BOLD}claude-agent installer v${VERSION}${RESET}"
echo "  Install to: ${INSTALL_DIR}"
echo "  Binary at:  ${BIN_DIR}/claude-agent"
echo ""

# ── 1. System requirements ────────────────────────────────────────
info "Checking requirements..."

# Bash version
bash_major="${BASH_VERSINFO[0]:-0}"
if [[ "$bash_major" -lt 4 ]]; then
    error "Bash 4.0+ required (found ${BASH_VERSION}). Upgrade bash first."
fi

# Required commands
for cmd in curl python3; do
    if ! command -v "$cmd" &>/dev/null; then
        # Try to install on Debian/Ubuntu
        if command -v apt-get &>/dev/null; then
            info "Installing $cmd..."
            apt-get update -qq && apt-get install -y -qq "$cmd" || error "Failed to install $cmd"
        else
            error "'$cmd' is required. Install it first."
        fi
    fi
done

info "Requirements satisfied."

# ── 2. Node.js ────────────────────────────────────────────────────
if ! command -v node &>/dev/null; then
    info "Installing Node.js 20 LTS..."
    if command -v apt-get &>/dev/null; then
        curl -fsSL https://deb.nodesource.com/setup_20.x | bash -
        apt-get install -y nodejs
    elif command -v apk &>/dev/null; then
        apk add --no-cache nodejs npm
    elif command -v yum &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
        yum install -y nodejs
    elif command -v dnf &>/dev/null; then
        curl -fsSL https://rpm.nodesource.com/setup_20.x | bash -
        dnf install -y nodejs
    else
        error "Cannot detect package manager. Install Node.js 18+ manually: https://nodejs.org/"
    fi
    info "Node.js $(node --version) installed."
else
    node_major=$(node --version | sed 's/v//' | cut -d. -f1)
    if [[ "$node_major" -lt 18 ]]; then
        warn "Node.js $(node --version) found but 18+ required. Upgrading is recommended."
    else
        info "Node.js $(node --version) found."
    fi
fi

# ── 3. Claude Code CLI ───────────────────────────────────────────
if ! command -v claude &>/dev/null; then
    info "Installing Claude Code CLI..."
    npm install -g @anthropic-ai/claude-code
    info "Claude Code CLI installed."
else
    info "Claude Code CLI found."
fi

# Pre-accept onboarding for non-interactive use
mkdir -p "$HOME/.claude"
if [[ ! -f "$HOME/.claude/settings.json" ]]; then
    echo '{"hasCompletedOnboarding":true,"hasAcknowledgedCostThreshold":true}' \
        > "$HOME/.claude/settings.json"
    info "Claude Code onboarding pre-accepted."
fi

# ── 4. Install claude-agent ──────────────────────────────────────
info "Installing claude-agent..."
mkdir -p "$INSTALL_DIR"/{lib,commands}

FILES=(
    "claude-agent"
    "lib/core.sh"
    "lib/config.sh"
    "lib/session.sh"
    "lib/claude.sh"
    "commands/run.sh"
    "commands/chat.sh"
    "commands/session.sh"
    "commands/config.sh"
    "commands/version.sh"
    "commands/cowork.sh"
)

for f in "${FILES[@]}"; do
    curl -fsSL "$REPO_URL/$f" -o "$INSTALL_DIR/$f" || error "Failed to download $f"
done

chmod +x "$INSTALL_DIR/claude-agent"
ln -sf "$INSTALL_DIR/claude-agent" "$BIN_DIR/claude-agent"

# ── 5. Verify ────────────────────────────────────────────────────
info "Verifying..."
if "$BIN_DIR/claude-agent" version &>/dev/null; then
    info "Verification passed."
else
    warn "Verification failed. Check output above."
fi

# ── Done ─────────────────────────────────────────────────────────
echo ""
echo -e "${GREEN}${BOLD}claude-agent v${VERSION} installed successfully.${RESET}"
echo ""
echo "  export ANTHROPIC_API_KEY=sk-ant-..."
echo "  claude-agent run \"fix the bug in main.py\""
echo "  claude-agent cowork -f prompt.md"
echo "  claude-agent --help"
echo ""

if [[ -n "${ANTHROPIC_API_KEY:-}" ]]; then
    info "ANTHROPIC_API_KEY is set. Ready to go."
else
    warn "Set ANTHROPIC_API_KEY before use: export ANTHROPIC_API_KEY=sk-ant-..."
fi
