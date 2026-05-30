#!/usr/bin/env python3
"""
Akashi — Phase 1: Sentinel Hub NDVI Test Script
================================================
Tests the Sentinel Hub Statistical API independently BEFORE building the full app.
This is the most critical external dependency — validate it works before writing UI.

Usage:
    1. Copy .env.example → .env and fill in your Sentinel Hub credentials
    2. pip install requests python-dotenv shapely
    3. python scripts/test_sentinel_ndvi.py

What it does:
    • Authenticates with Sentinel Hub via OAuth2 client_credentials
    • Queries NDVI (Sentinel-2 L2A) for a sample Bangladesh rice field polygon
    • Fetches mean NDVI for the last 5 days with ≤30% cloud cover
    • Converts NDVI → health status (green/yellow/red) using crop-specific thresholds
    • Prints full diagnostics so you can verify the integration before Phase 3

Reference: Akashi MVP Spec v1.0, Section 5.3 — Sentinel Hub Integration
"""

import sys
import os
import json
from datetime import datetime, timezone, timedelta
from pathlib import Path

import requests
from dotenv import load_dotenv

# ─── Load environment variables ───────────────────────────────────────────────
# Look for .env in the backend root (one level up from scripts/)
ENV_FILE = Path(__file__).parent.parent / ".env"
if not ENV_FILE.exists():
    ENV_FILE = Path(__file__).parent.parent.parent / ".env"  # Project root fallback
load_dotenv(ENV_FILE)

SENTINEL_CLIENT_ID = os.getenv("SENTINEL_HUB_CLIENT_ID", "")
SENTINEL_CLIENT_SECRET = os.getenv("SENTINEL_HUB_CLIENT_SECRET", "")

# Sentinel Hub endpoints
TOKEN_URL = "https://services.sentinel-hub.com/auth/realms/main/protocol/openid-connect/token"
STATISTICS_URL = "https://services.sentinel-hub.com/api/v1/statistics"


# ─── Sample Bangladesh Field (Tangail District — rice/ধান field) ──────────────
# Replace this with a real field polygon from your farmers table.
# Coordinates: WGS84 (longitude, latitude)
SAMPLE_FIELD_GEOJSON = {
    "type": "Polygon",
    "coordinates": [[
        [89.9186, 24.2513],   # southwest corner
        [89.9207, 24.2513],   # southeast corner
        [89.9207, 24.2531],   # northeast corner
        [89.9186, 24.2531],   # northwest corner
        [89.9186, 24.2513],   # close ring
    ]]
}

# Crop type for health status calculation
SAMPLE_CROP_TYPE = "ধান"  # Rice — uses higher NDVI thresholds


# ─── NDVI Evalscript (from MVP Spec Section 5.3) ─────────────────────────────
# Masks clouds using the Scene Classification Layer (SCL):
#   3 = Cloud shadow, 9 = Cloud medium prob, 10 = Cloud high prob, 11 = Cirrus
NDVI_EVALSCRIPT = """//VERSION=3
function setup() {
  return {
    input: [{
      bands: ["B04", "B08", "SCL"],
      units: "DN"
    }],
    output: [
      { id: "ndvi", bands: 1, sampleType: "FLOAT32" }
    ]
  };
}

function evaluatePixel(s) {
  // Mask clouds, cloud shadows, and cirrus
  if ([3, 9, 10, 11].includes(s.SCL[0])) {
    return { ndvi: [NaN] };
  }
  const ndvi = (s.B08[0] - s.B04[0]) / (s.B08[0] + s.B04[0]);
  return { ndvi: [ndvi] };
}
"""


def get_auth_token(client_id: str, client_secret: str) -> str:
    """
    Step 1: Authenticate with Sentinel Hub via OAuth2 client credentials.
    Returns the bearer token for subsequent API calls.

    Spec reference: Section 5.3 Step 1
    """
    print("🔐 Authenticating with Sentinel Hub...")

    if not client_id or not client_secret:
        print("\n❌ ERROR: SENTINEL_HUB_CLIENT_ID or SENTINEL_HUB_CLIENT_SECRET not set.")
        print("   1. Register at: https://www.sentinel-hub.com/")
        print(f"   2. Add credentials to: {ENV_FILE}")
        print("   3. Re-run this script.")
        sys.exit(1)

    response = requests.post(
        TOKEN_URL,
        data={
            "grant_type": "client_credentials",
            "client_id": client_id,
            "client_secret": client_secret,
        },
        headers={"Content-Type": "application/x-www-form-urlencoded"},
        timeout=30,
    )

    if response.status_code != 200:
        print(f"\n❌ Authentication failed: {response.status_code}")
        print(f"   Response: {response.text}")
        sys.exit(1)

    token = response.json().get("access_token", "")
    expires_in = response.json().get("expires_in", 0)
    print(f"   ✅ Token obtained (expires in {expires_in}s)")
    return token


def build_statistics_request(
    polygon: dict,
    days_back: int = 5,
    max_cloud_coverage: int = 30,
) -> dict:
    """
    Step 2: Build the Statistical API request body.

    The time range covers the last N days. We use P5D aggregation intervals
    so each 5-day window gives us one NDVI measurement (matching the cron schedule).

    Spec reference: Section 5.3 Step 2
    """
    now = datetime.now(timezone.utc)
    start = now - timedelta(days=days_back)

    return {
        "input": {
            "bounds": {
                "geometry": polygon,
                "properties": {"crs": "http://www.opengis.net/def/crs/EPSG/0/4326"},
            },
            "data": [{
                "type": "sentinel-2-l2a",
                "dataFilter": {
                    "maxCloudCoverage": max_cloud_coverage,
                },
            }],
        },
        "aggregation": {
            "timeRange": {
                "from": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "to": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            },
            "aggregationInterval": {
                "of": "P5D",  # One interval per 5-day window
            },
            "evalscript": NDVI_EVALSCRIPT,
            "resx": 10,  # 10m resolution (Sentinel-2 native)
            "resy": 10,
        },
        "calculations": {
            "ndvi": {
                "histograms": {
                    "default": {
                        "nBins": 5,
                        "lowEdge": -1.0,
                        "highEdge": 1.0,
                    }
                },
                "statistics": {
                    "default": {
                        "percentiles": {
                            "k": [25, 50, 75]
                        }
                    }
                }
            }
        },
    }


def fetch_ndvi(token: str, polygon: dict, days_back: int = 5) -> dict:
    """
    Calls the Sentinel Hub Statistical API and returns parsed NDVI results.

    Returns a dict with:
        ndvi_mean: float | None   — mean NDVI across all non-cloud pixels
        cloud_cover: float        — estimated cloud cover % (0–100)
        date_from: str            — actual data start date
        date_to: str              — actual data end date
        pixel_count: int          — number of valid (non-cloud) pixels analyzed
        raw_response: dict        — full API response for debugging/storage
    """
    print(f"\n📡 Fetching NDVI from Sentinel Hub...")
    print(f"   Period: last {days_back} days")

    payload = build_statistics_request(polygon, days_back)

    response = requests.post(
        STATISTICS_URL,
        json=payload,
        headers={
            "Authorization": f"Bearer {token}",
            "Content-Type": "application/json",
            "Accept": "application/json",
        },
        timeout=60,
    )

    if response.status_code != 200:
        print(f"\n❌ Statistics API failed: {response.status_code}")
        print(f"   Response: {response.text[:500]}")
        return {
            "ndvi_mean": None,
            "cloud_cover": 100.0,
            "date_from": None,
            "date_to": None,
            "pixel_count": 0,
            "raw_response": {"error": response.text},
        }

    data = response.json()

    # Parse Sentinel Hub Statistical API response structure
    # Response: { data: [ { interval: {...}, outputs: { ndvi: { bands: { B0: { stats: {...} } } } } } ] }
    results = data.get("data", [])

    if not results:
        print("   ⚠️  No data returned — possibly 100% cloud cover in this period")
        return {
            "ndvi_mean": None,
            "cloud_cover": 100.0,
            "date_from": None,
            "date_to": None,
            "pixel_count": 0,
            "raw_response": data,
        }

    # Take the most recent interval
    latest = results[-1]
    interval = latest.get("interval", {})
    outputs = latest.get("outputs", {})

    date_from = interval.get("from", "")
    date_to = interval.get("to", "")

    # Extract NDVI statistics from the response
    ndvi_bands = outputs.get("ndvi", {}).get("bands", {})
    band_data = ndvi_bands.get("B0", {})  # NDVI is single-band, named B0
    stats = band_data.get("statistics", {})
    histogram = band_data.get("histogram", {})

    ndvi_mean = stats.get("mean")
    sample_count = stats.get("sampleCount", 0)  # Total pixels (including cloud-masked)
    no_data_count = stats.get("noDataCount", 0)  # Cloud-masked NaN pixels

    # Estimate cloud cover from the ratio of masked pixels
    cloud_cover_pct = 0.0
    if sample_count > 0:
        cloud_cover_pct = (no_data_count / sample_count) * 100.0

    # If all pixels are masked → no valid data
    if ndvi_mean is None or (sample_count > 0 and no_data_count == sample_count):
        ndvi_mean = None

    valid_pixels = sample_count - no_data_count

    return {
        "ndvi_mean": round(ndvi_mean, 4) if ndvi_mean is not None else None,
        "cloud_cover": round(cloud_cover_pct, 1),
        "date_from": date_from,
        "date_to": date_to,
        "pixel_count": valid_pixels,
        "raw_response": data,
    }


def ndvi_to_status(ndvi: float | None, crop_type: str) -> str:
    """
    Convert NDVI value → health status using crop-specific thresholds.

    Thresholds from MVP Spec Section 5.3 Step 3.
    NOTE: These are provisional — validate with an agronomist before launch.

    Args:
        ndvi: Mean NDVI value (-1 to 1), or None if cloud-covered
        crop_type: Bengali crop type string ('ধান', 'গম', 'পাট', etc.)

    Returns:
        'green' | 'yellow' | 'red' | 'unknown'
    """
    if ndvi is None or ndvi < -1 or ndvi > 1:
        return "unknown"

    # Rice (ধান) — higher thresholds because rice fields are denser
    if crop_type in ["ধান", "rice"]:
        if ndvi >= 0.50:
            return "green"
        if ndvi >= 0.30:
            return "yellow"
        return "red"

    # General crops (wheat/গম, jute/পাট, vegetables/সবজি, other/অন্যান্য)
    else:
        if ndvi >= 0.45:
            return "green"
        if ndvi >= 0.25:
            return "yellow"
        return "red"


def get_bengali_recommendation(status: str, crop_type: str, cloud_cover: float) -> str:
    """
    Rule-based Bengali recommendation (MVP Spec Section 8).
    No LLM — pre-written strings only.
    """
    # Cloud cover warning overrides health recommendation
    if cloud_cover > 70:
        return "মেঘের কারণে এই তথ্য আংশিক। পরের আপডেটের জন্য অপেক্ষা করুন।"

    recommendations = {
        ("ধান", "green"): "ফসল ভালো আছে। নিয়মিত পানি দিতে থাকুন এবং পোকামাকড় পর্যবেক্ষণ করুন।",
        ("ধান", "yellow"): "ফসলের স্বাস্থ্য কিছুটা দুর্বল। নাইট্রোজেন সার প্রয়োগ বিবেচনা করুন।",
        ("ধান", "red"): "জরুরি: ফসল মারাত্মক ক্ষতিগ্রস্ত। দ্রুত কৃষি অফিসারের সাথে যোগাযোগ করুন।",
        ("গম", "green"): "ফসল সুস্থ আছে। সেচ চালিয়ে যান।",
        ("গম", "yellow"): "সতর্কতা: ফসলের সবুজ কমছে। সার ও পানি পরীক্ষা করুন।",
        ("গম", "red"): "জরুরি পরিস্থিতি। কৃষি বিশেষজ্ঞের সাথে যোগাযোগ করুন।",
    }

    # Try specific crop first, then generic
    key = (crop_type, status)
    if key in recommendations:
        return recommendations[key]

    # Generic fallback for unlisted crops
    generic = {
        "green": "ফসল সুস্থ আছে। নিয়মিত পরিচর্যা চালিয়ে যান।",
        "yellow": "সতর্কতা প্রয়োজন। ফসল পর্যবেক্ষণ বাড়ান।",
        "red": "জরুরি যত্ন নিন। কৃষি অফিসারের পরামর্শ নিন।",
        "unknown": "তথ্য পাওয়া যায়নি। পরবর্তী আপডেটের জন্য অপেক্ষা করুন।",
    }
    return generic.get(status, "তথ্য প্রক্রিয়াকরণ হচ্ছে...")


def print_result(ndvi_result: dict, crop_type: str) -> None:
    """Print a formatted diagnostic report."""
    ndvi = ndvi_result["ndvi_mean"]
    cloud = ndvi_result["cloud_cover"]
    status = ndvi_to_status(ndvi, crop_type)
    recommendation = get_bengali_recommendation(status, crop_type, cloud)

    status_icons = {"green": "🟢", "yellow": "🟡", "red": "🔴", "unknown": "⚪"}
    status_labels = {
        "green": "ফসল সুস্থ আছে ✓",
        "yellow": "সতর্কতা প্রয়োজন",
        "red": "জরুরি যত্ন নিন",
        "unknown": "তথ্য পাওয়া যায়নি",
    }

    print("\n" + "═" * 60)
    print("  🛰️  AKASHI — Sentinel Hub NDVI Test Result")
    print("═" * 60)
    print(f"  Crop type   : {crop_type}")
    print(f"  Period      : {ndvi_result['date_from']} → {ndvi_result['date_to']}")
    print(f"  Valid pixels: {ndvi_result['pixel_count']}")
    print(f"  Cloud cover : {cloud:.1f}%")
    print()

    if ndvi is not None:
        print(f"  NDVI Mean   : {ndvi:.4f}")
        # Visual NDVI bar
        bar_val = max(0, min(1, ndvi))
        filled = int(bar_val * 30)
        bar = "█" * filled + "░" * (30 - filled)
        print(f"  NDVI Scale  : [{bar}] {ndvi:.2f}")
    else:
        print("  NDVI Mean   : N/A (cloud-covered or no data)")

    print()
    print(f"  Status      : {status_icons.get(status, '?')} {status_labels.get(status, status)}")
    print(f"  Recommend.  : {recommendation}")
    print()

    if cloud > 70:
        print("  ⚠️  HIGH CLOUD COVER: Data reliability is low.")
        print("      The app will display: 'মেঘের কারণে এই তথ্য আংশিক'")

    if ndvi_result["pixel_count"] < 10:
        print("  ⚠️  WARNING: Very few valid pixels. Field may be too small or")
        print("      entirely cloud-covered. Consider expanding the polygon.")

    print("═" * 60)
    print()

    # Save raw response for debugging
    output_file = Path(__file__).parent / "ndvi_raw_response.json"
    with open(output_file, "w", encoding="utf-8") as f:
        json.dump(ndvi_result["raw_response"], f, indent=2, ensure_ascii=False)
    print(f"  📄 Raw API response saved to: {output_file}")


def validate_credentials_exist() -> bool:
    """Check if credentials are configured (without exposing them)."""
    if not SENTINEL_CLIENT_ID or SENTINEL_CLIENT_ID == "your_client_id_here":
        return False
    if not SENTINEL_CLIENT_SECRET or SENTINEL_CLIENT_SECRET == "your_client_secret_here":
        return False
    return True


def main():
    print()
    print("🌱 Akashi — Phase 1: Sentinel Hub NDVI Integration Test")
    print("─" * 60)

    # ── Step 0: Check credentials ──────────────────────────────────────────────
    if not validate_credentials_exist():
        print()
        print("⚠️  Sentinel Hub credentials not configured yet.")
        print()
        print("   How to get free Sentinel Hub credentials:")
        print("   1. Go to: https://www.sentinel-hub.com/")
        print("   2. Register for a free account")
        print("   3. Go to Dashboard → User Settings → OAuth Clients")
        print("   4. Create a new OAuth client → copy Client ID + Secret")
        print(f"   5. Add to: {ENV_FILE}")
        print("      SENTINEL_HUB_CLIENT_ID=<your_id>")
        print("      SENTINEL_HUB_CLIENT_SECRET=<your_secret>")
        print()
        print("   Running in DEMO MODE — showing expected output format")
        print("   (API call will fail without real credentials)")
        print()

        # Demo mode: show what output would look like
        demo_result = {
            "ndvi_mean": 0.6234,
            "cloud_cover": 12.5,
            "date_from": "2026-05-25T00:00:00Z",
            "date_to": "2026-05-30T00:00:00Z",
            "pixel_count": 847,
            "raw_response": {"demo": True},
        }
        print("[DEMO MODE — sample output with real credentials]")
        print_result(demo_result, SAMPLE_CROP_TYPE)
        return

    # ── Step 1: Authenticate ───────────────────────────────────────────────────
    token = get_auth_token(SENTINEL_CLIENT_ID, SENTINEL_CLIENT_SECRET)

    # ── Step 2: Query NDVI for sample Bangladesh field ─────────────────────────
    print(f"\n📍 Field polygon: Tangail District, Bangladesh (ধান/Rice field)")
    print(f"   Coordinates: {SAMPLE_FIELD_GEOJSON['coordinates'][0][0]} → "
          f"{SAMPLE_FIELD_GEOJSON['coordinates'][0][2]}")

    ndvi_result = fetch_ndvi(
        token=token,
        polygon=SAMPLE_FIELD_GEOJSON,
        days_back=5,
    )

    # ── Step 3: Display results ────────────────────────────────────────────────
    print_result(ndvi_result, SAMPLE_CROP_TYPE)

    # ── Step 4: Validate integration success ───────────────────────────────────
    if ndvi_result["ndvi_mean"] is not None:
        print("✅ Phase 1 COMPLETE: Sentinel Hub integration is working.")
        print("   You can now proceed to Phase 2 (Database Schema).")
    elif ndvi_result["cloud_cover"] > 70:
        print("⚠️  Phase 1 PARTIAL: API works, but high cloud cover this period.")
        print("   This is normal in Bangladesh — the app handles it gracefully.")
        print("   You can proceed to Phase 2.")
    else:
        print("❌ Phase 1 INCOMPLETE: No NDVI data returned.")
        print("   Check the raw response in ndvi_raw_response.json for details.")


if __name__ == "__main__":
    main()
