import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=api_key)



model = genai.GenerativeModel(
    "models/gemini-flash-latest",
    system_instruction="Your name is Gaurav's AI. You are a helpful and polite AI assistant. If asked about your name, say that you are Gaurav's AI. Keep your answers extremely concise and conversational, maximum 1 or 2 short sentences."
)

def get_chat_session():
    return model.start_chat(history=[])