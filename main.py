from fastapi import FastAPI, Depends, WebSocket, WebSocketDisconnect
from fastapi.middleware.cors import CORSMiddleware
from sqlalchemy.orm import Session
from typing import Dict, List
from .database import Base, engine, get_db
from . import models, schemas
from .matching import find_match, room_id_for_users
from .ai import generate_reply, check_gemini_status
from .schemas import RoadmapRequest, RoadmapOut
from .ai import generate_roadmap

app = FastAPI(title="MoodMatch API", version="0.1.0")

# Allow all origins for now
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# Create tables
Base.metadata.create_all(bind=engine)

@app.get("/health")
def health():
    return {"status": "ok"}

@app.get("/ai/status")
def ai_status():
    ok, msg = check_gemini_status()
    return {"gemini_api": ok, "message": msg}

@app.post("/register_user", response_model=schemas.UserOut)
def register_user(user: schemas.UserCreate, db: Session = Depends(get_db)):
    existing = db.query(models.User).filter(models.User.username == user.username).first()
    if existing:
        return existing
    obj = models.User(username=user.username, gender=user.gender, location=user.location)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj

@app.post("/mood", response_model=schemas.MoodOut)
def set_mood(mood_in: schemas.MoodCreate, db: Session = Depends(get_db)):
    obj = models.Mood(user_id=mood_in.user_id, mood=mood_in.mood)
    db.add(obj)
    db.commit()
    db.refresh(obj)
    return obj

@app.post("/match/find")
def match_find(req: schemas.MatchRequest, db: Session = Depends(get_db)):
    other_id, mood = find_match(db, req.user_id)
    if not other_id:
        return {"match": None}
    room_id = room_id_for_users(req.user_id, other_id)
    other = db.query(models.User).filter(models.User.id == other_id).first()
    return {
        "match": {
            "user_id": other_id,
            "username": other.username if other else "unknown",
            "shared_mood": mood,
            "room_id": room_id
        }
    }

# -----------------------------
# ✅ WebSocket Chat Manager
# -----------------------------
class ConnectionManager:
    def __init__(self):
        self.rooms: Dict[str, List[WebSocket]] = {}

    async def connect(self, room_id: str, websocket: WebSocket):
        await websocket.accept()
        if room_id not in self.rooms:
            self.rooms[room_id] = []
        self.rooms[room_id].append(websocket)

    def disconnect(self, room_id: str, websocket: WebSocket):
        if room_id in self.rooms and websocket in self.rooms[room_id]:
            self.rooms[room_id].remove(websocket)

    async def broadcast(self, room_id: str, message: str):
        if room_id in self.rooms:
            living = []
            for ws in self.rooms[room_id]:
                try:
                    await ws.send_text(message)
                    living.append(ws)
                except:
                    pass
            self.rooms[room_id] = living

manager = ConnectionManager()

# -----------------------------
# ✅ WebSocket endpoint
# -----------------------------
@app.websocket("/ws/{room_id}/{user_id}")
async def websocket_chat(websocket: WebSocket, room_id: str, user_id: int):
    await manager.connect(room_id, websocket)
    await manager.broadcast(room_id, f"User {user_id} joined the room")
    try:
        while True:
            text = await websocket.receive_text()
            if text.strip() == "__leave__":
                await manager.broadcast(room_id, f"User {user_id} left the room")
                break
            await manager.broadcast(room_id, f"User {user_id}: {text}")
    except WebSocketDisconnect:
        await manager.broadcast(room_id, f"User {user_id} disconnected")
        manager.disconnect(room_id, websocket)
    finally:
        manager.disconnect(room_id, websocket)

@app.post("/ai/talk")
def ai_talk(payload: dict):
    mood = payload.get("mood", "neutral")
    message = payload.get("message", "")
    reply = generate_reply(mood, message)
    return {"reply": reply}

@app.post("/maps/roadmap", response_model=RoadmapOut)
def maps_roadmap(req: RoadmapRequest):
    roadmap = generate_roadmap(req.working_hours, req.goals, req.stress_level)
    return {"roadmap": roadmap}
