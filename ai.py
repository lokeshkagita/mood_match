import os
import google.generativeai as genai
from dotenv import load_dotenv

# Load .env
load_dotenv()

# Get API key
GEMINI_API_KEY = os.getenv("GEMINI_API_KEY", "")
if GEMINI_API_KEY:
    genai.configure(api_key=GEMINI_API_KEY)

def generate_reply(mood: str, message: str) -> str:
    """Generate an empathetic reply using Gemini if available, else fallback."""
    if GEMINI_API_KEY:
        try:
            prompt = f"You are a kind friend. The user feels {mood}. Reply empathetically.\nUser: {message}\nFriend:"
            model = genai.GenerativeModel("gemini-1.5-flash")
            resp = model.generate_content(prompt)
            return resp.text.strip()
        except Exception as e:
            return f"(AI-{mood}) Gemini error: {str(e)}"
    else:
        # Safe fallback
        templates = {
            "anger": "I can feel that fire. Want to vent more, or try a quick cool-down?",
            "depression": "You’re not alone. Small steps count—I'm here to listen.",
            "sad": "That sounds heavy. Want to talk it through together?",
            "happy": "Love that energy! What made your day?",
            "tired": "Rest matters. A tiny recharge break might help. How are you holding up?",
        }
        prefix = templates.get(mood.lower(), "I'm here for you.")
        return f"(AI - {mood}) {prefix} You said: '{message}'"
    
def generate_roadmap(working_hours: str, goals: str, stress_level: str):
    if not GEMINI_API_KEY:
        return [{"time": "N/A", "activity": "Gemini API key not set"}]

    prompt = f"""
    You are a wellbeing and productivity assistant.
    Create a daily roadmap schedule for a person with:
    - Working hours: {working_hours}
    - Goals: {goals}
    - Stress level: {stress_level}

    The roadmap must:
    - Include work tasks, meditation, exercise, wellbeing breaks.
    - Reduce stress, balance productivity + wellness.
    - Output in JSON list: [{{"time": "07:00 AM", "activity": "Meditation"}}, ...]
    """

    try:
        model = genai.GenerativeModel("gemini-1.5-flash")
        response = model.generate_content(prompt)
        roadmap_json = eval(response.text)  # AI should return JSON
        return roadmap_json
    except Exception as e:
        return [{"time": "Error", "activity": str(e)}]
    
def check_gemini_status():
    if not GEMINI_API_KEY:
        return False, "GEMINI_API_KEY is missing in environment."
    try:
        model = genai.GenerativeModel("gemini-1.5-flash")
        resp = model.generate_content("Hello Gemini! Are you working?")
        if resp and resp.text:
            return True, f"Gemini API working fine: {resp.text[:50]}..."
        return False, "No response from Gemini API."
    except Exception as e:
        return False, f"Error: {str(e)}"
