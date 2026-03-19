# Task: Build a full-stack Todo app

Build a complete Todo application in /workspace/todo-app/ with a Python backend and a simple HTML/JS frontend.

## Backend (FastAPI)

1. Create a FastAPI app with SQLite database
2. Models: Todo (id, title, description, completed, created_at)
3. Endpoints:
   - POST /api/todos — create a todo
   - GET /api/todos — list all todos (support ?completed=true/false filter)
   - GET /api/todos/{id} — get single todo
   - PUT /api/todos/{id} — update a todo
   - DELETE /api/todos/{id} — delete a todo
   - GET /health — health check
4. Use Pydantic for request/response schemas
5. Add CORS middleware for frontend

## Frontend (static HTML)

1. Create a static/index.html with:
   - Form to add new todos
   - List of todos with checkboxes to toggle completion
   - Delete button for each todo
   - Filter buttons: All / Active / Completed
2. Use vanilla JavaScript (no frameworks)
3. Style with minimal CSS (clean, readable)

## Testing

1. Backend tests with pytest (test all CRUD operations)
2. At least 10 test cases

## Verify

- Install all dependencies
- Run all tests — they must pass
- Start the server and confirm it responds on /health
- Confirm static files are served
