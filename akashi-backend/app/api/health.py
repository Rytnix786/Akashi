"""
Akashi — Crop Health Monitoring API Routes
==========================================
Retrieves crop health readings, satellite telemetry histories, and localized agronomic advice.

Features:
  - Dynamically calculates the official rule-based Bengali advice table (Spec Section 8)
  - Distributes recent satellite diagnostic details
  - Serves historical health logs (up to last 12 readings / 60 days) for telemetry dots

Reference: Akashi MVP Spec v1.0, Section 5.2, 8 & Screen 7
"""

import logging
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from app.db.connection import db
from app.api.auth import get_current_farmer
from app.models.schemas import HealthReadingResponse, FieldDetailResponse

logger = logging.getLogger("akashi.health")
router = APIRouter(prefix="/fields", tags=["Crop Health & Recommendations"])

# Core Bengali Recommendation Engine (Spec Section 8 - 100% compliant)
def get_bengali_recommendation(
    status: str,
    crop_type: str,
    cloud_cover: float,
    ndwi: float = 0.2
) -> str:
    """
    Computes standard rule-based advice in Bengali without LLM dependencies.
    """
    # Cloud cover warning overrides health recommendation
    if cloud_cover > 70.0:
        return "মেঘের কারণে এই তথ্য আংশিক। পরের আপডেটের জন্য অপেক্ষা করুন।"

    # Safe NDWI boundary: low is dry (< 0.1)
    is_dry = ndwi < 0.1
    is_rice = crop_type in ["ধান", "rice", "boro", "aman", "aus"]

    if status == "green":
        return "ফসল সুস্থ আছে। নিয়মিত সেচ ও পরিচর্যা চালিয়ে যান।"
        
    elif status == "yellow":
        if is_dry:
            return "ফসলে পানির অভাব দেখা যাচ্ছে। দ্রুত সেচ দিন।"
        else:
            return "ফসলে হালকা চাপ আছে। সার ও বালাইনাশক পরীক্ষা করুন।"
            
    elif status == "red":
        if is_dry:
            return "ফসল মারাত্মক পানির চাপে আছে। এখনই সেচ দিন এবং কৃষি অফিসে যোগাযোগ করুন।"
        else:
            return "ফসলে গুরুতর সমস্যা দেখা যাচ্ছে। কৃষি সম্প্রসারণ কর্মকর্তার সাথে যোগাযোগ করুন।"
            
    else: # unknown
        return "আজকের তথ্য পাওয়া যায়নি (সম্ভবত মেঘলা আকাশ)। আগামী আপডেট ৫ দিন পরে।"


@router.get("/{id}/health", response_model=HealthReadingResponse)
async def get_latest_health(
    id: str,
    current_farmer: Dict[str, Any] = Depends(get_current_farmer)
):
    """
    Gets the latest NDVI crop health reading and Bengali recommendation for a field.
    Spec Reference: Screen 5 / Screen 7
    """
    try:
        # Retrieve the latest reading for the field
        readings = await db.select(
            table="health_readings",
            select_fields="*",
            filters={"field_id": f"eq.{id}"},
            order_by="reading_date.desc",
            limit=1
        )

        if not readings:
            # Return a default empty/unknown reading if satellite sync hasn't run yet
            return {
                "reading_date": "N/A",
                "ndvi_mean": None,
                "ndwi_mean": None,
                "cloud_cover": 0.0,
                "health_status": "unknown",
                "pixel_count": 0,
                "recommendation_bn": "জমিটি সবেমাত্র নিবন্ধিত হয়েছে। প্রথম স্যাটেলাইট ছবি ৫ দিনের মধ্যে পৌঁছাবে।"
            }

        r = readings[0]
        ndvi_val = float(r["ndvi_mean"]) if r["ndvi_mean"] is not None else None
        ndwi_val = float(r["ndwi_mean"]) if r["ndwi_mean"] is not None else 0.2
        cloud_val = float(r["cloud_cover"]) if r["cloud_cover"] is not None else 0.0
        health_stat = r["health_status"] or "unknown"

        # Fetch field's crop type to compute recommendations
        field_info = await db.select(
            table="fields",
            select_fields="crop_type",
            filters={"id": f"eq.{id}"},
            limit=1
        )
        crop_type = field_info[0]["crop_type"] if field_info else "ধান"

        # Compute Bengali recommendation
        rec = get_bengali_recommendation(health_stat, crop_type, cloud_val, ndwi_val)

        return {
            "reading_date": str(r["reading_date"]),
            "ndvi_mean": ndvi_val,
            "ndwi_mean": ndwi_val if r["ndwi_mean"] is not None else None,
            "cloud_cover": cloud_val,
            "health_status": health_stat,
            "pixel_count": r.get("pixel_count", 0) or 0,
            "recommendation_bn": rec
        }

    except Exception as e:
        logger.error(f"Failed to fetch latest crop health for field {id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database read failure retrieving health status."
        )


@router.get("/{id}/history", response_model=List[HealthReadingResponse])
async def get_health_history(
    id: str,
    current_farmer: Dict[str, Any] = Depends(get_current_farmer)
):
    """
    Fetches the history of the last 12 health readings (roughly 60 days) for a field.
    Used for Screen 7's historical status dots.
    """
    try:
        # Fetch the last 12 readings in descending date order
        readings = await db.select(
            table="health_readings",
            select_fields="*",
            filters={"field_id": f"eq.{id}"},
            order_by="reading_date.desc",
            limit=12
        )

        # Get field crop_type for recommendations
        field_info = await db.select(
            table="fields",
            select_fields="crop_type",
            filters={"id": f"eq.{id}"},
            limit=1
        )
        crop_type = field_info[0]["crop_type"] if field_info else "ধান"

        history_response = []
        # Return in ascending order (left-to-right timeline for UI dots)
        for r in reversed(readings):
            ndvi_val = float(r["ndvi_mean"]) if r["ndvi_mean"] is not None else None
            ndwi_val = float(r["ndwi_mean"]) if r["ndwi_mean"] is not None else 0.2
            cloud_val = float(r["cloud_cover"]) if r["cloud_cover"] is not None else 0.0
            health_stat = r["health_status"] or "unknown"
            
            rec = get_bengali_recommendation(health_stat, crop_type, cloud_val, ndwi_val)

            history_response.append({
                "reading_date": str(r["reading_date"]),
                "ndvi_mean": ndvi_val,
                "ndwi_mean": ndwi_val if r["ndwi_mean"] is not None else None,
                "cloud_cover": cloud_val,
                "health_status": health_stat,
                "pixel_count": r.get("pixel_count", 0) or 0,
                "recommendation_bn": rec
            })

        return history_response

    except Exception as e:
        logger.error(f"Failed to fetch health history for field {id}: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database read failure retrieving health history."
        )
