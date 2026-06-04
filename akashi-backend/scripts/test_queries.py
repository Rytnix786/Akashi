import sys
import os
from pathlib import Path

# Add project root to path
sys.path.append(str(Path(__file__).resolve().parent.parent))

from fastapi.testclient import TestClient
from main import app

client = TestClient(app)

queries = [
    "আমার ধান পাতায় বাদামি দাগ হচ্ছে কী করব",
    "বোরো ধান কখন রোপণ করব",
    "আমার জমিতে পানি জমে গেছে কী করব",
    "আমাকে একটি গান গাও",
    "ইউরিয়া সার কত কেজি দেব"
]

# Set mock authorization header using our dynamic dynamic suffix token
headers = {
    "Authorization": "Bearer mock_jwt_token_+8801712345678"
}

# Ensure farmer profile exists in database
register_payload = {
    "name": "Mock Farmer",
    "district": "Tangail",
    "upazila": "Mirzapur",
    "fcm_token": "mock_fcm",
    "consent_given": True
}
print("Registering farmer profile...")
reg_resp = client.post("/farmers/register", json=register_payload, headers=headers)
print("Registration status:", reg_resp.status_code)

for idx, q in enumerate(queries, 1):
    print(f"\n--- Query {idx}: {q} ---")
    response = client.post("/chat", json={"query": q}, headers=headers)
    print("Status code:", response.status_code)
    if response.status_code == 200:
        data = response.json()
        print("Response:", data.get("response"))
        citations = data.get("citations", [])
        print("Citations:")
        for c in citations:
            print(f"  - Source: {c.get('source_file')}, Chunk: {c.get('chunk_index')}, Similarity: {c.get('similarity')}")
    else:
        print("Error:", response.text)
