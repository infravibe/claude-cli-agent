#!/usr/bin/env bash
# Example: Various ways to use claude-agent with Docker
set -euo pipefail

# ── Method 1: Direct docker run ─────────────────────────────────────
# Mount your project and run a task
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v "$(pwd)":/workspace \
    claude-agent run "fix all linting errors in this project"

# ── Method 2: Build and run ──────────────────────────────────────────
# Build the image first
docker build -t claude-agent -f docker/Dockerfile .

# Run tasks against your project
docker run --rm \
    -e ANTHROPIC_API_KEY \
    -v "$(pwd)":/workspace \
    claude-agent run "add type hints to all Python functions"

# ── Method 3: Docker Compose ─────────────────────────────────────────
# Run with compose (uses docker-compose.yml config)
cd docker
docker compose run claude-agent run "explain the architecture of this codebase"

# ── Method 4: Interactive-ish workflow ───────────────────────────────
# Start a container, run multiple commands
CONTAINER_ID=$(docker run -d \
    -e ANTHROPIC_API_KEY \
    -v "$(pwd)":/workspace \
    --entrypoint tail \
    claude-agent -f /dev/null)

# Run multiple tasks in the same container
docker exec "$CONTAINER_ID" claude-agent run "analyze the codebase"
docker exec "$CONTAINER_ID" claude-agent run "fix the failing tests"
docker exec "$CONTAINER_ID" claude-agent run "add documentation"

# Clean up
docker stop "$CONTAINER_ID"
docker rm "$CONTAINER_ID"

# ── Method 5: Pipe input ─────────────────────────────────────────────
# Pipe a diff for review
git diff | docker run --rm -i \
    -e ANTHROPIC_API_KEY \
    -v "$(pwd)":/workspace \
    claude-agent run -
