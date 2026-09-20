from typing import Optional
from fastapi import FastAPI, HTTPException, Depends, Header
from fastapi.middleware.cors import CORSMiddleware
from fastapi.responses import StreamingResponse
from pydantic import BaseModel
from sqlalchemy.orm import Session
from fastapi.security import OAuth2PasswordRequestForm
from datetime import timedelta
import traceback
import uvicorn
import json
import uuid
import chromadb

# DB & Models Import
from core.database import engine, Base, get_db, SessionLocal
import models
from core.auth import get_password_hash, verify_password, create_access_token, get_current_user, ACCESS_TOKEN_EXPIRE_MINUTES
from models import User

# Tools & LLM Import
from core.llm import stream_chat_response
from tools.time_tool import get_current_time
from tools.currency_tool import get_currency_exchange_rate

# डेटाबेस टेबल्स तयार करा (नसतील तर)
Base.metadata.create_all(bind=engine)

# ChromaDB Setup
chroma_client = chromadb.PersistentClient(path="./chroma_db")
chroma_collection = chroma_client.get_or_create_collection(name="chat_history")

app = FastAPI(title="AI Voice Assistant API")

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=False,
    allow_methods=["*"],
    allow_headers=["*"],
)

class UserCreate(BaseModel):
    username: str
    password: str

class QueryRequest(BaseModel):
    message: str
    provider: str = "gemini"

class QueryResponse(BaseModel):
    reply: str
    tool_used: str | None = None

@app.post("/register")
def register(user: UserCreate, db: Session = Depends(get_db)):
    db_user = db.query(User).filter(User.username == user.username).first()
    if db_user:
        raise HTTPException(status_code=400, detail="Username already registered")
    hashed_password = get_password_hash(user.password)
    new_user = User(username=user.username, hashed_password=hashed_password)
    db.add(new_user)
    db.commit()
    db.refresh(new_user)
    return {"message": "User created successfully"}

@app.post("/login")
def login(form_data: OAuth2PasswordRequestForm = Depends(), db: Session = Depends(get_db)):
    user = db.query(User).filter(User.username == form_data.username).first()
    if not user or not verify_password(form_data.password, user.hashed_password):
        raise HTTPException(status_code=400, detail="Incorrect username or password")
    
    access_token_expires = timedelta(minutes=ACCESS_TOKEN_EXPIRE_MINUTES)
    access_token = create_access_token(
        data={"sub": user.username}, expires_delta=access_token_expires
    )
    return {"access_token": access_token, "token_type": "bearer"}

@app.post("/chat")
async def chat_endpoint(
    payload: QueryRequest, 
    current_user: User = Depends(get_current_user),
    x_api_key: Optional[str] = Header(None)
):
    user_msg = payload.message.strip()
    if not user_msg:
        raise HTTPException(status_code=400, detail="Message cannot be empty")
    
    # Fetch Past Semantic Context from ChromaDB
    past_memory_context = ""
    try:
        results = chroma_collection.query(
            query_texts=[user_msg],
            n_results=3,
            where={"user_id": str(current_user.id)}
        )
        if results and results['documents'] and results['documents'][0]:
            past_docs = results['documents'][0]
            past_memory_context = "\n[Past Memory Context]:\n" + "\n".join(past_docs)
    except Exception as e:
        print("Chroma Query Error:", e)
    
    # Broad Tool detection (Hindi, English, Marathi)
    tool_tag = None
    lower_msg = user_msg.lower()
    injected_context = ""
    
    if any(w in lower_msg for w in ["time", "samay", "baje", "kiti", "vajle", "vel"]):
        tool_tag = "Time Tool"
        injected_context = f"\n[Tool Context: The current time is {get_current_time()}. Use this info to answer the user.]"
    elif any(w in lower_msg for w in ["dollar", "inr", "currency", "rate", "rupya", "rupaye"]):
        tool_tag = "Currency Tool"
        injected_context = f"\n[Tool Context: {get_currency_exchange_rate('USD', 'INR')}. Use this info to answer the user.]"

    prompt = past_memory_context + injected_context + "\n[User Query]: " + user_msg

    async def event_generator():
        complete_reply = []  # पूर्ण बॉट रिस्पॉन्स गोळा करण्यासाठी
        try:
            if tool_tag:
                yield json.dumps({"tool_used": tool_tag}) + "\n"
            
            response_stream = stream_chat_response(payload.provider, x_api_key, prompt)
            for chunk_text in response_stream:
                if chunk_text:
                    complete_reply.append(chunk_text)
                    yield json.dumps({"chunk": chunk_text}) + "\n"
            
            # --- स्ट्रिमिंग पूर्ण झाल्यावर डेटाबेसमध्ये सेव्ह करणे ---
            full_bot_response = "".join(complete_reply)
            if full_bot_response:
                db: Session = SessionLocal()
                try:
                    chat_entry = models.ChatHistory(
                        user_id=current_user.id,
                        user_message=user_msg,
                        bot_response=full_bot_response
                    )
                    db.add(chat_entry)
                    db.commit()
                    
                    # ChromaDB मध्ये सेव्ह करणे
                    try:
                        chroma_collection.add(
                            documents=[user_msg],
                            metadatas=[{
                                "bot_response": full_bot_response, 
                                "sender": "user",
                                "user_id": str(current_user.id),
                                "username": current_user.username
                            }],
                            ids=[str(uuid.uuid4())]
                        )
                    except Exception as chroma_err:
                        print("ChromaDB Save Error:", chroma_err)
                        
                except Exception as db_err:
                    print("Database Save Error:", db_err)
                finally:
                    db.close()

        except Exception as e:
            print("Backend Error Details:")
            traceback.print_exc()
            error_msg = str(e)
            if "Quota exceeded" in error_msg or "429" in error_msg:
                provider_name = "OpenAI" if payload.provider.lower() == "openai" else "Google Gemini"
                yield json.dumps({"chunk": f"\nYour {provider_name} API key has exceeded its quota or rate limit. Please check your billing or wait a moment."}) + "\n"
            else:
                yield json.dumps({"error": error_msg}) + "\n"

    return StreamingResponse(event_generator(), media_type="application/x-ndjson")

if __name__ == "__main__":
    uvicorn.run("main:app", host="0.0.0.0", port=8000, reload=True)