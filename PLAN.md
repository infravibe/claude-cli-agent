# claude-agent v2.0 - Project Plan

## Overview

Production-grade non-interactive CLI wrapper for Claude Code (`claude` CLI). Designed for Docker containers, CI/CD, and automation. Features autonomous **cowork** mode (plan → execute → verify → self-heal). Bash 3.2+ compatible. Claude runs as root with full unrestricted access inside containers.

## Architecture

```
claude-agent (entrypoint)
├── lib/
│   ├── core.sh          # Logging, safe JSON ops, sanitization, UUID, timeout
│   ├── config.sh         # 4-level config with validation
│   ├── session.sh        # Session CRUD with sanitized inputs
│   └── claude.sh         # Command builder + 3 execution modes (exec/capture/json)
├── commands/
│   ├── run.sh            # One-shot execution
│   ├── cowork.sh         # Autonomous plan → execute → verify → retry loop
│   ├── chat.sh           # Multi-turn sessions
│   ├── session.sh        # Session lifecycle
│   ├── config.sh         # Config inspection
│   └── version.sh        # Version info
├── install.sh            # Curl-pipe-bash installer
├── docker/
│   ├── Dockerfile        # Ubuntu 22.04 (full)
│   ├── Dockerfile.slim   # Node 20 (slim)
│   └── docker-compose.yml
├── tests/                # 91 tests across 5 files
│   ├── test_core.sh      # 16 tests: JSON safety, sanitization, UUID
│   ├── test_config.sh    # 15 tests: defaults, env, file, validation
│   ├── test_session.sh   # 12 tests: CRUD, sanitization, resolve
│   ├── test_commands.sh  # 15 tests: CLI integration
│   └── test_claude_flags.sh # 33 tests: every Claude CLI flag
├── examples/
│   ├── prompt.md
│   ├── cowork-basic.sh
│   ├── ci-code-review.sh
│   ├── batch-refactor.sh
│   ├── chat-session.sh
│   └── docker-usage.sh
└── completions/
    └── claude-agent.bash
```

## CLI Interface

```
claude-agent [GLOBAL OPTIONS] <COMMAND> [ARGS...]

Commands:
  run <prompt>          One-shot task
  cowork <prompt>       Plan → Execute → Verify → Retry (autonomous)
  chat <prompt>         Multi-turn with session persistence
  session <subcmd>      Manage sessions (list/show/delete)
  config <subcmd>       Configuration (show/set/path)
  version               Version info
```

## Claude CLI Flag Mapping (v2.0)

Every flag maps to the real `claude` CLI, verified by 33 dedicated tests:

| Category | Our Flag | Claude CLI Flag |
|----------|----------|-----------------|
| Model | `--model` | `--model` |
| Model | `--effort` | `--effort` |
| Model | `--fallback-model` | `--fallback-model` |
| Output | `--output` | `--output-format` |
| Output | `--json-schema` | `--json-schema` |
| Output | `--input-format` | `--input-format` |
| Tools | `--tools` | `--allowedTools` (per-tool) |
| Tools | `--disallowed-tools` | `--disallowedTools` (per-tool) |
| Limits | `--max-turns` | `--max-turns` |
| Limits | `--max-budget` | `--max-budget-usd` |
| Prompt | `--system-prompt` | `--system-prompt` |
| Prompt | `--system-prompt-file` | `--system-prompt-file` |
| Prompt | `--append-system-prompt` | `--append-system-prompt` |
| Session | `--continue` | `--continue` |
| Session | `--resume` | `--resume` |
| Session | `--session-id` | `--session-id` |
| Session | `--name` | `--name` |
| Session | `--fork-session` | `--fork-session` |
| Session | `--no-session-persistence` | `--no-session-persistence` |
| Perms | (default) | `--dangerously-skip-permissions` |
| Perms | `--permission-mode` | `--permission-mode` |
| Context | `--mcp-config` | `--mcp-config` |
| Context | `--settings` | `--settings` |
| Context | `--add-dir` | `--add-dir` |
| Debug | `--verbose` | `--verbose` |
| Debug | `--debug` | `--debug` |

Exit codes: 0=success, 1=error, 2=auth, 124=timeout.

## Cowork Workflow

```
prompt.md
    │
    ▼
┌──────────┐  (2 retries)
│   PLAN   │──────────────────────────────────┐
└────┬─────┘                                  │ fail → die
     │                                        │
     ▼                                        │
┌──────────┐  claude_exec_json()              │
│ EXECUTE  │  tracks cost + turns             │
└────┬─────┘                                  │
     │                                        │
     ▼                                        │
┌──────────┐  Checks VERIFICATION_STATUS:     │
│  VERIFY  │  PASS on own line                │
└────┬─────┘                                  │
     │                                        │
     ├── PASS → done (report cost/turns)      │
     │                                        │
     └── FAIL → feed errors back to EXECUTE   │
              (up to N retries)               │
```

## Security Model

### v1.0 → v2.0 fixes:
- **JSON injection eliminated**: All Python ops use `sys.argv`/`sys.stdin`, not string interpolation
- **Input sanitization**: `sanitize()` strips everything except `[a-zA-Z0-9._-]`
- **Config file not sourced**: Parsed line-by-line, only accepting known key patterns
- **`--max-budget` fixed**: Now correctly maps to `--max-budget-usd` (was mapped to `--max-turns`)
- **Verification hardened**: Requires `VERIFICATION_STATUS: PASS` on own line, not substring match
- **Errors not suppressed**: Removed `2>/dev/null` from plan phase; all errors visible
- **Auth error handling**: Exit code 2 detected and reported immediately

### Docker permissions:
- `USER root` in Dockerfile
- `privileged: true` in docker-compose
- Pre-accepted Claude Code onboarding
- `--dangerously-skip-permissions` default on
- Full network, filesystem, package manager access
- The container IS the security boundary

## Bash Compatibility

Compatible with bash 3.2+ (macOS default) and 4.x+ (Linux):
- No `local -n` (namerefs) — uses global `CLAUDE_CMD` array
- No `((var++))` — uses `var=$((var + 1))`
- No `[[ ]] && action` without `|| true`
- `log_debug` uses `if/then` not `&&`
- `readlink -f` with fallback for macOS

## Test Commands

```bash
# Full suite (91 tests)
bash tests/test_core.sh && bash tests/test_config.sh && bash tests/test_session.sh && bash tests/test_commands.sh && bash tests/test_claude_flags.sh

# Individual suites
bash tests/test_core.sh          # 16 tests: JSON safety, sanitization, UUID, parsing
bash tests/test_config.sh        # 15 tests: defaults, env override, file loading, validation
bash tests/test_session.sh       # 12 tests: CRUD, name sanitization, resolve by name/ID
bash tests/test_commands.sh      # 15 tests: help, version, config, error handling
bash tests/test_claude_flags.sh  # 33 tests: every Claude CLI flag verified
```
