"""
Akashi — Government Analytics API Routes & Role Security
=========================================================
Implements district-level agricultural health aggregations and reports for DAE.

Features:
  - Secure signed JWT government authentication (POST /gov/login)
  - Attribute-Based Access Control (ABAC) limiting query scopes strictly to assigned districts
  - Logging of government officer queries to central audit tables
  - Bypasses raw database connection requirements using PostgREST spatial queries

Reference: Akashi MVP Spec v1.0, Section 7
"""

import os
import logging
import datetime
from typing import Dict, Any, List, Optional
from fastapi import APIRouter, Depends, HTTPException, status, Security, Cookie
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from jose import jwt, JWTError
from pydantic import BaseModel, Field
from app.db.connection import db
from app.services.audit import log_audit_action

logger = logging.getLogger("akashi.gov")
router = APIRouter(prefix="/gov", tags=["Government Dashboard"])

# JWT Configuration Scopes
JWT_SECRET = os.getenv("JWT_SECRET", "change_this_secret_in_production_akashi_gov")
JWT_ALGORITHM = "HS256"

security = HTTPBearer(auto_error=False)

# List of all 64 districts in Bangladesh (Spec Appendix B)
BANGLADESH_DISTRICTS = [
    "Dhaka", "Chittagong", "Rajshahi", "Khulna", "Barishal", "Sylhet", "Rangpur", "Mymensingh",
    "Comilla", "Narayanganj", "Gazipur", "Tangail", "Faridpur", "Manikganj", "Munshiganj", 
    "Narsingdi", "Shariatpur", "Madaripur", "Gopalganj", "Kishoreganj", "Netrokona", "Jamalpur", 
    "Sherpur", "Brahmanbaria", "Chandpur", "Lakshmipur", "Noakhali", "Feni", "Khagrachhari", 
    "Rangamati", "Bandarban", "Cox's Bazar", "Bogura", "Joypurhat", "Naogaon", "Natore", 
    "Chapainawabganj", "Pabna", "Sirajganj", "Bagerhat", "Chuadanga", "Jessore", "Jhenaidah", 
    "Kushtia", "Magura", "Meherpur", "Narail", "Satkhira", "Barguna", "Bhola", "Jhalokati", 
    "Patuakhali", "Pirojpur", "Habiganj", "Moulvibazar", "Sunamganj", "Dinajpur", "Gaibandha", 
    "Kurigram", "Lalmonirhat", "Nilphamari", "Panchagarh", "Thakurgaon"
]

# ─── Pydantic Schemas ──────────────────────────────────────────────────────────

class GovLoginRequest(BaseModel):
    """Request schema for DAE Government Officer logins."""
    email: str = Field(..., description="Government officer email address, e.g. officer@tangail.gov.bd")
    password: str = Field(..., description="Secure password")

# ─── Security Dependencies ─────────────────────────────────────────────────────

async def get_current_gov_user(
    credentials: Optional[HTTPAuthorizationCredentials] = Security(security),
    gov_session: Optional[str] = Cookie(None)
) -> Dict[str, Any]:
    """
    Security dependency that validates the government user session.
    Accepts JWT tokens from either the Authorization header or an httpOnly cookie.
    """
    token = None
    if credentials:
        token = credentials.credentials
    elif gov_session:
        token = gov_session

    if not token:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="অননুমোদিত অ্যাক্সেস: অনুগ্রহ করে আপনার কৃষি আইডি দিয়ে লগইন করুন।"
        )

    try:
        payload = jwt.decode(token, JWT_SECRET, algorithms=[JWT_ALGORITHM])
        email: str = payload.get("sub", "")
        role: str = payload.get("role", "district_officer")
        district: Optional[str] = payload.get("district")
        
        if not email:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="অকার্যকর সেশন টোকেন।"
            )
            
        return {
            "email": email,
            "role": role,
            "district": district
        }
    except JWTError:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="সেশন শেষ হয়েছে। অনুগ্রহ করে আবার লগইন করুন।"
        )

# ─── Auth Endpoints ───────────────────────────────────────────────────────────

@router.post("/login", response_model=Dict[str, Any])
async def DAE_government_login(payload: GovLoginRequest):
    """
    Handles authentication for regional agricultural extension officers.
    Signs a custom, district-scoped JWT session and registers events in audit logs.
    """
    email = payload.email.strip().lower()

    # Query DAE user from DB
    try:
        existing = await db.select(
            table="government_users",
            filters={"email": f"eq.{email}"},
            limit=1
        )
    except Exception as e:
        logger.error(f"Database officer check failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="ডাটাবেজ সংযোগে ত্রুটি ঘটেছে।"
        )

    if not existing:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="অননুমোদিত অ্যাক্সেস: ভুল ইমেইল বা পাসওয়ার্ড।"
        )

    user_record = existing[0]
    stored_hash = user_record.get("password_hash")
    if not stored_hash:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="অননুমোদিত অ্যাক্সেস: ভুল ইমেইল বা পাসওয়ার্ড।"
        )

    import bcrypt
    try:
        is_valid = bcrypt.checkpw(payload.password.encode('utf-8'), stored_hash.encode('utf-8'))
    except Exception as e:
        logger.error(f"Bcrypt password verification exception: {str(e)}")
        is_valid = False

    if not is_valid:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="অননুমোদিত অ্যাক্সেস: ভুল ইমেইল বা পাসওয়ার্ড।"
        )

    district = user_record.get("district")
    role = user_record.get("role") or "district_officer"

    # Issue secure signed JWT
    token_payload = {
        "sub": email,
        "role": role,
        "district": district,
        "exp": datetime.datetime.now(datetime.UTC) + datetime.timedelta(hours=8)
    }
    
    token = jwt.encode(token_payload, JWT_SECRET, algorithm=JWT_ALGORITHM)
    
    # Log login action in audit trails
    await log_audit_action(
        actor_id=email,
        actor_role=role,
        action="login",
        district=district,
        payload={"auth_mode": "secure_jwt"}
    )
    
    return {
        "status": "success",
        "access_token": token,
        "token_type": "bearer",
        "user": {
            "email": email,
            "role": role,
            "district": district
        }
    }

# ─── Dashboard Scoped Queries ─────────────────────────────────────────────────

@router.get("/districts/{district}/health", response_model=Dict[str, Any])
async def get_district_health_summary(
    district: str,
    current_user: Dict[str, Any] = Depends(get_current_gov_user)
):
    """
    Retrieves aggregated crop health metrics for a specific Bangladesh district.
    Enforces dynamic ABAC: Assigned district officers are blocked from reading other regions.
    """
    district_clean = district.strip().title()
    
    # Enforce Attribute-Based Scoping Security
    if current_user["district"] is not None and current_user["district"].lower() != district_clean.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="অননুমোদিত: আপনি শুধুমাত্র আপনার নিজের জেলার কৃষি তথ্য দেখতে পারেন।"
        )

    # Log successful audit access
    await log_audit_action(
        actor_id=current_user["email"],
        actor_role=current_user["role"],
        action="dashboard_access",
        district=district_clean,
        payload={"metric": "health_summary"}
    )

    try:
        res = await db.select(
            table="district_health_summary",
            select_fields="*",
            filters={"district": f"eq.{district_clean}"},
            limit=1
        )
        
        if res:
            return res[0]
            
        return {
            "district": district_clean,
            "farmer_count": 0,
            "field_count": 0,
            "green_fields": 0,
            "yellow_fields": 0,
            "red_fields": 0,
            "avg_ndvi": None,
            "last_updated": "N/A"
        }
    except Exception as e:
        logger.error(f"Database health views failed: {str(e)}.")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error"
        )


@router.get("/districts/{district}/fields", response_model=List[Dict[str, Any]])
async def get_district_fields_list(
    district: str,
    current_user: Dict[str, Any] = Depends(get_current_gov_user)
):
    """
    Lists all fields in a district with their latest health status.
    Enforces district officers ABAC scopes.
    """
    district_clean = district.strip().title()
    
    if current_user["district"] is not None and current_user["district"].lower() != district_clean.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="অননুমোদিত: আপনি শুধুমাত্র আপনার নিজের জেলার কৃষি তথ্য দেখতে পারেন।"
        )

    # Log audit access
    await log_audit_action(
        actor_id=current_user["email"],
        actor_role=current_user["role"],
        action="dashboard_access",
        district=district_clean,
        payload={"metric": "fields_list"}
    )

    try:
        res = await db.select(
            table="field_latest_health",
            select_fields="*",
            filters={"district": f"eq.{district_clean}"}
        )
        return res
    except Exception as e:
        logger.error(f"Database fields list failed: {str(e)}.")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error"
        )


@router.get("/districts/{district}/report", response_model=Dict[str, Any])
async def generate_district_pdf_report_data(
    district: str,
    current_user: Dict[str, Any] = Depends(get_current_gov_user)
):
    """
    Retrieves the complete data structure required to compile a district PDF report.
    Enforces district scoping security.
    """
    district_clean = district.strip().title()
    
    if current_user["district"] is not None and current_user["district"].lower() != district_clean.lower():
        raise HTTPException(
            status_code=status.HTTP_403_FORBIDDEN,
            detail="অননুমোদিত: আপনি শুধুমাত্র আপনার নিজের জেলার তথ্য ডাউনলোড করতে পারেন।"
        )

    # Log report export action
    await log_audit_action(
        actor_id=current_user["email"],
        actor_role=current_user["role"],
        action="export",
        district=district_clean,
        payload={"format": "pdf_report"}
    )

    try:
        summary = await get_district_health_summary(district_clean, current_user=current_user)
        fields = await get_district_fields_list(district_clean, current_user=current_user)
        
        upazila_data = {}
        for f in fields:
            upazila = f.get("upazila", "Sadar")
            status_val = f.get("health_status", "unknown")
            
            if upazila not in upazila_data:
                upazila_data[upazila] = {
                    "upazila": upazila,
                    "field_count": 0,
                    "stressed_fields": 0,
                    "green_fields": 0,
                    "yellow_fields": 0,
                    "red_fields": 0
                }
            
            upazila_data[upazila]["field_count"] += 1
            if status_val == "red":
                upazila_data[upazila]["stressed_fields"] += 1
                upazila_data[upazila]["red_fields"] += 1
            elif status_val == "yellow":
                upazila_data[upazila]["yellow_fields"] += 1
            elif status_val == "green":
                upazila_data[upazila]["green_fields"] += 1

        breakdown_list = list(upazila_data.values())
        
        return {
            "district": district_clean,
            "generated_at": datetime.datetime.now().strftime("%d %B, %Y"),
            "summary": summary,
            "upazila_breakdown": breakdown_list
        }
    except Exception as e:
        logger.error(f"Error compiling report data: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail="Database error"
        )
