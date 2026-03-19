# RUN.md — Complete guide to running claude-agent

## Prerequisites

- Docker installed and running
- An Anthropic API key (`sk-ant-...`)
- This repository cloned:
  ```bash
  git clone https://github.com/infravibe/claude-cli-agent.git
  cd claude-cli-agent
  ```

---

## Step 1: Set your API key

```bash
export ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
```

This must be set in every terminal session. To make it permanent:

```bash
echo 'export ANTHROPIC_API_KEY=sk-ant-api03-xxxxx' >> ~/.bashrc
source ~/.bashrc
```

---

## Step 2: Build the Docker image

```bash
# Full image (Ubuntu-based, ~1.5GB, has build tools, networking, etc.)
docker build -t claude-agent -f docker/Dockerfile .

# OR slim image (Node-based, ~800MB, faster build)
docker build -t claude-agent -f docker/Dockerfile.slim .
```

Verify the build:

```bash
docker run --rm claude-agent version
```

Expected output:

```
claude-agent v2.0.0
claude-code: 1.x.x
bash: 5.x.x
python3: 3.x.x
node: v20.x.x
```

---

## Step 3: Create a workspace

Create a directory where Claude will work. This gets mounted into the container at `/workspace`:

```bash
mkdir -p workspace
```

---

## Method A: docker run (one-off tasks)

### A1. Simple one-shot task

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent run "create a Python script that prints the first 20 fibonacci numbers"
```

### A2. Cowork with a prompt file

Copy a prompt file into your workspace, then run cowork:

```bash
# Copy the example prompt
cp examples/prompt-simple.md workspace/prompt.md

# Run cowork (plan → execute → verify → retry)
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent cowork -f /workspace/prompt.md
```

### A3. Cowork with inline prompt

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent cowork "Create a Python calculator CLI with add, subtract, multiply, divide. Include tests."
```

### A4. Use a specific model

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent --model opus cowork -f /workspace/prompt.md
```

### A5. Set a budget limit

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent --max-budget 5.00 cowork -f /workspace/prompt.md
```

### A6. Set effort level and retries

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent --model opus --effort high \
    cowork --retries 5 -f /workspace/prompt.md
```

### A7. Get JSON output

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent --output json run "list all files in /workspace" | jq '.result'
```

### A8. Pipe input (code review)

```bash
cd workspace
git diff HEAD~1 | docker run --rm -i \
    -e ANTHROPIC_API_KEY \
    -v $(pwd):/workspace \
    claude-agent run - "review this diff for bugs and security issues"
```

### A9. Work on an existing project

Mount your actual project directory:

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v /path/to/your/project:/workspace \
    claude-agent cowork "fix all failing tests and linting errors"
```

### A10. Skip planning (faster for simple tasks)

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent cowork --no-plan "fix the typo in README.md"
```

### A11. Skip verification (trust the output)

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent cowork --no-verify "add docstrings to all Python files"
```

---

## Method B: docker compose

### B1. Setup

```bash
cd docker
```

Create a `.env` file for your API key (so you don't have to pass it every time):

```bash
echo "ANTHROPIC_API_KEY=sk-ant-api03-xxxxx" > .env
```

Create the workspace directory:

```bash
mkdir -p workspace
```

Copy a prompt file:

```bash
cp ../examples/prompt-simple.md workspace/prompt.md
```

### B2. Run a one-shot task

```bash
docker compose run --rm claude-agent run "create a hello world Python script"
```

### B3. Run cowork

```bash
docker compose run --rm cowork -f /workspace/prompt.md
```

### B4. Run cowork with inline prompt

```bash
docker compose run --rm cowork "Build a REST API with Flask, include tests and a Dockerfile"
```

### B5. Override the model

```bash
CLAUDE_AGENT_MODEL=opus docker compose run --rm cowork -f /workspace/prompt.md
```

### B6. Long-running dev container (multiple tasks)

Start a persistent container:

```bash
docker compose up -d dev
```

Run multiple tasks inside it:

```bash
# First task
docker compose exec dev claude-agent cowork -f /workspace/prompt.md

# Follow-up task (same container, sees previous work)
docker compose exec dev claude-agent run "now add API documentation"

# Another follow-up
docker compose exec dev claude-agent run "add rate limiting to all endpoints"
```

Stop when done:

```bash
docker compose down
```

### B7. View sessions

```bash
docker compose exec dev claude-agent session list
```

---

## Method C: Install directly (no Docker)

For use on your local machine or a VM:

```bash
curl -fsSL https://raw.githubusercontent.com/infravibe/claude-cli-agent/main/install.sh | bash
export ANTHROPIC_API_KEY=sk-ant-api03-xxxxx

claude-agent run "hello world"
claude-agent cowork -f prompt.md
```

---

## Testing with example prompts

The `examples/` directory has ready-to-use prompts at different complexity levels:

### Test 1: Simple (5 min, ~$0.10)

```bash
cp examples/prompt-simple.md workspace/prompt.md
docker run --rm -e ANTHROPIC_API_KEY -v $(pwd)/workspace:/workspace \
    claude-agent cowork -f /workspace/prompt.md
```

Creates a Flask hello-world app with 3 routes and tests.

### Test 2: Full-stack (15 min, ~$0.50)

```bash
cp examples/prompt-fullstack.md workspace/prompt.md
docker run --rm -e ANTHROPIC_API_KEY -v $(pwd)/workspace:/workspace \
    claude-agent --model opus cowork -f /workspace/prompt.md
```

Creates a complete Todo app with FastAPI backend, HTML/JS frontend, SQLite, and tests.

### Test 3: DevOps (15 min, ~$0.50)

```bash
cp examples/prompt-devops.md workspace/prompt.md
docker run --rm -e ANTHROPIC_API_KEY -v $(pwd)/workspace:/workspace \
    claude-agent --model opus cowork -f /workspace/prompt.md
```

Creates an Express.js API with Docker, CI/CD workflow, Makefile, and full test suite.

### Test 4: Bug fixing (varies)

Put your buggy project in `workspace/`, then:

```bash
docker run --rm -e ANTHROPIC_API_KEY -v $(pwd)/workspace:/workspace \
    claude-agent cowork -f /workspace/prompt-bugfix.md
```

### Test 5: Work on your own project

```bash
docker run --rm -e ANTHROPIC_API_KEY -v /path/to/your/project:/workspace \
    claude-agent cowork "add comprehensive tests for the user authentication module"
```

---

## Writing your own prompt.md

A good prompt file has this structure:

```markdown
# Task: [one-line description]

[Brief overview of what you want built/done]

## Step 1: [component name]

- Specific requirement
- Specific requirement
- Specific requirement

## Step 2: [component name]

- Specific requirement
- Specific requirement

## Verify

- [how to check it worked]
- [what tests to run]
- [what output to expect]
```

### Tips for good prompts:

1. **Be specific about paths** — use `/workspace/myapp/` not "create a project"
2. **List exact endpoints/functions** — don't say "add CRUD", say "POST /api/users, GET /api/users/:id"
3. **Specify the tech stack** — "Python with FastAPI" not just "a web server"
4. **Include a Verify section** — tell Claude exactly how to check its work
5. **One task per prompt** — don't mix "build an API" with "deploy to AWS"

### Bad prompt:

```markdown
Build me an app with a database and tests
```

### Good prompt:

```markdown
# Task: Build a bookmark manager API

Create a FastAPI app in /workspace/bookmarks/ with:

1. SQLite database with model: Bookmark (id, url, title, tags, created_at)
2. Endpoints:
   - POST /api/bookmarks — create (url required, title optional)
   - GET /api/bookmarks — list all (support ?tag=python filter)
   - DELETE /api/bookmarks/{id} — delete
3. Pydantic schemas for request/response validation
4. pytest tests for all endpoints (at least 8 test cases)

Verify: install deps, run tests, all must pass
```

---

## Troubleshooting

### "Claude CLI is not installed"

The Docker image didn't build correctly. Rebuild:

```bash
docker build --no-cache -t claude-agent -f docker/Dockerfile .
```

### "ANTHROPIC_API_KEY is not set"

```bash
# Check if it's set
echo $ANTHROPIC_API_KEY

# Set it
export ANTHROPIC_API_KEY=sk-ant-api03-xxxxx
```

### "Authentication error (code 2)"

Your API key is invalid or expired. Get a new one from https://console.anthropic.com/

### Cowork keeps failing verification

- Increase retries: `cowork --retries 5`
- Use a stronger model: `--model opus`
- Use higher effort: `--effort high`
- Simplify the prompt (break into smaller tasks)

### Container runs out of disk space

```bash
# Clean up Docker
docker system prune -f
docker volume prune -f
```

### Want to see what Claude is doing

Add `--verbose`:

```bash
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent --verbose cowork -f /workspace/prompt.md
```

### Want to limit cost

```bash
# Stop after spending $2
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent --max-budget 2.00 cowork -f /workspace/prompt.md

# Limit to 10 turns
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v $(pwd)/workspace:/workspace \
    claude-agent --max-turns 10 cowork -f /workspace/prompt.md
```

---

## Quick reference

```bash
# Build
docker build -t claude-agent -f docker/Dockerfile .

# One-shot
docker run --rm -e ANTHROPIC_API_KEY -v $(pwd)/workspace:/workspace \
    claude-agent run "your task"

# Cowork (autonomous)
docker run --rm -e ANTHROPIC_API_KEY -v $(pwd)/workspace:/workspace \
    claude-agent cowork -f /workspace/prompt.md

# Cowork with all options
docker run --rm -e ANTHROPIC_API_KEY -v $(pwd)/workspace:/workspace \
    claude-agent --model opus --effort high --max-budget 10.00 --verbose \
    cowork --retries 5 -f /workspace/prompt.md

# Docker compose
cd docker && echo "ANTHROPIC_API_KEY=sk-ant-..." > .env
docker compose run --rm cowork -f /workspace/prompt.md
```
