# Task: Build a REST API

## Operations

1. **Create a Python FastAPI project** in `/workspace/myapi/`
   - Set up virtual environment
   - Install FastAPI, uvicorn, sqlalchemy, alembic, pydantic
   - Create proper project structure with `app/`, `tests/`, `alembic/`

2. **Implement User model and auth**
   - SQLAlchemy User model (id, email, hashed_password, created_at)
   - JWT-based authentication (login, register endpoints)
   - Password hashing with bcrypt
   - Auth middleware/dependency

3. **Implement CRUD endpoints**
   - POST /api/users/register
   - POST /api/users/login
   - GET /api/users/me
   - PUT /api/users/me
   - DELETE /api/users/me

4. **Add tests**
   - pytest with httpx AsyncClient
   - Test all endpoints (happy path + error cases)
   - Test auth flow (register → login → access protected route)
   - Achieve >80% coverage

5. **Add Docker support**
   - Dockerfile for the API
   - docker-compose.yml with PostgreSQL
   - Health check endpoint at GET /health

6. **Verify everything**
   - All tests pass
   - Linting passes (ruff)
   - App starts without errors
   - Docker build succeeds
