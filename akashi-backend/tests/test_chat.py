"""
Akashi — Conversational Chatbot API Endpoint Unit Tests
======================================================
Tests JWT security guards, daily chat rate limits (10 messages/day), automatic date resets,
low-similarity knowledge refusals, mock agronomist advices, and chemical safety warnings.
Uses FastAPI app.dependency_overrides for robust framework-level mocking.
"""

import sys
import datetime
import pytest
from pathlib import Path
from unittest.mock import AsyncMock, patch, MagicMock
from fastapi.testclient import TestClient

# Add project root to path
sys.path.append(str(Path(__file__).parent.parent))

from main import app
from app.api.auth import get_current_farmer
from app.api.chat import NO_KNOWLEDGE_REFUSAL, OFFICIAL_CHEMICAL_WARNING

client = TestClient(app)


# ─── 1. Security & Authentication Checks ─────────────────────────────────────

def test_ask_chatbot_unauthorized():
    """Verifies that accessing `/chat` without a valid JWT token is blocked."""
    # Ensure overrides are clear
    app.dependency_overrides.clear()
    
    response = client.post("/chat", json={"query": "আমার ধান পাতায় দাগ"})
    assert response.status_code == 401


# ─── 2. Rate Limiting & Quota Management Tests ────────────────────────────────

@pytest.mark.asyncio
async def test_chatbot_rate_limit_exceeded():
    """Verifies that a farmer who has reached their 10 daily messages limit is blocked with a 429 error."""
    mock_farmer = {
        "id": "farmer-id-123",
        "phone": "+8801712345678",
        "district": "Tangail",
        "crop_type": "ধান",
        "daily_chat_count": 10,
        "chat_count_reset_date": datetime.date.today().isoformat()
    }

    # Override get_current_farmer dependency at the FastAPI framework level
    app.dependency_overrides[get_current_farmer] = lambda: mock_farmer

    try:
        headers = {"Authorization": "Bearer mock_jwt_token_test"}
        response = client.post("/chat", json={"query": "আমার ধানে সার কতটুকু লাগবে?"}, headers=headers)
        
        # Verify 429 Too Many Requests
        assert response.status_code == 429
        assert "দৈনিক চ্যাট সীমা অতিক্রম" in response.json()["detail"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_chatbot_rate_limit_calendar_reset():
    """Verifies that the rate limit resets to 0 if the calendar date has changed."""
    yesterday = datetime.date.today() - datetime.timedelta(days=1)
    mock_farmer = {
        "id": "farmer-id-123",
        "phone": "+8801712345678",
        "district": "Tangail",
        "crop_type": "ধান",
        "daily_chat_count": 10, # Quota reached yesterday
        "chat_count_reset_date": yesterday.isoformat()
    }

    app.dependency_overrides[get_current_farmer] = lambda: mock_farmer

    try:
        # Mock DB updates and insert metrics logging
        with patch("app.db.connection.db.update", new_callable=AsyncMock) as mock_db_update:
            with patch("app.db.connection.db.insert", new_callable=AsyncMock) as mock_db_insert:
                with patch("app.services.rag.rag_service.retrieve_context", new_callable=AsyncMock, return_value=[]):
                    
                    headers = {"Authorization": "Bearer mock_jwt_token_test"}
                    response = client.post("/chat", json={"query": "আমার ধানে সার কতটুকু লাগবে?"}, headers=headers)
                    
                    # Should reset successfully and return the refusal status response
                    assert response.status_code == 200
                    # Assert database update reset was triggered for this farmer ID
                    mock_db_update.assert_any_call(
                        table="farmers",
                        data={"daily_chat_count": 0, "chat_count_reset_date": datetime.date.today().isoformat()},
                        filters={"id": "eq.farmer-id-123"}
                    )
    finally:
        app.dependency_overrides.clear()


# ─── 3. Low Match Refusal Bypass Tests ──────────────────────────────────────

@pytest.mark.asyncio
async def test_chatbot_low_similarity_refusal():
    """Verifies that queries with low similarity scores (< 0.7) bypass the LLM and return safe refusal."""
    mock_farmer = {
        "id": "farmer-id-123",
        "phone": "+8801712345678",
        "district": "Tangail",
        "crop_type": "ধান",
        "daily_chat_count": 0,
        "chat_count_reset_date": datetime.date.today().isoformat()
    }

    # Retrieve context returns low matching chunks (similarity = 0.58)
    low_match_chunks = [{
        "id": "fallback-id",
        "content": "Random unrelated text",
        "source_file": "random.txt",
        "chunk_index": 0,
        "similarity": 0.58
    }]

    app.dependency_overrides[get_current_farmer] = lambda: mock_farmer

    try:
        with patch("app.services.rag.rag_service.retrieve_context", new_callable=AsyncMock, return_value=low_match_chunks):
            with patch("app.db.connection.db.insert", new_callable=AsyncMock):
                
                headers = {"Authorization": "Bearer mock_jwt_token_test"}
                response = client.post("/chat", json={"query": "কিভাবে মোটরসাইকেল চালাতে হয়?"}, headers=headers)
                
                assert response.status_code == 200
                data = response.json()
                assert data["response"] == NO_KNOWLEDGE_REFUSAL
                assert len(data["citations"]) == 0
    finally:
        app.dependency_overrides.clear()


# ─── 4. Conversational Agronomist Responses & Warnings Tests ──────────────────

@pytest.mark.asyncio
async def test_chatbot_agronomist_advisory():
    """Verifies chatbot advisory responses and citations matching the query."""
    mock_farmer = {
        "id": "farmer-id-123",
        "phone": "+8801712345678",
        "district": "Tangail",
        "crop_type": "ধান",
        "daily_chat_count": 0,
        "chat_count_reset_date": datetime.date.today().isoformat()
    }

    high_match_chunks = [{
        "id": "rag-chunk-id",
        "content": "Rice brown spot Helminthosporium oryzae causes spot lesions on leaves.",
        "source_file": "brri_manual.pdf",
        "chunk_index": 2,
        "similarity": 0.89
    }]

    app.dependency_overrides[get_current_farmer] = lambda: mock_farmer

    try:
        with patch("app.services.rag.rag_service.retrieve_context", new_callable=AsyncMock, return_value=high_match_chunks):
            with patch("app.db.connection.db.insert", new_callable=AsyncMock):
                
                headers = {"Authorization": "Bearer mock_jwt_token_test"}
                response = client.post("/chat", json={"query": "আমার ধানে বাদামি দাগ রোগ হয়েছে কি করব?"}, headers=headers)
                
                assert response.status_code == 200
                data = response.json()
                # Check for standard mock advisor answers
                assert "বাদামি দাগ" in data["response"]
                assert "সার" in data["response"]
                assert len(data["citations"]) == 1
                assert data["citations"][0]["source_file"] == "brri_manual.pdf"
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_chatbot_chemical_safety_warning_filter():
    """Verifies that mentioning dynamic chemical compounds automatically appends the agronomist safety warnings."""
    mock_farmer = {
        "id": "farmer-id-123",
        "phone": "+8801712345678",
        "district": "Tangail",
        "crop_type": "ধান",
        "daily_chat_count": 0,
        "chat_count_reset_date": datetime.date.today().isoformat()
    }

    high_match_chunks = [{
        "id": "rag-chunk-id",
        "content": "Integrated disease management instructions",
        "source_file": "brri_manual.pdf",
        "chunk_index": 0,
        "similarity": 0.85
    }]

    # Mock the LLM to return advice containing chemical names (such as Propiconazole or Mancozeb)
    mock_llm_text = "জমিতে ছত্রাক দেখা দিলে প্রোপিকোনাজল (Propiconazole) স্প্রে করতে হবে।"

    app.dependency_overrides[get_current_farmer] = lambda: mock_farmer

    try:
        with patch("app.services.rag.rag_service.retrieve_context", new_callable=AsyncMock, return_value=high_match_chunks):
            with patch("app.api.chat.call_gemini_agronomist_api", new_callable=AsyncMock, return_value=mock_llm_text):
                with patch("app.db.connection.db.insert", new_callable=AsyncMock):
                    
                    headers = {"Authorization": "Bearer mock_jwt_token_test"}
                    response = client.post("/chat", json={"query": "কীটনাশক ব্যবহার করতে হবে?"}, headers=headers)
                    
                    assert response.status_code == 200
                    data = response.json()
                    # Check that the chemical warning was successfully dynamically appended!
                    assert OFFICIAL_CHEMICAL_WARNING in data["response"]
                    assert "প্রোপিকোনাজল" in data["response"]
    finally:
        app.dependency_overrides.clear()
