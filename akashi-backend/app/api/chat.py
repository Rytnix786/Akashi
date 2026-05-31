"""
Akashi — Cross-Lingual Gemini RAG Chatbot API Route
==================================================
Implements farmer advisory services utilizing semantic vector retrieval and
Generative AI responses. Features rate limiting, safety filters, and audit logs.

Reference: Akashi MVP Spec Section 5.3 & RAG Chatbot Phase 2
"""

import os
import logging
import datetime
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
import httpx
from app.db.connection import db
from app.api.auth import get_current_farmer
from app.services.rag import rag_service
from app.models.schemas import ChatRequest, ChatResponse, ChatCitation

logger = logging.getLogger("akashi.chat")
router = APIRouter(prefix="/chat", tags=["agronomic-chatbot"])

# Dynamic threshold config
SIMILARITY_THRESHOLD = 0.7
DAILY_CHAT_LIMIT = 10

# Official Bengali safety warning appended to chemical recommendations
OFFICIAL_CHEMICAL_WARNING = (
    "\n\n🚨 **সতর্কতা:** কীটনাশক বা রাসায়নিক ব্যবহারের পূর্বে বোতলের নির্দেশাবলী ভালো করে পড়ুন। "
    "সবসময় নিরাপদ দূরত্ব বজায় রাখুন এবং মুখে মাস্ক ও হাতে গ্লাভস ব্যবহার করুন।"
)

# Bengali refusal message if similarity match is < 0.7
NO_KNOWLEDGE_REFUSAL = (
    "দুঃখিত, আপনার প্রশ্নের জন্য আমাদের কৃষি তথ্যভাণ্ডারে পর্যাপ্ত তথ্য খুঁজে পাওয়া যায়নি। "
    "সঠিক ও নিরাপদ পরামর্শের জন্য অনুগ্রহ করে আপনার নিকটস্থ উপ-সহকারী কৃষি কর্মকর্তা (কৃষি অফিস) "
    "অথবা কৃষি তথ্য সার্ভিসের হেল্পলাইন ১৬১২৩ নম্বরে যোগাযোগ করুন।"
)

def contains_chemical_terms(text: str) -> bool:
    """Checks if the text mentions any chemical fungicides, pesticides or application terms."""
    chemical_patterns = [
        "বিষ", "কীটনাশক", "পেস্টিসাইড", "ফাঙ্গিসাইড", "fungicide", "pesticide",
        "mancozeb", "mancozeb", "propiconazole", "propiconazole", "ম্যানকোজেব", 
        "প্রোপিকোনাজল", "ডাইথেন", "কার্বোফুরান", "ফুরাডান", "লরসবান", "কপার", "সালফার"
    ]
    text_lower = text.lower()
    return any(pattern in text_lower for pattern in chemical_patterns)

async def check_and_update_rate_limit(farmer: Dict[str, Any]) -> None:
    """
    Enforces a strict rate limit of 10 chat advisories per day.
    Automatically resets quota if the calendar date has changed.
    """
    farmer_id = farmer["id"]
    today = datetime.date.today()
    
    db_reset_date_str = farmer.get("chat_count_reset_date")
    daily_count = farmer.get("daily_chat_count", 0)

    # Clean date conversion
    if isinstance(db_reset_date_str, str):
        try:
            db_reset_date = datetime.datetime.strptime(db_reset_date_str, "%Y-%m-%d").date()
        except ValueError:
            db_reset_date = today
    elif isinstance(db_reset_date_str, datetime.date):
        db_reset_date = db_reset_date_str
    else:
        db_reset_date = today

    # Reset counter if calendar date changed
    if db_reset_date < today:
        daily_count = 0
        await db.update(
            table="farmers",
            data={
                "daily_chat_count": 0,
                "chat_count_reset_date": today.isoformat()
            },
            filters={"id": f"eq.{farmer_id}"}
        )
        logger.info(f"Reset daily chat count for farmer {farmer_id}")
    
    # Block if quota exceeded
    if daily_count >= DAILY_CHAT_LIMIT:
        raise HTTPException(
            status_code=status.HTTP_429_TOO_MANY_REQUESTS,
            detail="দৈনিক চ্যাট সীমা অতিক্রম করেছেন! ২৪ ঘণ্টায় সর্বোচ্চ ১০টি প্রশ্নের সীমা রয়েছে। অনুগ্রহ করে আগামীকাল আবার চেষ্টা করুন।"
        )

async def increment_chat_usage(farmer_id: str, current_count: int) -> None:
    """Increments the farmer's daily conversational transaction count."""
    await db.update(
        table="farmers",
        data={"daily_chat_count": current_count + 1},
        filters={"id": f"eq.{farmer_id}"}
    )

async def call_gemini_agronomist_api(
    query: str, RAG_context: str, api_key: str, farmer_crop: str
) -> str:
    """
    Queries Google's Gemini 2.5 Flash endpoint, passing our robust agronomist system prompt
    and context chunks. Returns compiled Bengali advice text.

    # STUB: Replace with real Gemini API once deployed in production
    """
    if not api_key or api_key == "change_this_to_your_actual_gemini_api_key":
        return generate_mock_agronomist_response(query, RAG_context, farmer_crop)

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-2.5-flash:generateContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    
    # Agronomist system prompt setup
    system_instruction = (
        "You are 'আকাশি' (Akashi) chatbot, an elite agricultural agronomist advising Bangladeshi farmers. "
        "Your mission is to provide accurate, warm, practical advice strictly based on the retrieved context documents. "
        "Rules:\n"
        "1. Answer strictly in fluent, clear Bengali.\n"
        "2. Do not offer assumptions outside of the context. If details are missing, state it clearly.\n"
        "3. Provide advice in easy bullet points.\n"
        "4. Address the farmer with respect ('আপনি/আপনার')."
    )

    prompt = (
        f"Retrieved Research Context:\n{RAG_context}\n\n"
        f"Farmer Query: {query}\n\n"
        f"Farmer Registered Crop: {farmer_crop}\n\n"
        f"Agronomist response:"
    )

    payload = {
        "contents": [
            {
                "parts": [{"text": prompt}]
            }
        ],
        "generationConfig": {
            "temperature": 0.2,
            "maxOutputTokens": 800
        },
        "systemInstruction": {
            "parts": [{"text": system_instruction}]
        }
    }

    try:
        async with httpx.AsyncClient(timeout=20.0) as client:
            response = await client.post(url, json=payload, headers=headers)
            if response.status_code == 200:
                res_data = response.json()
                # Parse standard Gemini response text
                text_out = res_data["candidates"][0]["content"]["parts"][0]["text"]
                return text_out.strip()
            
            logger.warning(f"Gemini API returned {response.status_code}. Fallback activated.")
    except Exception as e:
        logger.debug(f"Gemini LLM network error: {str(e)}. Fallback activated.")

    return generate_mock_agronomist_response(query, RAG_context, farmer_crop)

def generate_mock_agronomist_response(query: str, context: str, crop: str) -> str:
    """
    Generates a deterministic high-fidelity mock agronomy response in Bengali.
    Provides useful local advising when network is offline.
    """
    query_lower = query.lower()
    
    if "brown" in query_lower or "spots" in query_lower or "বাদামি" in query_lower or "দাগ" in query_lower:
        return (
            "ধানের বাদামি দাগ রোগ (Rice Brown Spot) সনাক্ত করা হয়েছে। প্রতিকারের জন্য নিম্নলিখিত পদক্ষেপগুলো গ্রহণ করুন:\n\n"
            "• **সার ব্যবস্থাপনা:** ইউরিয়া সারের অতিরিক্ত ব্যবহার পরিহার করুন এবং জমিতে সুষম হারে পটাশ সার (Muriate of Potash) ব্যবহার নিশ্চিত করুন।\n"
            "• **বীজ শোধন:** বপনের পূর্বে পরিষ্কার ও প্রত্যয়িত রোগমুক্ত বীজ ব্যবহার করুন। বীজ শোধনের জন্য গরম পানি পদ্ধতি ব্যবহার করতে পারেন।\n"
            "• **রাসায়নিক দমন:** আক্রমণ তীব্র আকার ধারণ করলে উপ-সহকারী কৃষি কর্মকর্তার পরামর্শে ম্যানকোজেব (Dithane M-45) অথবা প্রোপিকোনাজল (Tilt 250 EC) নির্দেশিত মাত্রায় স্প্রে করুন।"
        )
    
    # Generic agronomic response matching registered crop context
    crop_name = crop or "ধান"
    return (
        f"আপনার {crop_name} চাষের পরামর্শের জন্য ধন্যবাদ। আমাদের কৃষি তথ্যভাণ্ডার অনুযায়ী:\n\n"
        "• জমির ড্রেনেজ ব্যবস্থা সচল রাখুন এবং অতিরিক্ত পানি জমতে দেবেন না।\n"
        "• ফসলের নিয়মিত বৃদ্ধি পর্যবেক্ষণ করুন এবং সুষম জৈব সার ব্যবহার করুন।\n"
        "• কোনো অস্বাভাবিক পোকার আক্রমণ দেখলে আক্রান্ত পাতা দ্রুত কেটে ধ্বংস করুন।"
    )


@router.post("", response_model=ChatResponse)
async def ask_agronomist_chatbot(
    payload: ChatRequest,
    current_farmer: Dict[str, Any] = Depends(get_current_farmer)
):
    """
    FastAPI conversational chat endpoint for registered farmers.
    Applies RAG matching, daily rate limits, safe LLM-bypass refusal,
    Gemini response generation, and post-processed chemical usage warnings.
    """
    if current_farmer.get("id") is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="কৃষক প্রোফাইল সম্পূর্ণ নিবন্ধন না করে চ্যাট সেবা ব্যবহার করা যাবে না।"
        )

    farmer_id = current_farmer["id"]
    farmer_crop = current_farmer.get("crop_type", "ধান") # fallback to rice

    # 1. Enforce strict Daily Rate Limit of 10 messages
    await check_and_update_rate_limit(current_farmer)

    query = payload.query.strip()
    logger.info(f"Chat request from farmer {farmer_id}: {query}")

    # 2. Query RAG vector chunks
    # Threshold = 0.7, retrieve top 3 chunks
    chunks = await rag_service.retrieve_context(query, threshold=SIMILARITY_THRESHOLD, limit=3)

    citations = []
    response_text = ""

    # 3. Apply Bypass Refusal if highest score similarity < 0.7
    # Note: fallback dummy chunks from _retrieve_local_fallback carry mock similarity score
    if not chunks or (chunks[0].get("similarity", 0.0) < SIMILARITY_THRESHOLD):
        logger.info(f"Query similarity below {SIMILARITY_THRESHOLD}. LLM bypassed, returning refusal.")
        response_text = NO_KNOWLEDGE_REFUSAL
    else:
        # Assemble Citations list
        for c in chunks:
            citations.append(ChatCitation(
                source_file=c["source_file"],
                chunk_index=c["chunk_index"],
                similarity=c["similarity"]
            ))

        # 4. Generate RAG Answer using Gemini 2.5 Flash
        context_str = "\n---\n".join([item["content"] for item in chunks])
        api_key = os.getenv("GEMINI_API_KEY", "")
        
        response_text = await call_gemini_agronomist_api(
            query=query,
            RAG_context=context_str,
            api_key=api_key,
            farmer_crop=farmer_crop
        )

        # 5. Apply Safety Post-processing filter
        # If chemical fungicides are mentioned without safety warning, append it
        if contains_chemical_terms(response_text) and "সতর্কতা" not in response_text:
            logger.info("Safety alert triggered: appending chemical application warning.")
            response_text += OFFICIAL_CHEMICAL_WARNING

    try:
        # 6. Log transaction details to audit log
        citations_json = [item.model_dump() for item in citations]
        await db.insert("chat_logs", {
            "farmer_id": farmer_id,
            "query": query,
            "response": response_text,
            "source_citations": citations_json
        })

        # 7. Increment farmer's daily limit
        current_count = current_farmer.get("daily_chat_count", 0)
        await increment_chat_usage(farmer_id, current_count)
    except Exception as e:
        logger.error(f"Failed to log chat metrics to database: {str(e)}")

    # 8. Return response payload
    return ChatResponse(
        response=response_text,
        citations=citations
    )
