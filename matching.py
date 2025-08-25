from sqlalchemy import text

def find_match(db, user_id: int):
    # Get the latest mood of the current user
    latest = db.execute(
        text("SELECT mood FROM moods WHERE user_id = :uid ORDER BY id DESC LIMIT 1"),
        {"uid": user_id}
    ).fetchone()

    if not latest:
        return None, None

    user_mood = latest[0]

    # Find another user with the same mood
    match = db.execute(
        text("SELECT user_id, mood FROM moods WHERE mood = :mood AND user_id != :uid ORDER BY id DESC LIMIT 1"),
        {"mood": user_mood, "uid": user_id}
    ).fetchone()

    if match:
        return match[0], match[1]

    return None, None


# ✅ Add this missing function so main.py can import it
def room_id_for_users(user1: int, user2: int) -> str:
    """
    Generate a unique room ID for two users.
    Always orders the IDs to avoid duplicates.
    """
    users = sorted([user1, user2])
    return f"room_{users[0]}_{users[1]}"
