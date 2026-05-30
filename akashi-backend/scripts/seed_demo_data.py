#!/usr/bin/env python3
"""
Akashi demo seeder.

Creates a small, realistic test dataset for the full app flow:
- Supabase Auth phone users (when supported by the Auth admin API)
- farmer profile rows
- field rows with polygons
- health_readings rows for trend/history UI
- notifications rows for the farmer notifications screen
- a government_users row for dashboard testing

Run from the backend folder:
    python scripts/seed_demo_data.py

Environment variables:
    SUPABASE_URL
    SUPABASE_SERVICE_KEY

Notes:
- The script is idempotent where practical. Existing rows are updated or skipped.
- If auth user creation fails for any reason, the script still seeds the database rows.
"""

from __future__ import annotations

import asyncio
import os
import sys
from dataclasses import dataclass, field
from datetime import date, datetime, timedelta, timezone
from pathlib import Path
from typing import Any, Dict, List, Optional

import httpx
from dotenv import load_dotenv

ROOT = Path(__file__).resolve().parent.parent
if str(ROOT) not in sys.path:
    sys.path.insert(0, str(ROOT))

from app.db.connection import db  # noqa: E402

load_dotenv(ROOT / ".env")
load_dotenv(ROOT.parent / ".env")

SUPABASE_URL = os.getenv("SUPABASE_URL", "").rstrip("/")
SUPABASE_SERVICE_KEY = os.getenv("SUPABASE_SERVICE_KEY", "")

if not SUPABASE_URL or not SUPABASE_SERVICE_KEY:
    raise SystemExit("SUPABASE_URL and SUPABASE_SERVICE_KEY must be set before running the seeder.")

ADMIN_HEADERS = {
    "apikey": SUPABASE_SERVICE_KEY,
    "Authorization": f"Bearer {SUPABASE_SERVICE_KEY}",
    "Content-Type": "application/json",
    "Accept": "application/json",
}


@dataclass
class FieldSeed:
    name: str
    crop_type: str
    crop_season: str
    polygon: List[List[float]]  # [[lon, lat], ...]
    area_acres: float
    area_bigha: float
    reading_states: List[Dict[str, Any]]


@dataclass
class FarmerSeed:
    phone: str
    name: str
    district: str
    upazila: str
    fcm_token: str
    fields: List[FieldSeed] = field(default_factory=list)


DEMO_FARMERS: List[FarmerSeed] = [
    FarmerSeed(
        phone="+8801712345678",
        name="আব্দুল করিম",
        district="Tangail",
        upazila="Mirzapur",
        fcm_token="demo_fcm_token_tangail_001",
        fields=[
            FieldSeed(
                name="ধানের মাঠ ১",
                crop_type="ধান",
                crop_season="Boro",
                polygon=[
                    [89.9186, 24.2513],
                    [89.9207, 24.2513],
                    [89.9207, 24.2531],
                    [89.9186, 24.2531],
                    [89.9186, 24.2513],
                ],
                area_acres=1.32,
                area_bigha=4.00,
                reading_states=[
                    {
                        "reading_date": (date.today() - timedelta(days=5)).isoformat(),
                        "ndvi_mean": 0.64,
                        "ndwi_mean": 0.21,
                        "cloud_cover": 18.0,
                        "health_status": "green",
                        "pixel_count": 142,
                    },
                    {
                        "reading_date": date.today().isoformat(),
                        "ndvi_mean": 0.49,
                        "ndwi_mean": 0.18,
                        "cloud_cover": 22.0,
                        "health_status": "yellow",
                        "pixel_count": 148,
                    },
                ],
            ),
            FieldSeed(
                name="ধানের মাঠ ২",
                crop_type="ধান",
                crop_season="Aman",
                polygon=[
                    [89.9212, 24.2504],
                    [89.9230, 24.2504],
                    [89.9230, 24.2520],
                    [89.9212, 24.2520],
                    [89.9212, 24.2504],
                ],
                area_acres=0.96,
                area_bigha=2.91,
                reading_states=[
                    {
                        "reading_date": (date.today() - timedelta(days=5)).isoformat(),
                        "ndvi_mean": 0.56,
                        "ndwi_mean": 0.19,
                        "cloud_cover": 12.0,
                        "health_status": "green",
                        "pixel_count": 121,
                    },
                    {
                        "reading_date": date.today().isoformat(),
                        "ndvi_mean": 0.34,
                        "ndwi_mean": 0.14,
                        "cloud_cover": 31.0,
                        "health_status": "red",
                        "pixel_count": 109,
                    },
                ],
            ),
        ],
    ),
    FarmerSeed(
        phone="+8801812345678",
        name="রহিমা বেগম",
        district="Mymensingh",
        upazila="Trishal",
        fcm_token="demo_fcm_token_mymensingh_001",
        fields=[
            FieldSeed(
                name="সবজির বাগান",
                crop_type="সবজি",
                crop_season="Rabi",
                polygon=[
                    [90.3764, 24.7872],
                    [90.3780, 24.7872],
                    [90.3780, 24.7888],
                    [90.3764, 24.7888],
                    [90.3764, 24.7872],
                ],
                area_acres=0.74,
                area_bigha=2.24,
                reading_states=[
                    {
                        "reading_date": (date.today() - timedelta(days=5)).isoformat(),
                        "ndvi_mean": 0.52,
                        "ndwi_mean": 0.25,
                        "cloud_cover": 14.0,
                        "health_status": "green",
                        "pixel_count": 97,
                    },
                    {
                        "reading_date": date.today().isoformat(),
                        "ndvi_mean": 0.60,
                        "ndwi_mean": 0.27,
                        "cloud_cover": 10.0,
                        "health_status": "green",
                        "pixel_count": 105,
                    },
                ],
            ),
        ],
    ),
    FarmerSeed(
        phone="+8801912345678",
        name="জামাল উদ্দিন",
        district="Dhaka",
        upazila="Savar",
        fcm_token="demo_fcm_token_dhaka_001",
        fields=[
            FieldSeed(
                name="পাটের জমি",
                crop_type="পাট",
                crop_season="Aus",
                polygon=[
                    [90.2603, 23.8453],
                    [90.2620, 23.8453],
                    [90.2620, 23.8469],
                    [90.2603, 23.8469],
                    [90.2603, 23.8453],
                ],
                area_acres=1.05,
                area_bigha=3.18,
                reading_states=[
                    {
                        "reading_date": (date.today() - timedelta(days=5)).isoformat(),
                        "ndvi_mean": 0.43,
                        "ndwi_mean": 0.16,
                        "cloud_cover": 20.0,
                        "health_status": "yellow",
                        "pixel_count": 118,
                    },
                    {
                        "reading_date": date.today().isoformat(),
                        "ndvi_mean": 0.39,
                        "ndwi_mean": 0.13,
                        "cloud_cover": 24.0,
                        "health_status": "yellow",
                        "pixel_count": 113,
                    },
                ],
            ),
        ],
    ),
]

GOVERNMENT_USERS = [
    {
        "email": "officer@dae.gov.bd",
        "name": "Tangail DAE Officer",
        "role": "district_officer",
        "district": "Tangail",
    },
    {
        "email": "national@dae.gov.bd",
        "name": "National DAE Admin",
        "role": "national_admin",
        "district": None,
    },
]


async def find_auth_user_by_phone(client: httpx.AsyncClient, phone: str) -> Optional[Dict[str, Any]]:
    page = 1
    per_page = 100

    while page <= 10:
        response = await client.get(
            f"{SUPABASE_URL}/auth/v1/admin/users",
            params={"page": page, "per_page": per_page},
            headers=ADMIN_HEADERS,
        )
        response.raise_for_status()
        payload = response.json()
        users = payload.get("users", payload if isinstance(payload, list) else [])
        for user in users:
            if user.get("phone") == phone:
                return user
        if len(users) < per_page:
            break
        page += 1

    return None


async def create_or_get_auth_user(client: httpx.AsyncClient, farmer: FarmerSeed) -> Dict[str, Any]:
    existing = await find_auth_user_by_phone(client, farmer.phone)
    if existing:
        return existing

    response = await client.post(
        f"{SUPABASE_URL}/auth/v1/admin/users",
        headers=ADMIN_HEADERS,
        json={
            "phone": farmer.phone,
            "phone_confirm": True,
            "user_metadata": {
                "name": farmer.name,
                "district": farmer.district,
                "upazila": farmer.upazila,
                "seeded": True,
                "role": "farmer",
            },
        },
    )

    if response.status_code not in (200, 201):
        raise RuntimeError(f"Auth user creation failed for {farmer.phone}: {response.status_code} {response.text}")

    return response.json()


async def upsert_farmer_profile(user_id: str, farmer: FarmerSeed) -> Dict[str, Any]:
    existing = await db.select("farmers", filters={"id": f"eq.{user_id}"}, limit=1)
    payload = {
        "id": user_id,
        "phone": farmer.phone,
        "name": farmer.name,
        "district": farmer.district,
        "upazila": farmer.upazila,
        "fcm_token": farmer.fcm_token,
    }

    if existing:
        updated = await db.update("farmers", payload, {"id": f"eq.{user_id}"})
        return updated[0] if updated else payload

    created = await db.insert("farmers", payload)
    return created[0] if created else payload


async def upsert_farmer_by_phone(farmer: FarmerSeed) -> Dict[str, Any]:
    existing = await db.select("farmers", filters={"phone": f"eq.{farmer.phone}"}, limit=1)
    payload = {
        "phone": farmer.phone,
        "name": farmer.name,
        "district": farmer.district,
        "upazila": farmer.upazila,
        "fcm_token": farmer.fcm_token,
    }

    if existing:
        farmer_row = existing[0]
        await db.update("farmers", payload, {"phone": f"eq.{farmer.phone}"})
        farmer_row.update(payload)
        return farmer_row

    created = await db.insert("farmers", payload)
    return created[0] if created else payload


async def ensure_field(farmer_id: str, farmer: FarmerSeed, field_seed: FieldSeed) -> Dict[str, Any]:
    existing = await db.select(
        "fields",
        filters={"farmer_id": f"eq.{farmer_id}", "name": f"eq.{field_seed.name}"},
        limit=1,
    )

    polygon = {
        "type": "Polygon",
        "coordinates": [field_seed.polygon],
    }
    center_lon = sum(point[0] for point in field_seed.polygon[:-1]) / (len(field_seed.polygon) - 1)
    center_lat = sum(point[1] for point in field_seed.polygon[:-1]) / (len(field_seed.polygon) - 1)
    center_point = {
        "type": "Point",
        "coordinates": [center_lon, center_lat],
    }

    payload = {
        "farmer_id": farmer_id,
        "name": field_seed.name,
        "crop_type": field_seed.crop_type,
        "crop_season": field_seed.crop_season,
        "area_acres": field_seed.area_acres,
        "area_bigha": field_seed.area_bigha,
        "polygon": polygon,
        "center_point": center_point,
        "district": farmer.district,
        "upazila": farmer.upazila,
        "is_active": True,
    }

    if existing:
        return existing[0]

    created = await db.insert("fields", payload)
    return created[0]


async def ensure_readings(field_row: Dict[str, Any], field_seed: FieldSeed) -> None:
    field_id = field_row["id"]
    reading_date_keys = [entry["reading_date"] for entry in field_seed.reading_states]

    existing = await db.select(
        "health_readings",
        filters={"field_id": f"eq.{field_id}"},
        limit=100,
    )
    existing_dates = {row.get("reading_date") for row in existing}

    for entry in field_seed.reading_states:
        if entry["reading_date"] in existing_dates:
            continue

        await db.insert(
            "health_readings",
            {
                "field_id": field_id,
                "reading_date": entry["reading_date"],
                "ndvi_mean": entry["ndvi_mean"],
                "ndwi_mean": entry["ndwi_mean"],
                "cloud_cover": entry["cloud_cover"],
                "health_status": entry["health_status"],
                "pixel_count": entry["pixel_count"],
                "raw_response": {
                    "seeded": True,
                    "source": "seed_demo_data.py",
                    "field_name": field_seed.name,
                    "status": entry["health_status"],
                    "reading_date": entry["reading_date"],
                },
            },
        )


async def seed_notifications(farmer_row: Dict[str, Any], field_row: Dict[str, Any], latest_status: str) -> None:
    titles = {
        "green": ("ফসলের স্বাস্থ্য ভালো", "আপনার ফসল সবুজ ও সুস্থ আছে। স্বাভাবিক পরিচর্যা চালিয়ে যান।"),
        "yellow": ("ফসলের স্বাস্থ্য সতর্কতা", "আপনার জমিতে মনোযোগ প্রয়োজন। সেচ ও পুষ্টি পরীক্ষা করুন।"),
        "red": ("জরুরি ফসল সতর্কতা", "ফসলের গুরুতর ঝুঁকি দেখা গেছে। দ্রুত কৃষি সহায়তা নিন।"),
    }

    title, body = titles.get(latest_status, titles["yellow"])
    existing = await db.select(
        "notifications",
        filters={"farmer_id": f"eq.{farmer_row['id']}"},
        limit=1,
    )

    if existing:
        return

    await db.insert(
        "notifications",
        {
            "farmer_id": farmer_row["id"],
            "field_id": field_row["id"],
            "type": "health_alert",
            "title_bn": title,
            "body_bn": body,
            "sent_at": datetime.now(timezone.utc).isoformat(),
            "delivered": False,
        },
    )


async def seed_government_users() -> None:
    for user in GOVERNMENT_USERS:
        existing = await db.select("government_users", filters={"email": f"eq.{user['email']}"}, limit=1)
        payload = {
            "email": user["email"],
            "name": user["name"],
            "role": user["role"],
            "district": user["district"],
        }
        if existing:
            await db.update("government_users", payload, {"email": f"eq.{user['email']}"})
        else:
            await db.insert("government_users", payload)


async def main() -> None:
    print("Seeding Akashi demo data...")

    async with httpx.AsyncClient(timeout=60.0) as client:
        for farmer in DEMO_FARMERS:
            try:
                auth_user = await create_or_get_auth_user(client, farmer)
                user_id = auth_user["id"]
            except Exception as exc:
                print(f"[warn] Auth seeding failed for {farmer.phone}: {exc}")
                user_id = None

            if user_id:
                farmer_row = await upsert_farmer_profile(user_id, farmer)
            else:
                # Fallback for DB-only testing when Auth seeding is unavailable.
                farmer_row = await upsert_farmer_by_phone(farmer)

            latest_status = "green"
            for field_seed in farmer.fields:
                field_row = await ensure_field(farmer_row["id"], farmer, field_seed)
                await ensure_readings(field_row, field_seed)
                latest_status = field_seed.reading_states[-1]["health_status"]
                await seed_notifications(farmer_row, field_row, latest_status)

            print(f"[ok] Seeded farmer: {farmer.name} ({farmer.phone})")

        await seed_government_users()

    print("Done. Demo data is ready.")
    print("Test accounts:")
    for farmer in DEMO_FARMERS:
        print(f" - {farmer.name}: {farmer.phone} ({farmer.district}/{farmer.upazila})")
    print("Government login:")
    print(" - officer@dae.gov.bd")
    print(" - national@dae.gov.bd")


if __name__ == "__main__":
    asyncio.run(main())
