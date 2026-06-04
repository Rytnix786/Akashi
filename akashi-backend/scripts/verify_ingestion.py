import asyncio
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

sys.path.append(str(Path(__file__).resolve().parent.parent))
from app.db.connection import db

async def verify():
    load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../.env"))
    
    print("Fetching chunks from Supabase...")
    # Fetch chunk count
    chunks = await db.select("knowledge_chunks")
    total_chunks = len(chunks)
    print(f"Total chunks in database: {total_chunks}")
    
    if total_chunks == 0:
        print("No chunks found!")
        return

    # Check content_en translation rate
    translated_count = sum(1 for c in chunks if c.get("content_en") and c.get("content_en") != c.get("content"))
    bengali_count = sum(1 for c in chunks if any('\u0980' <= char <= '\u09FF' for char in (c.get("content") or "")))
    
    print(f"Chunks with Bengali text: {bengali_count}")
    print(f"Chunks translated successfully (content_en != content): {translated_count}")
    
    # Print unique source files
    source_files = set(c.get("source_file") for c in chunks)
    print(f"Unique source files: {source_files}")

    if bengali_count > 0:
        success_rate = (translated_count / bengali_count) * 100
        print(f"Translation Success Rate: {success_rate:.2f}%")
    else:
        print("No Bengali chunks detected.")

    # Show a few sample records
    print("\nSample records:")
    for idx, c in enumerate(chunks[:3]):
        print(f"\n--- Chunk {idx+1} ---")
        print(f"Source File: {c.get('source_file')}")
        print(f"Content (first 100 chars): {c.get('content')[:100]}...")
        print(f"Content_EN (first 100 chars): {c.get('content_en')[:100]}...")

    # Inspect dsr-bangladesh-bangla.pdf chunks
    bangla_file_chunks = [c for c in chunks if c.get("source_file") == "dsr-bangladesh-bangla.pdf"]
    print(f"\nTotal chunks for dsr-bangladesh-bangla.pdf: {len(bangla_file_chunks)}")
    if bangla_file_chunks:
        print("\n--- Sample dsr-bangladesh-bangla.pdf Chunk ---")
        print(f"Content: {bangla_file_chunks[0].get('content')[:500]}")

if __name__ == "__main__":
    asyncio.run(verify())
