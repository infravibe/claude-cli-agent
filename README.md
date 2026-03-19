# claude-agent

Production-grade, non-interactive CLI wrapper for [Claude Code](https://docs.anthropic.com/en/docs/claude-code) in Docker containers. One command to install, one command to run. Features an autonomous **cowork** mode that plans, executes, verifies, and self-heals.

## Install

```bash
# On any Ubuntu/Debian Docker container (or local machine)
curl -fsSL https://raw.githubusercontent.com/akash/claude-cli-agent/main/install.sh | bash
```

Installs Node.js (if missing), Claude Code CLI, pre-accepts onboarding, and sets up `claude-agent`.

## Quick Start

```bash
export ANTHROPIC_API_KEY=sk-ant-...

# One-shot task
claude-agent run "fix the bug in main.py"

# Autonomous cowork: plan → execute → verify → retry
claude-agent cowork -f prompt.md

# Docker (Claude gets full root access inside the container)
docker run --rm -e ANTHROPIC_API_KEY -v $(pwd):/workspace \
    claude-agent cowork -f /workspace/prompt.md
```

## Commands

### `cowork` — Autonomous Plan-Execute-Verify Loop

The flagship command. Give it a task and it autonomously:

1. **Plans** — analyzes the task and creates a step-by-step execution plan
2. **Executes** — carries out every step with full system access
3. **Verifies** — runs tests, checks files, validates output
4. **Retries** — if verification fails, feeds errors back and re-executes (up to N retries)

Tracks cumulative cost and turns across all phases.

```bash
# From a prompt file (recommended for complex tasks)
claude-agent cowork -f prompt.md

# Inline
claude-agent cowork "Create a Python CLI that converts CSV to JSON with tests"

# Skip planning (faster)
claude-agent cowork --no-plan "Fix all failing tests in this project"

# With model, effort, budget control, and more retries
claude-agent --model opus --effort high --max-budget 10.00 cowork --retries 5 -f prompt.md
```

**Example `prompt.md`:**

```markdown
# Task: Build a REST API

1. Create a FastAPI project with proper structure
2. Implement User model with SQLAlchemy
3. Add JWT auth (register, login endpoints)
4. Add CRUD endpoints for users
5. Write pytest tests with >80% coverage
6. Add Dockerfile and docker-compose.yml
7. Verify all tests pass and Docker builds
```

### `run` — One-shot execution

```bash
claude-agent run "your task here"
claude-agent run -f prompt.md                    # From file
echo "task" | claude-agent run -                 # From stdin
git diff | claude-agent run "review this diff"   # Pipe context
claude-agent --output json run "list functions" | jq '.result'  # JSON output
```

### `chat` — Multi-turn sessions

```bash
claude-agent chat --session myproject "set up the project structure"
claude-agent chat --session myproject "now add tests"
```

### `session` — Manage sessions

```bash
claude-agent session list
claude-agent session show <ID>
claude-agent session delete <ID>
```

### `config` — Configuration

```bash
claude-agent config show
claude-agent config set CLAUDE_AGENT_MODEL opus
```

## Global Options

### Model

| Flag | Description | Default |
|---|---|---|
| `--model <MODEL>` | Model: sonnet, opus, haiku, or full name | default |
| `--effort <LEVEL>` | Reasoning depth: low, medium, high, max | default |
| `--fallback-model <M>` | Fallback when primary is overloaded | none |

### Output

| Flag | Description | Default |
|---|---|---|
| `--output <FORMAT>` | Output: text, json, stream-json | text |
| `--json-schema <JSON>` | Validate JSON output against schema | none |
| `--input-format <FMT>` | Input format: text, stream-json | text |

### Tools & Permissions

| Flag | Description | Default |
|---|---|---|
| `--tools <TOOLS>` | Comma-separated allowed tools (Bash,Read,Edit,...) | all |
| `--disallowed-tools <TOOLS>` | Comma-separated disallowed tools | none |
| `--no-skip-permissions` | Enable permission prompts | skip |
| `--permission-mode <MODE>` | default, acceptEdits, plan, bypassPermissions | default |

### Execution Limits

| Flag | Description | Default |
|---|---|---|
| `--max-turns <N>` | Max agentic turns | unlimited |
| `--max-budget <USD>` | Max cost in USD before stopping | unlimited |
| `--timeout <SECS>` | Timeout in seconds | none |

### System Prompt

| Flag | Description |
|---|---|
| `--system-prompt <TEXT>` | Replace entire system prompt |
| `--system-prompt-file <PATH>` | Replace system prompt from file |
| `--append-system-prompt <TEXT>` | Append to default system prompt |
| `--append-system-prompt-file <PATH>` | Append from file |

### Session

| Flag | Description |
|---|---|
| `--continue` | Continue last conversation |
| `--resume <ID>` | Resume specific session (ID or name) |
| `--session-id <UUID>` | Use specific session UUID |
| `--name, -n <NAME>` | Name for the session |
| `--fork-session` | Fork when resuming (new session ID) |
| `--no-session-persistence` | Don't save session to disk |

### Other

| Flag | Description |
|---|---|
| `--workdir, -w <DIR>` | Working directory for Claude |
| `--add-dir <DIR>` | Additional directories (repeatable) |
| `--api-key <KEY>` | Anthropic API key |
| `--mcp-config <PATH>` | MCP server config file or inline JSON |
| `--settings <PATH>` | Additional settings file or JSON |
| `-v, --verbose` | Verbose output from Claude |
| `--debug <CATEGORIES>` | Debug mode (e.g., "api,hooks") |

## Docker Usage

Claude runs as **root** inside the container with full unrestricted access — install packages, modify any file, run any command. The container itself is the security boundary.

### Direct Docker run

```bash
# One-shot task
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd):/workspace \
    claude-agent run "fix all linting errors"

# Cowork with prompt file
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd):/workspace \
    claude-agent cowork -f /workspace/prompt.md

# With model and budget control
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd):/workspace \
    claude-agent --model opus --max-budget 5.00 cowork -f /workspace/prompt.md
```

### Build the image

```bash
# Ubuntu-based (full — build tools, networking, jq, etc.)
docker build -t claude-agent -f docker/Dockerfile .

# Node-based (slim, faster build)
docker build -t claude-agent -f docker/Dockerfile.slim .
```

### Docker Compose

```bash
cd docker

# Cowork task
docker compose run cowork -f /workspace/prompt.md

# Any command
docker compose run claude-agent run "fix the tests"

# Long-running dev container (run multiple tasks)
docker compose up -d dev
docker compose exec dev claude-agent cowork -f /workspace/prompt.md
docker compose exec dev claude-agent run "now add documentation"
docker compose down dev
```

### Add to any existing Dockerfile

```dockerfile
FROM ubuntu:22.04
# ... your setup ...

# One line to install claude-agent
RUN curl -fsSL https://raw.githubusercontent.com/akash/claude-cli-agent/main/install.sh | bash
```

## Environment Variables

| Variable | Description | Default |
|---|---|---|
| `ANTHROPIC_API_KEY` | API key (required) | — |
| `CLAUDE_AGENT_MODEL` | Default model | — |
| `CLAUDE_AGENT_EFFORT` | Default effort level | — |
| `CLAUDE_AGENT_OUTPUT` | Default output format | text |
| `CLAUDE_AGENT_TOOLS` | Default allowed tools | all |
| `CLAUDE_AGENT_DISALLOWED_TOOLS` | Default disallowed tools | none |
| `CLAUDE_AGENT_MAX_TURNS` | Default max turns | unlimited |
| `CLAUDE_AGENT_MAX_BUDGET_USD` | Default max budget | unlimited |
| `CLAUDE_AGENT_TIMEOUT` | Default timeout (seconds) | none |
| `CLAUDE_AGENT_SKIP_PERMISSIONS` | Skip permission prompts | true |
| `CLAUDE_AGENT_PERMISSION_MODE` | Permission mode | default |
| `CLAUDE_AGENT_WORKDIR` | Default working directory | cwd |
| `CLAUDE_AGENT_VERBOSE` | Verbose logging | false |
| `CLAUDE_AGENT_COWORK_RETRIES` | Max cowork retries | 3 |
| `CLAUDE_AGENT_FALLBACK_MODEL` | Fallback model | none |
| `CLAUDE_AGENT_MCP_CONFIG` | MCP server config path | none |
| `CLAUDE_AGENT_CONFIG_DIR` | Config directory | ~/.config/claude-agent |

## CI/CD Integration

### GitHub Actions — Code Review

```yaml
- name: Code Review
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    curl -fsSL https://raw.githubusercontent.com/akash/claude-cli-agent/main/install.sh | bash
    git diff origin/main...HEAD | claude-agent run "review this diff for bugs and security issues"
```

### GitHub Actions — Auto-fix with Cowork

```yaml
- name: Auto-fix and verify
  env:
    ANTHROPIC_API_KEY: ${{ secrets.ANTHROPIC_API_KEY }}
  run: |
    curl -fsSL https://raw.githubusercontent.com/akash/claude-cli-agent/main/install.sh | bash
    claude-agent --max-budget 5.00 cowork "Fix all failing tests and linting errors. Verify everything passes."
```

### GitLab CI

```yaml
code-review:
  image: node:20
  script:
    - curl -fsSL https://raw.githubusercontent.com/akash/claude-cli-agent/main/install.sh | bash
    - git diff origin/main...HEAD | claude-agent run "review this diff"
  variables:
    ANTHROPIC_API_KEY: $ANTHROPIC_API_KEY
```

## How It Works

```
prompt.md
    │
    ▼
┌──────────┐
│   PLAN   │  Claude analyzes task, outputs step-by-step plan
└────┬─────┘
     ▼
┌──────────┐
│ EXECUTE  │  Claude executes with full system access
└────┬─────┘
     ▼
┌──────────┐     ┌───────────────────────────┐
│  VERIFY  │────▶│ PASS → Done (report cost) │
└────┬─────┘     │ FAIL → Feed errors back   │
     │           │         to EXECUTE (retry) │
     └───────────┘
```

`claude-agent` wraps the `claude` CLI's non-interactive print mode (`-p`). Each phase is a separate Claude invocation:

1. **Plan** — `claude -p "<planning prompt>" --dangerously-skip-permissions`
2. **Execute** — `claude -p "<task + plan>" --output-format json --dangerously-skip-permissions`
3. **Verify** — `claude -p "<verification prompt>" --output-format json --dangerously-skip-permissions`

The execute and verify phases use `--output-format json` to parse structured results (`result`, `cost_usd`, `num_turns`, `is_error`). On verify failure, the error output is prepended to the next execution prompt.

Exit codes: `0` = success, `1` = error, `2` = authentication error.

### Docker Security Model

The container runs as root with `--dangerously-skip-permissions` enabled by default. Claude can install packages, compile code, run tests, modify any configuration. The Docker container itself is the security boundary — Claude has full access inside, but nothing outside.

## Testing

91 tests across 5 test suites:

```bash
# Run all tests
bash tests/test_core.sh && \
bash tests/test_config.sh && \
bash tests/test_session.sh && \
bash tests/test_commands.sh && \
bash tests/test_claude_flags.sh

# Individual suites
bash tests/test_core.sh          # 16 tests — JSON safety, sanitization, UUID
bash tests/test_config.sh        # 15 tests — defaults, env vars, file loading, validation
bash tests/test_session.sh       # 12 tests — CRUD, name sanitization, resolve
bash tests/test_commands.sh      # 15 tests — CLI help, version, config, error handling
bash tests/test_claude_flags.sh  # 33 tests — every Claude CLI flag verified
```

## License

MIT
