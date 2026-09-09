from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from core.llm import get_chat_session
from tools.time_tool import get_current_time
from tools.currency_tool import get_currency_exchange_rate
import traceback
import uvicorn
import json

app = FastAPI(title="AI Voice Assistant API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

chat_session = get_chat_session()

class QueryRequest(BaseModel):
    message: str

class QueryResponse(BaseModel):
    reply: str
    tool_used: str | None = None

@app.post("/chat")
async def chat_endpoint(payload: QueryRequest):
    user_msg = payload.message.strip()
    if not user_msg:
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    
    # Broad Tool detection (Hindi, English, Marathi)
    tool_tag = None
    lower_msg = user_msg.lower()
    injected_context = ""
    
    if any(w in lower_msg for w in ["time", "samay", "baje", "kiti", "vajle", "vel"]):
        tool_tag = "Time Tool"
        injected_context = f"\n[System Note: The current time is {get_current_time()}. Use this info to answer the user.]"
    elif any(w in lower_msg for w in ["dollar", "inr", "currency", "rate", "rupya", "rupaye"]):
        tool_tag = "Currency Tool"
        injected_context = f"\n[System Note: {get_currency_exchange_rate('USD', 'INR')}. Use this info to answer the user.]"

    prompt = user_msg + injected_context

    async def event_generator():
        try:
            if tool_tag:
                yield json.dumps({"tool_used": tool_tag}) + "\n"
            
            response = chat_session.send_message(prompt, stream=True)
            for chunk in response:
                if chunk.text:
                    yield json.dumps({"chunk": chunk.text}) + "\n"
        except Exception as e:
            print("Backend Error Details:")
            traceback.print_exc()
            error_msg = str(e)
            if "Quota exceeded" in error_msg or "429" in error_msg:
                yield json.dumps({"chunk": "\nYou have exceeded the Google Gemini API free rate limit. Please wait 1 minute and try again."}) + "\n"
            else:
                yield json.dumps({"error": error_msg}) + "\n"

    return StreamingResponse(event_generator(), media_type="application/x-ndjson")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)