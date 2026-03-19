#!/usr/bin/env bash
# Example: Multi-turn development session
set -euo pipefail

PROJECT="my-api"

# Turn 1: Set up the project
claude-agent chat --session "$PROJECT" "Create a new FastAPI project with:
- User authentication (JWT)
- SQLAlchemy models for users and posts
- Alembic migrations
- Basic CRUD endpoints"

# Turn 2: Add tests (continues from previous context)
claude-agent chat --session "$PROJECT" "Now add comprehensive pytest tests for all endpoints.
Use httpx for async test client."

# Turn 3: Add Docker support
claude-agent chat --session "$PROJECT" "Add a Dockerfile and docker-compose.yml with
PostgreSQL for the database."

# Check session history
claude-agent session list
