# Task: Create a Hello World web server

Create a simple Python Flask web server in /workspace/hello-app/ with:

1. A Flask app with these routes:
   - GET / → returns {"message": "Hello, World!", "status": "ok"}
   - GET /health → returns {"healthy": true}
   - GET /greet/<name> → returns {"message": "Hello, <name>!"}

2. A requirements.txt with flask

3. A test file (test_app.py) using pytest that tests all 3 routes

4. Verify: install dependencies, run all tests, confirm they pass
