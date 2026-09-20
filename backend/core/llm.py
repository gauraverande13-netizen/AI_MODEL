import os
import google.generativeai as genai
from openai import OpenAI
from dotenv import load_dotenv

load_dotenv()

SYSTEM_INSTRUCTION = "Your name is Gaurav's AI. You are a helpful and polite AI assistant. If asked about your name, say that you are Gaurav's AI. Keep your answers extremely concise and conversational, maximum 1 or 3 short sentences. Use very simple, easy-to-understand words, and always add a little bit of humor or a light joke to your replies."

def stream_chat_response(provider: str, api_key: str, prompt: str):
    if provider.lower() == "openai":
        actual_key = api_key or os.getenv("OPENAI_API_KEY")
        if not actual_key:
            raise ValueError("OpenAI API Key is missing. Please provide it in settings.")
            
        client = OpenAI(api_key=actual_key)
        try:
            response = client.chat.completions.create(
                model="gpt-4o-mini",
                messages=[
                    {"role": "system", "content": SYSTEM_INSTRUCTION},
                    {"role": "user", "content": prompt}
                ],
                stream=True
            )
            for chunk in response:
                if chunk.choices and chunk.choices[0].delta.content:
                    yield chunk.choices[0].delta.content
        except Exception as e:
            raise e

    else: # Default to gemini
        actual_key = api_key or os.getenv("GEMINI_API_KEY")
        if not actual_key:
            raise ValueError("Gemini API Key is missing. Please provide it in settings.")
            
        genai.configure(api_key=actual_key)
        model = genai.GenerativeModel(
            "models/gemini-flash-latest",
            system_instruction=SYSTEM_INSTRUCTION
        )
        try:
            chat = model.start_chat(history=[])
            response = chat.send_message(prompt, stream=True)
            for chunk in response:
                if chunk.text:
                    yield chunk.text
        except Exception as e:
            raise e