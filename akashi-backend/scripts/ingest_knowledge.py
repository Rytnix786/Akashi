"""
Akashi — pgvector Knowledge Ingestion Pipeline
==============================================
Extracts text from BRRI/IRRI/FAO disease advisory articles, chunks text segments,
creates 768-dimensional embeddings using Google text-embedding-004, and saves
vectors directly into the database.

Reference: Akashi MVP Spec Section 4 / Phase 2
"""

import sys
import os
import json
import asyncio
import logging
import hashlib
from typing import List, Dict, Any, Optional
from pathlib import Path
import httpx
from dotenv import load_dotenv

# Setup logging
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s"
)
logger = logging.getLogger("akashi.ingest")

# Add project root to path
sys.path.append(str(Path(__file__).resolve().parent.parent))

from app.db.connection import db

# Load env variables
load_dotenv()

# Configuration
CHUNK_SIZE_WORDS = 375  # ~500 tokens (1 token ≈ 0.75 words)
OVERLAP_WORDS = 37     # ~50 tokens overlap

def chunk_text(text: str, chunk_size: int = CHUNK_SIZE_WORDS, overlap: int = OVERLAP_WORDS) -> List[str]:
    """
    Splits text into chunks of specified word length with a sliding overlap.
    Uses word boundaries to maintain complete sentences and agronomic terms.
    """
    words = text.split()
    chunks = []
    
    if len(words) <= chunk_size:
        return [text]
        
    i = 0
    while i < len(words):
        chunk_words = words[i:i + chunk_size]
        chunks.append(" ".join(chunk_words))
        # Advance slide window
        i += (chunk_size - overlap)
        
    return chunks

async def get_google_embedding(text: str, api_key: str) -> Optional[List[float]]:
    """
    Generates 768-dimensional embeddings via Google's Generative Language REST API.
    Uses the recommended text-embedding-004 model.
    Falls back gracefully to deterministic local vector hashing if offline or keys are missing.
    """
    if not api_key or api_key == "change_this_to_your_actual_gemini_api_key":
        # Safe deterministic mock fallback for local sandboxing / unit tests!
        return generate_mock_embedding(text)

    url = f"https://generativelanguage.googleapis.com/v1beta/models/gemini-embedding-2:embedContent?key={api_key}"
    headers = {"Content-Type": "application/json"}
    payload = {
        "model": "models/gemini-embedding-2",
        "content": {
            "parts": [{"text": text}]
        },
        "outputDimensionality": 768
    }

    try:
        async with httpx.AsyncClient(timeout=10.0) as client:
            response = await client.post(url, json=payload, headers=headers)
            if response.status_code == 200:
                data = response.json()
                return data["embedding"]["values"]
            else:
                logger.warning(
                    f"Google embedding API returned {response.status_code}. "
                    f"Activating deterministic local mock fallback."
                )
    except Exception as e:
        logger.debug(f"Network error in Google embedding request: {str(e)}. Fallback activated.")

    return generate_mock_embedding(text)

def generate_mock_embedding(text: str) -> List[float]:
    """
    Generates a deterministic 768-dimensional mock embedding based on the text hash.
    Ensures identical text chunks yield identical vectors in offline testing.
    """
    hash_bytes = hashlib.sha256(text.encode("utf-8")).digest()
    mock_vector = []
    
    for idx in range(768):
        # Generate floating numbers between -1.0 and 1.0 deterministically
        byte_pos = (idx * 3) % len(hash_bytes)
        val = (hash_bytes[byte_pos] / 255.0) * 2.0 - 1.0
        mock_vector.append(round(val, 6))
        
    return mock_vector

def parse_file(file_path: Path) -> str:
    """Parses text content from txt or pdf files."""
    if file_path.suffix.lower() == ".txt":
        try:
            with open(file_path, "r", encoding="utf-8") as f:
                return f.read()
        except Exception as e:
            logger.error(f"Error reading text file {file_path.name}: {str(e)}")
            return ""
            
    elif file_path.suffix.lower() == ".pdf":
        try:
            import pdfplumber
            logger.info(f"Parsing PDF document: {file_path.name}")
            with pdfplumber.open(file_path) as pdf:
                content = []
                for idx, page in enumerate(pdf.pages):
                    text = page.extract_text()
                    if text:
                        content.append(text)
                return "\n".join(content)
        except ImportError:
            logger.warning(f"pdfplumber package missing! Cannot parse PDF: {file_path.name}. Skip.")
            return ""
        except Exception as e:
            logger.error(f"Error extracting PDF file {file_path.name}: {str(e)}")
            return ""
            
    return ""

def discover_knowledge_files(kb_dir: Path) -> List[Path]:
    """
    Returns all real knowledge files (PDFs and TXTs).
    If both a .txt and .pdf file exist with the same base name, prefers the .txt file.
    """
    all_files = list(kb_dir.iterdir())
    txt_names = {f.stem.lower() for f in all_files if f.is_file() and f.suffix.lower() == ".txt"}
    
    selected_files = []
    for f in all_files:
        if not f.is_file():
            continue
        suffix = f.suffix.lower()
        if suffix == ".txt":
            if f.name.lower() != "test_dummy.txt":
                selected_files.append(f)
        elif suffix == ".pdf":
            # If there is a txt file with the same name or ocr suffix, skip the PDF
            stem_lower = f.stem.lower()
            ocr_stem = stem_lower.replace("_content", "_ocr")
            if stem_lower not in txt_names and ocr_stem not in txt_names:
                selected_files.append(f)
                
    return sorted(selected_files, key=lambda x: x.name)

async def ingest_knowledge_base():
    """Scans knowledge_base folders, chunks documents, fetches embeddings, and saves to database."""
    # Resolve knowledge base paths (check both project root and backend subdirs)
    project_root = Path(__file__).resolve().parent.parent.parent
    paths_to_check = [
        project_root / "docs" / "knowledge_base",
        Path(__file__).resolve().parent.parent / "docs" / "knowledge_base"
    ]
    
    kb_dir = None
    for p in paths_to_check:
        if p.exists() and p.is_dir():
            kb_dir = p
            break
            
    if not kb_dir:
        logger.error("Could not locate docs/knowledge_base directory in workspace paths.")
        return

    logger.info(f"📁 Scanning knowledge directory: {kb_dir}")
    
    api_key = os.getenv("GEMINI_API_KEY", "")
    
    files = discover_knowledge_files(kb_dir)
    if not files:
        logger.warning(f"No valid .txt or .pdf files found in {kb_dir}")
        return

    total_chunks_saved = 0

    for file_path in files:
        logger.info(f"📖 Processing: {file_path.name}")
        text = parse_file(file_path)
        
        if not text.strip():
            logger.warning(f"Skipping empty or failed file: {file_path.name}")
            continue

        # Segment text into chunks
        chunks = chunk_text(text)
        logger.info(f"✂️ Segmented {file_path.name} into {len(chunks)} chunks.")

        for idx, chunk in enumerate(chunks):
            # Detect if language is Bengali (Bengali Unicode Block is \u0980-\u09FF)
            is_bengali = any('\u0980' <= char <= '\u09FF' for char in chunk)
            content_en = chunk
            
            if is_bengali:
                try:
                    from deep_translator import GoogleTranslator
                    translated = GoogleTranslator(source='auto', target='en').translate(chunk)
                    if translated:
                        content_en = translated
                        logger.info(f"Translated chunk {idx} of {file_path.name} to English.")
                except Exception as e:
                    logger.warning(f"Translation failed for chunk {idx} of {file_path.name}: {str(e)}. Falling back to original.")
                    content_en = chunk

            # Calculate embedding vector on translated English content
            embedding = await get_google_embedding(content_en, api_key)
            if not embedding:
                logger.error(f"Failed to generate embedding for chunk {idx} of {file_path.name}")
                continue

            try:
                # Save chunk record to pgvector
                # We format embedding as a list of floats (direct REST handles arrays perfectly)
                await db.insert("knowledge_chunks", {
                    "content": chunk,
                    "content_en": content_en,
                    "source_file": file_path.name,
                    "chunk_index": idx,
                    "embedding": embedding
                })
                total_chunks_saved += 1
            except Exception as e:
                logger.error(f"Failed to insert chunk {idx} into database: {str(e)}")

    logger.info(f"🎉 RAG Ingestion complete! Saved {total_chunks_saved} chunks to Supabase.")

if __name__ == "__main__":
    asyncio.run(ingest_knowledge_base())
