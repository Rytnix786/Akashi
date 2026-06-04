"""
Akashi — pgvector RAG Knowledge Pipeline Unit Tests
===================================================
Tests word chunking limits, embedding vector dimensions, pgvector matching lookups,
and the local file retrieval fallback (test_dummy.txt) under database simulation failures.
"""

import sys
import pytest
from pathlib import Path
from unittest.mock import AsyncMock, patch, MagicMock

# Add project root to path
sys.path.append(str(Path(__file__).parent.parent))

from scripts.ingest_knowledge import chunk_text, discover_knowledge_files, generate_mock_embedding, get_google_embedding
from app.services.rag import RAGService, rag_service


# ─── 1. Text Chunking Tests ──────────────────────────────────────────────────

def test_chunk_text_boundaries():
    """Verifies that the word-boundary chunking slices text and overlap correctly."""
    sample_text = "one two three four five six seven eight nine ten"
    
    # Size 5, overlap 2
    chunks = chunk_text(sample_text, chunk_size=5, overlap=2)
    
    assert len(chunks) >= 2
    # First chunk: 'one two three four five'
    assert chunks[0] == "one two three four five"
    # Second chunk has overlap of 2 words: 'four five six seven eight'
    assert "four" in chunks[1] and "five" in chunks[1]


def test_chunk_text_short_boundaries():
    """Verifies that text shorter than chunk size returns a single chunk containing the whole text."""
    sample_text = "short text here"
    chunks = chunk_text(sample_text, chunk_size=10, overlap=2)
    assert len(chunks) == 1
    assert chunks[0] == sample_text


def test_discover_knowledge_files_prefers_real_pdfs(tmp_path):
    """Verifies that real PDFs are ingested instead of the local dummy text fixture."""
    real_pdf = tmp_path / "rice_manual.pdf"
    dummy_txt = tmp_path / "test_dummy.txt"
    real_pdf.write_bytes(b"%PDF-1.4\n")
    dummy_txt.write_text("dummy rice text", encoding="utf-8")

    files = discover_knowledge_files(tmp_path)

    assert files == [real_pdf]


# ─── 2. Vector Embedding Tests ───────────────────────────────────────────────

def test_generate_mock_embedding_dimensions():
    """Verifies that the mock embedding generator produces exactly 768 dimensions of floats."""
    vector = generate_mock_embedding("Helminthosporium oryzae")
    
    assert isinstance(vector, list)
    assert len(vector) == 768
    assert all(isinstance(val, float) for val in vector)
    
    # Must be deterministic (same chunk yields identical vectors)
    vector2 = generate_mock_embedding("Helminthosporium oryzae")
    assert vector == vector2


@pytest.mark.asyncio
async def test_get_google_embedding_fallback():
    """Verifies that get_google_embedding falls back to mock vector without crashing when keys are stubbed."""
    # API key is missing or dummy
    vector = await get_google_embedding("rice blast treatment", api_key="")
    assert len(vector) == 768
    
    vector_stub = await get_google_embedding("rice blast treatment", api_key="change_this_to_your_actual_gemini_api_key")
    assert len(vector_stub) == 768


# ─── 3. RAG Retrieval Tests ─────────────────────────────────────────────────

@pytest.mark.asyncio
async def test_retrieve_context_db_match():
    """Tests RAG query matching when Supabase database vector RPC is active."""
    query = "brown spot on rice leaf"
    mock_db_result = [
        {
            "id": "db-chunk-uuid-1",
            "content": "Brown spot causes brown lesions with yellow halos on rice leaves.",
            "source_file": "manual_spot.pdf",
            "chunk_index": 0,
            "similarity": 0.88
        }
    ]

    with patch("app.services.rag.rag_service.get_query_embedding", new_callable=AsyncMock, return_value=[0.1]*768):
        with patch("app.db.connection.db.rpc", new_callable=AsyncMock, return_value=mock_db_result):
            # We query and expect the mocked DB records to be returned
            results = await rag_service.retrieve_context(query)
            
            assert len(results) == 1
            assert results[0]["id"] == "db-chunk-uuid-1"
            assert results[0]["source_file"] == "manual_spot.pdf"
            assert results[0]["similarity"] == 0.88


@pytest.mark.asyncio
async def test_retrieve_context_db_error_returns_empty():
    """Tests RAG retrieval graceful return of empty list when DB encounters errors."""
    query = "treatment for brown spot"

    with patch("app.services.rag.rag_service.get_query_embedding", new_callable=AsyncMock, return_value=[0.1]*768):
        # We force the db.rpc call to raise an exception
        with patch("app.db.connection.db.rpc", new_callable=AsyncMock, side_effect=Exception("Database tables not found")):
            results = await rag_service.retrieve_context(query)
            assert results == []


@pytest.mark.asyncio
async def test_retrieve_context_missing_embedding_raises():
    """Tests that retrieve_context propagates exceptions if embedding generation fails."""
    query = "treatment for brown spot"

    with patch("app.services.rag.rag_service.get_query_embedding", new_callable=AsyncMock, side_effect=ValueError("Key missing")):
        with pytest.raises(ValueError):
            await rag_service.retrieve_context(query)
