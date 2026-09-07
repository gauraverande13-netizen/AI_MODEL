import os
import google.generativeai as genai
from dotenv import load_dotenv

load_dotenv()

api_key = os.getenv("GEMINI_API_KEY")
genai.configure(api_key=api_key)

from tools.time_tool import get_current_time
from tools.currency_tool import get_currency_exchange_rate

model = genai.GenerativeModel(
    "models/gemini-flash-latest",
    tools=[get_current_time, get_currency_exchange_rate]
)

def get_chat_session():
    return model.start_chat(enable_automatic_function_calling=True, history=[])