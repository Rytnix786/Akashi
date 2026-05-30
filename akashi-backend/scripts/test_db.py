import sys
import asyncio
from pathlib import Path

# Add project root to path so we can import app
sys.path.append(str(Path(__file__).parent.parent))

from app.db.connection import db

async def main():
    print("Testing connection to Supabase database...")
    try:
        # Check if the schema cache contains something or fetch an empty table
        # We query the farmers table (it will fail with 404 because tables are not set up yet,
        # but a 404 with PGRST205 is a SUCCESSFUL network connection!)
        res = await db.select("farmers", limit=1)
        print(f"Result: {res}")
    except Exception as e:
        print(f"Done with result/error: {str(e)}")

if __name__ == "__main__":
    asyncio.run(main())
