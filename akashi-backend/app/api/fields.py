"""
Akashi — Fields Registration & GIS API Routes
============================================
Implements spatial crop field registrations and spatial coordinate lookups.

Features:
  - Calculates area in acres and local bighas using local meter-projection math
  - Computes spatial centroids for map centering
  - Encodes spatial polygons and points into PostGIS-compatible WKT (Well-Known Text) strings
  - Bypasses raw database connection requirements using PostgREST spatial queries

Reference: Akashi MVP Spec v1.0, Section 5.2 & Screen 6
"""

import math
import logging
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
from shapely.geometry import Polygon as ShapelyPolygon
from app.db.connection import db
from app.api.auth import get_current_farmer
from app.models.schemas import CreateFieldRequest, FieldDetailResponse, HealthReadingResponse
from app.services.audit import log_audit_action

logger = logging.getLogger("akashi.fields")
router = APIRouter(prefix="/fields", tags=["Fields Registration"])

# Helper function to calculate area of field in acres and bighas
def compute_field_gis_metrics(coordinates: List[List[float]]) -> tuple[float, float, float, float]:
    """
    Computes area in acres, area in bighas, and spatial centroid (lat/lon).
    Uses a highly accurate local flat-earth coordinate projection for Bangladesh (~24°N).
    """
    if len(coordinates) < 3:
        raise ValueError("Field boundary polygon must contain at least 3 points.")

    # Calculate average latitude for projection calculation
    avg_lat = sum(p[1] for p in coordinates) / len(coordinates)
    
    # Meters per degree at Bangladesh's delta location
    lat_dist = 110574.0
    lon_dist = 111320.0 * math.cos(math.radians(avg_lat))
    
    # Project coordinates to local flat-earth meters
    projected_coords = []
    for lon, lat in coordinates:
        x = lon * lon_dist
        y = lat * lat_dist
        projected_coords.append((x, y))
        
    # Calculate area using Shapely
    poly_meter = ShapelyPolygon(projected_coords)
    area_sq_meters = poly_meter.area
    
    # 1 acre = 4046.856 square meters
    acres = round(area_sq_meters / 4046.8564, 3)
    
    # 1 bigha = 0.33 acres in Bangladesh
    bigha = round(acres / 0.33, 3)

    # Compute centroid in WGS84
    poly_wgs84 = ShapelyPolygon(coordinates)
    center_lon = round(poly_wgs84.centroid.x, 6)
    center_lat = round(poly_wgs84.centroid.y, 6)

    return acres, bigha, center_lon, center_lat


@router.post("", response_model=Dict[str, Any])
async def create_field(
    payload: CreateFieldRequest,
    current_farmer: Dict[str, Any] = Depends(get_current_farmer)
):
    """
    Registers a new field with a polygon boundary.
    Computes area in acres and bighas and calculates the center point centroid.
    Spec Reference: Screen 6, Add Field Screen
    """
    if current_farmer.get("id") is None:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Farmer profile must be fully registered before creating fields."
        )

    farmer_id = current_farmer["id"]
    district = current_farmer["district"]
    upazila = current_farmer["upazila"]

    # Extract coordinates from GeoJSON outer ring
    outer_ring_coords = payload.polygon.coordinates[0]

    try:
        # Calculate GIS metrics
        acres, bigha, center_lon, center_lat = compute_field_gis_metrics(outer_ring_coords)
        
        # Build PostGIS-compatible Well-Known Text (WKT) representations
        # PostgREST natively parses WKT geometry strings prefixed with EPSG identifier (SRID=4326)
        polygon_wkt = f"SRID=4326;POLYGON(({', '.join(f'{lon} {lat}' for lon, lat in outer_ring_coords)}))"
        center_point_wkt = f"SRID=4326;POINT({center_lon} {center_lat})"

        # Insert field record
        res = await db.insert("fields", {
            "farmer_id": farmer_id,
            "name": payload.name,
            "crop_type": payload.crop_type,
            "crop_season": payload.crop_season,
            "area_acres": acres,
            "area_bigha": bigha,
            "polygon": polygon_wkt,
            "center_point": center_point_wkt,
            "district": district,
            "upazila": upazila,
            "is_active": True
        })

        logger.info(f"Registered new field '{payload.name}' ({acres} acres) for farmer {farmer_id}")
        
        # Log successful field creation in security audit logs
        new_field = res[0]
        await log_audit_action(
            actor_id=farmer_id,
            actor_role="farmer",
            action="field_created",
            district=district,
            payload={"field_id": new_field["id"], "name": payload.name, "area_acres": acres}
        )

        # Proactively trigger Phase 1 script (via sentinel_service) on signup so the farmer gets
        # their very first NDVI reading instantly instead of waiting 5 days for the cron!
        # This creates a gorgeous, instant WOW effect when onboarding!
        from app.services.sentinel import sentinel_service
        
        # We run this in background so it doesn't block the API response
        async def run_initial_ndvi():
            try:
                # 1. Fetch initial reading
                reading = await sentinel_service.get_field_ndvi(
                    polygon=payload.polygon.model_dump(),
                    crop_type=payload.crop_type,
                    field_id_str=new_field["id"]
                )
                
                # 2. Save reading
                await db.insert("health_readings", {
                    "field_id": new_field["id"],
                    "reading_date": new_field["created_at"][:10],
                    "ndvi_mean": reading["ndvi_mean"],
                    "ndwi_mean": reading["ndwi_mean"],
                    "cloud_cover": reading["cloud_cover"],
                    "health_status": reading["health_status"],
                    "pixel_count": reading["pixel_count"],
                    "raw_response": reading["raw_response"]
                })
                logger.info(f"Initial NDVI fetch completed for field {new_field['id']}. Status: {reading['health_status']}")
            except Exception as ex:
                logger.error(f"Error fetching initial NDVI for new field: {str(ex)}")

        asyncio.create_task(run_initial_ndvi())

        return {"status": "success", "field": new_field}
        
    except ValueError as e:
        raise HTTPException(
            status_code=status.HTTP_400_BAD_REQUEST,
            detail=f"Spatial geometry validation error: {str(e)}"
        )
    except Exception as e:
        logger.error(f"Failed to register field: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail=f"Database write failure: {str(e)}"
        )

# Require asyncio for initial background fetch
import asyncio

@router.get("", response_model=List[Dict[str, Any]])
async def list_fields(
    current_farmer: Dict[str, Any] = Depends(get_current_farmer)
):
    """
    Lists all fields for the authenticated farmer.
    Spec Reference: Screen 5, Home Screen (Field tab)
    """
    if current_farmer.get("id") is None:
        return []

    farmer_id = current_farmer["id"]
    try:
        fields = await db.select(
            table="fields",
            select_fields="*",
            filters={"farmer_id": f"eq.{farmer_id}", "is_active": "eq.true"}
        )
        return fields
    except Exception as e:
        logger.error(f"Failed to retrieve fields: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database read failure during fields retrieval."
        )
