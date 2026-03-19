# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

## Project Overview

`claude-agent` v2.0 — production-grade non-interactive CLI wrapper for Claude Code in Docker containers. Wraps `claude -p` with config management, session persistence, and autonomous cowork workflow (plan → execute → verify → retry). Written in bash, compatible with bash 3.2+ (macOS) and 4.x+ (Linux). Python3 is the only non-trivial dependency.

## Commands

```bash
# Run full test suite (91 tests across 5 files)
bash tests/test_core.sh && bash tests/test_config.sh && bash tests/test_session.sh && bash tests/test_commands.sh && bash tests/test_claude_flags.sh

# Run a single test file
bash tests/test_claude_flags.sh

# Test the CLI locally
./claude-agent --help
./claude-agent version
./claude-agent config show

# Build Docker images
docker build -t claude-agent -f docker/Dockerfile .
docker build -t claude-agent-slim -f docker/Dockerfile.slim .
```

## Architecture

- **`claude-agent`** — Main entrypoint. Parses global flags, loads config, dispatches to subcommands. Sources all `lib/` and `commands/` modules.

- **`lib/core.sh`** — Logging, `die()`, safe JSON operations (`json_get/json_set/json_create/json_parse/json_is_error` — all use `sys.argv` or `sys.stdin` in Python, never string interpolation), `sanitize()` for input cleaning, UUID generation, timeout wrapper.

- **`lib/config.sh`** — 4-level config: CLI flags > env vars > config file > defaults. All values in `CFG_*` globals. Includes `config_validate()` for checking output format, effort level, permission mode. Config file is parsed line-by-line (not sourced) to prevent code execution.

- **`lib/claude.sh`** — `_claude_build_cmd()` builds a `CLAUDE_CMD` global array from resolved `CFG_*` values with every Claude Code CLI flag. Three execution modes:
  - `claude_exec()` — runs claude, output to stdout, returns exit code
  - `claude_exec_capture()` — captures output + exit code into globals
  - `claude_exec_json()` — forces `--output-format json`, parses `result`, `session_id`, `cost_usd`, `num_turns`, `is_error`

- **`lib/session.sh`** — Session CRUD with sanitized inputs. All names go through `sanitize()` before use in file paths.

- **`commands/cowork.sh`** — Three-phase autonomous loop: `cowork_plan()` → execute via `claude_exec_json()` → verify via `claude_exec_json()`. Verification uses `VERIFICATION_STATUS: PASS` on its own line (not substring match). On failure, verify output is prepended to next execution prompt. Tracks cumulative cost and turns. Plan phase has its own retry (2 attempts).

- **`commands/run.sh`**, **`chat.sh`**, **`session.sh`**, **`config.sh`**, **`version.sh`** — Standard subcommands.

## Claude CLI Flag Mapping

All flags map to the real `claude` CLI flags (verified by 33 dedicated tests):
- `--model`, `--effort`, `--fallback-model` — model selection
- `--output-format`, `--json-schema`, `--input-format` — output control
- `--allowedTools`, `--disallowedTools` — tool permissions
- `--max-turns`, `--max-budget-usd` — execution limits (NOT `--max-budget`)
- `--system-prompt`, `--system-prompt-file`, `--append-system-prompt`, `--append-system-prompt-file`
- `--resume`, `--session-id`, `--continue`, `--fork-session`, `--no-session-persistence`, `--name`
- `--permission-mode`, `--dangerously-skip-permissions`
- `--mcp-config`, `--settings`, `--add-dir`
- `--verbose`, `--debug`

Exit codes: 0=success, 1=error, 2=auth error, 124=timeout.

## Key Design Decisions

- **No `local -n` (namerefs)**: macOS ships bash 3.2 which lacks namerefs. `_claude_build_cmd` writes to a global `CLAUDE_CMD` array instead.

- **`set -euo pipefail` safe patterns**: `[[ ]] && action` uses `|| true` suffix. Arithmetic uses `var=$((var + 1))` not `((var++))`. `log_debug` uses `if/then` not `&&`.

- **Safe JSON ops**: All Python code uses `sys.argv` for file paths/keys and `sys.stdin` for data. No shell variable interpolation inside Python strings. `json_parse` and `json_is_error` use `-c` flag (not heredoc) to avoid stdin conflicts when piping.

- **Input sanitization**: `sanitize()` strips everything except `[a-zA-Z0-9._-]`. Session names, IDs, and file paths all go through it before use.

- **Config file is parsed, not sourced**: `config_load_file` reads line-by-line, only accepting `CFG_*`/`ANTHROPIC_*`/`CLAUDE_AGENT_*` keys, preventing arbitrary code execution from a malicious config file.

- **Cowork verification is strict**: Requires `VERIFICATION_STATUS: PASS` on its own line at the end of output. Not a substring match.

- **Docker runs as root**: Container is the security boundary. `USER root`, `privileged: true`, pre-accepted onboarding, `--dangerously-skip-permissions` default-on.
