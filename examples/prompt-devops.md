# Task: Set up a complete CI/CD-ready project

Create a production-ready Node.js Express API in /workspace/express-api/ with:

## Application

1. Express.js REST API with:
   - GET /api/health — health check with uptime and version
   - POST /api/items — create item (title, description required)
   - GET /api/items — list items (support pagination: ?page=1&limit=10)
   - GET /api/items/:id — get single item
   - DELETE /api/items/:id — delete item
2. In-memory storage (no database needed)
3. Request validation middleware
4. Error handling middleware
5. Request logging with morgan

## Testing

1. Jest test suite with supertest
2. Test all endpoints (happy path + error cases)
3. Test pagination logic
4. Test validation (missing fields, invalid data)

## DevOps

1. Dockerfile (multi-stage build: build → production)
2. .dockerignore
3. GitHub Actions workflow (.github/workflows/ci.yml):
   - Run tests on push/PR
   - Build Docker image
   - Lint with eslint
4. Makefile with targets: install, test, lint, build, run

## Verify

- npm install succeeds
- All tests pass
- Lint passes (eslint)
- Docker build succeeds
- App starts and /api/health responds
