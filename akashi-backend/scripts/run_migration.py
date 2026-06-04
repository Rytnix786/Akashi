import asyncio
import os
import asyncpg
from dotenv import load_dotenv

async def main():
    # Load root .env which contains DATABASE_URL
    load_dotenv(dotenv_path=os.path.join(os.path.dirname(__file__), "../../.env"))
    db_url = os.getenv("DATABASE_URL")
    if not db_url:
        print("DATABASE_URL not found!")
        return

    import urllib.parse
    if "@" in db_url:
        prefix, rest = db_url.split("@", 1)
        if "://" in prefix:
            proto, user_pass = prefix.split("://", 1)
            if ":" in user_pass:
                user, password = user_pass.split(":", 1)
                # Parse query parameters if any are already appended to password
                # But here password is Hasan12539?! which asyncpg misinterprets as start of query parameters
                # Quote only the password
                encoded_password = urllib.parse.quote(password)
                db_url = f"{proto}://{user}:{encoded_password}@{rest}"

    print("Connecting to database...")
    conn = await asyncpg.connect(db_url)
    try:
        print("Running migration: ALTER TABLE fields ADD COLUMN IF NOT EXISTS planting_date DATE;")
        await conn.execute("ALTER TABLE fields ADD COLUMN IF NOT EXISTS planting_date DATE;")
        print("Running migration: ALTER TABLE knowledge_chunks ADD COLUMN IF NOT EXISTS content_en TEXT;")
        await conn.execute("ALTER TABLE knowledge_chunks ADD COLUMN IF NOT EXISTS content_en TEXT;")
        print("Migration completed successfully!")
    except Exception as e:
        print(f"Migration failed: {e}")
    finally:
        await conn.close()

if __name__ == "__main__":
    asyncio.run(main())
