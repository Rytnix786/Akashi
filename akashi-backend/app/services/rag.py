"""
Akashi — pgvector RAG Retrieval Service
=======================================
Calculates semantic query embeddings and retrieves highly relevant crop disease
advisories from pgvector knowledge bases using Supabase PostgREST RPC queries.

Reference: Akashi MVP Spec Section 4 / Phase 2
"""

import os
import logging
import hashlib
import re
from typing import List, Dict, Any, Optional
from pathlib import Path
import httpx
from dotenv import load_dotenv

logger = logging.getLogger("akashi.rag")

# Load environment variables
load_dotenv()

class RAGService:
    """
    Service to retrieve agronomic knowledge chunks matching farmers' queries.
    """
    def __init__(self):
        self.api_key = os.getenv("GEMINI_API_KEY", "")

    async def get_query_embedding(self, query: str) -> Optional[List[float]]:
        """
        Generates a 768-dimensional embedding for search queries using text-embedding-004.
        """
        embed_key = os.getenv("GOOGLE_EMBED_API_KEY", "")
        if not embed_key or embed_key == "change_this_to_your_actual_gemini_api_key":
            raise ValueError("GOOGLE_EMBED_API_KEY is missing or unconfigured")

        url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2:embedContent?key={embed_key}"
        headers = {"Content-Type": "application/json"}
        payload = {
            "model": "models/gemini-embedding-2",
            "content": {
                "parts": [{"text": query}]
            },
            "outputDimensionality": 768
        }

        async with httpx.AsyncClient(timeout=5.0) as client:
            response = await client.post(url, json=payload, headers=headers)
            response.raise_for_status()
            data = response.json()
            return data["embedding"]["values"]

    async def retrieve_context(
        self, query: str, threshold: float = 0.6, limit: int = 5
    ) -> List[Dict[str, Any]]:
        """
        Retrieves top-N knowledge chunks matching the search query from pgvector database.
        """
        from app.db.connection import db

        # 1. Translate query if Bengali to match English embeddings in Supabase
        is_bengali = any('\u0980' <= char <= '\u09FF' for char in query)
        search_query = query
        if is_bengali:
            try:
                from deep_translator import GoogleTranslator
                translated = GoogleTranslator(source='auto', target='en').translate(query)
                if translated:
                    search_query = translated
                    logger.info(f"Translated query '{query}' to English for RAG lookup: '{search_query}'")
            except Exception as e:
                logger.warning(f"Translation failed for query RAG lookup: {str(e)}")

        # 2. Embed query
        query_vector = await self.get_query_embedding(search_query)
        if not query_vector:
            return []

        try:
            # 3. Execute RPC vector similarity match in Supabase
            res = await db.rpc("match_knowledge_chunks", {
                "query_embedding": query_vector,
                "match_threshold": threshold,
                "match_count": limit
            })
            
            if res:
                return res
            return []
        except Exception as e:
            logger.error(f"Supabase pgvector query failed: {str(e)}")
            return []

# Singleton instance for easy imports across routes
rag_service = RAGService()
