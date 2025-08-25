from pydantic import BaseModel
from typing import Optional, List

class UserCreate(BaseModel):
    username: str
    location: str
    gender: str

class UserOut(BaseModel):
    id: int
    username: str
    location: str
    gender: str
    last_mood: Optional[str] = None

    class Config:
        from_attributes = True

class MoodIn(BaseModel):
    user_id: int
    mood: str

class TalkIn(BaseModel):
    user_id: int
    mood: str
    message: str

class MatchCreate(BaseModel):
    user_id: int
    other_id: int

class MatchOut(BaseModel):
    id: int
    user1_id: int
    user2_id: int

    class Config:
        from_attributes = True
