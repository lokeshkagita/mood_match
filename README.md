# MoodMatch Backend (FastAPI)

## Setup
```bash
cd backend
python -m venv .venv
# On Windows: .venv\Scripts\activate
# On macOS/Linux: source .venv/bin/activate
pip install -r requirements.txt
uvicorn app.main:app --host 0.0.0.0 --port 8000 --reload
```

The server uses a local SQLite database `app.db` in the backend directory.
Endpoints:
- `POST /register_user` -> `{username, gender, location}`
- `POST /mood` -> `{user_id, mood}`
- `POST /match/find` -> `{user_id}`
- `POST /ai/talk` -> `{mood, message}`
- `WS /ws/chat/{room_id}` for realtime chat