#!/usr/bin/env bash
# Example: Basic cowork usage - plan, execute, verify, retry
set -euo pipefail

# ── Method 1: From a prompt file ─────────────────────────────────
claude-agent cowork -f prompt.md

# ── Method 2: Inline prompt ──────────────────────────────────────
claude-agent cowork "Create a Python CLI tool that converts CSV to JSON.
Add argument parsing, error handling, tests, and a README."

# ── Method 3: Skip planning (direct execution + verify) ──────────
claude-agent cowork --no-plan "Fix all failing tests in this project"

# ── Method 4: With model override and more retries ────────────────
claude-agent --model opus cowork --retries 5 -f prompt.md

# ── Method 5: Docker (full root access) ──────────────────────────
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v "$(pwd)":/workspace \
    claude-agent cowork -f /workspace/prompt.md

# ── Method 6: Docker Compose ─────────────────────────────────────
cd docker
docker compose run cowork -f /workspace/prompt.md
