from fastapi import FastAPI, HTTPException
from fastapi.middleware.cors import CORSMiddleware
from pydantic import BaseModel
from core.llm import get_chat_session
import traceback
import uvicorn

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

@app.post("/chat", response_model=QueryResponse)
async def chat_endpoint(payload: QueryRequest):
    user_msg = payload.message.strip()
    if not user_msg:
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    
    try:
        response = chat_session.send_message(user_msg)
        
        # Safe text extraction
        reply_text = ""
        try:
            reply_text = response.text
        except Exception:
            if response.candidates and response.candidates[0].content.parts:
                for part in response.candidates[0].content.parts:
                    if hasattr(part, 'text') and part.text:
                        reply_text += part.text
        
        if not reply_text:
            reply_text = "sorry i don't anderstood , please Tell me again."

        # Broad Tool detection (Hindi, English, Marathi)
        tool_tag = None
        lower_msg = user_msg.lower()
        if any(w in lower_msg for w in ["time", "samay", "baje", "kiti", "vajle", "vel"]):
            tool_tag = "Time Tool"
        elif any(w in lower_msg for w in ["dollar", "inr", "currency", "rate", "rupya", "rupaye"]):
            tool_tag = "Currency Tool"

        return QueryResponse(reply=reply_text, tool_used=tool_tag)

    except Exception as e:
        print("Backend Error Details:")
        traceback.print_exc()
        
        error_msg = str(e)
        if "Quota exceeded" in error_msg or "429" in error_msg:
            return QueryResponse(reply="You have exceeded the Google Gemini API free rate limit. Please wait 1 minute and try again.", tool_used=None)
            
        raise HTTPException(status_code=500, detail=error_msg)

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)