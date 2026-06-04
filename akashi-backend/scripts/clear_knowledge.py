import asyncio
import os
import sys
from pathlib import Path
from dotenv import load_dotenv

sys.path.append(str(Path(__file__).resolve().parent.parent))
from app.db.connection import db

async def clear():
    load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../.env"))
    
    print("Clearing all knowledge chunks...")
    try:
        # Delete using PostgREST filter to select all rows (id is not null)
        res = await db.delete("knowledge_chunks", {"id": "not.is.null"})
        print(f"Cleared {len(res)} chunks successfully.")
    except Exception as e:
        print(f"Error clearing chunks: {e}")

if __name__ == "__main__":
    asyncio.run(clear())
