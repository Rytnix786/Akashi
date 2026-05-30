"""
Akashi — Pydantic Validation Models
===================================
Defines request and response schemas for all API endpoints.
Uses Pydantic v2 patterns to enforce structural correctness and input sanitization.

Reference: Akashi MVP Spec v1.0, Section 5
"""

from typing import Any, Dict, List, Optional
from pydantic import BaseModel, Field, field_validator

# ─── Auth Schemas ─────────────────────────────────────────────────────────────

class SendOtpRequest(BaseModel):
    """Request schema for sending OTP to a phone number."""
    phone: str = Field(..., description="Bangladeshi phone number in E.164 format, e.g., +8801712345678")

    @field_validator("phone")
    @classmethod
    def validate_bangladesh_phone(cls, value: str) -> str:
        """Ensures phone number starts with +880 and has correct length."""
        value = value.strip()
        if not value.startswith("+880"):
            raise ValueError("Phone number must start with +880 prefix.")
        # +880 plus 10 digits = 14 characters
        if len(value) != 14 or not value[4:].isdigit():
            raise ValueError("Phone number must contain exactly 10 digits after +880 prefix.")
        return value

class VerifyOtpRequest(BaseModel):
    """Request schema for verifying OTP."""
    phone: str = Field(..., description="Bangladeshi phone number")
    token: str = Field(..., description="6-digit OTP code")

    @field_validator("token")
    @classmethod
    def validate_otp_token(cls, value: str) -> str:
        value = value.strip()
        if len(value) != 6 or not value.isdigit():
            raise ValueError("OTP token must be exactly 6 numeric digits.")
        return value

class AuthResponse(BaseModel):
    """Response schema containing JWT access token and farmer profile."""
    access_token: str
    token_type: str = "bearer"
    expires_in: int
    user: Dict[str, Any]

# ─── Farmer Schemas ───────────────────────────────────────────────────────────

class RegisterFarmerRequest(BaseModel):
    """Request schema for profile setup / registration."""
    name: Optional[str] = Field(None, max_length=100, description="Farmer's full name")
    district: str = Field(..., description="One of 64 districts in Bangladesh")
    upazila: str = Field(..., description="Upazila name")
    fcm_token: Optional[str] = Field(None, description="FCM Push notification token")

class UpdateFcmRequest(BaseModel):
    """Request schema for silent FCM token updates."""
    fcm_token: str = Field(..., description="FCM push token")

# ─── Field Schemas ────────────────────────────────────────────────────────────

class GeoJsonPolygon(BaseModel):
    """Validates GeoJSON Polygon geometry format."""
    type: str = Field("Polygon", pattern="^Polygon$")
    coordinates: List[List[List[float]]] = Field(..., description="WGS84 lon, lat coordinates of boundary")

    @field_validator("coordinates")
    @classmethod
    def validate_polygon_closed(cls, value: List[List[List[float]]]) -> List[List[List[float]]]:
        if not value or len(value) < 1:
            raise ValueError("Polygon must have at least one ring.")
        outer_ring = value[0]
        if len(outer_ring) < 4:
            raise ValueError("Polygon outer ring must contain at least 4 coordinates (min 3 unique points + closed loop).")
        # Check if polygon is closed (first coord matches last coord)
        first, last = outer_ring[0], outer_ring[-1]
        if abs(first[0] - last[0]) > 1e-7 or abs(first[1] - last[1]) > 1e-7:
            raise ValueError("Polygon coordinates must form a closed loop (first and last coordinates must match).")
        
        # Verify coordinates are roughly within Bangladesh bounds (Lon: 88-93, Lat: 20-27)
        for coord in outer_ring:
            lon, lat = coord[0], coord[1]
            if not (88.0 <= lon <= 93.0) or not (20.0 <= lat <= 27.0):
                raise ValueError(f"Coordinate [{lon}, {lat}] is outside Bangladesh geographic bounds.")
        return value

class CreateFieldRequest(BaseModel):
    """Request schema for registering a new field."""
    name: str = Field("আমার জমি", max_length=50, description="Field name")
    crop_type: str = Field(..., description=" ধান | গম | পাট | সবজি | অন্যান্য ")
    crop_season: Optional[str] = Field(None, description=" Boro | Aman | Aus | Rabi ")
    polygon: GeoJsonPolygon = Field(..., description="GeoJSON polygon coordinates drawn on map")

# ─── Health Reading Schemas ───────────────────────────────────────────────────

class HealthReadingResponse(BaseModel):
    """Response schema representing a single NDVI health reading."""
    reading_date: str
    ndvi_mean: Optional[float]
    ndwi_mean: Optional[float]
    cloud_cover: float
    health_status: str
    pixel_count: int
    recommendation_bn: str

class FieldDetailResponse(BaseModel):
    """Detailed response schema for a single field's details and health status."""
    id: str
    name: str
    crop_type: str
    crop_season: Optional[str]
    area_acres: float
    area_bigha: float
    district: str
    upazila: str
    created_at: str
    latest_reading: Optional[HealthReadingResponse] = None
    history: List[HealthReadingResponse] = []
