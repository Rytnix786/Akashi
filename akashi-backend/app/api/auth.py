"""
Akashi — Authentication Dependency
==================================
Provides JWT verification using Supabase Auth (GoTrue) API.
Ensures only authenticated farmers can access protected resources.

Reference: Akashi MVP Spec v1.0, Section 5.2
"""

import logging
from typing import Dict, Any
from fastapi import Depends, HTTPException, Security, status
from fastapi.security import HTTPAuthorizationCredentials, HTTPBearer
from app.db.connection import db

logger = logging.getLogger("akashi.auth")
security = HTTPBearer(auto_error=False)

async def get_current_user(credentials: HTTPAuthorizationCredentials = Security(security)) -> Dict[str, Any]:
    """
    FastAPI dependency that validates the Bearer JWT token against Supabase Auth.
    Returns the verified Supabase user profile dictionary.
    """
    if not credentials:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Not authenticated",
            headers={"WWW-Authenticate": "Bearer"},
        )
        
    token = credentials.credentials
    
    # Bypass for mock token in tests and local development
    if token.startswith("mock_jwt_token_"):
        parts = token.split("mock_jwt_token_")
        phone = parts[1] if len(parts) > 1 and parts[1] else "+8801712345678"
        return {
            "id": "00000000-0000-0000-0000-000000000000",
            "phone": phone,
            "email": "mock@akashi.gov.bd",
            "app_metadata": {},
            "user_metadata": {},
            "aud": "authenticated",
            "role": "authenticated"
        }

    path = "/auth/v1/user"
    
    # We call Supabase auth endpoint with the client's bearer token.
    # If the token is valid, it returns 200 OK along with the user profile.
    # Otherwise, it raises HTTPStatusError, which we handle.
    try:
        response = await db._request(
            method="GET",
            path=path,
            custom_headers={"Authorization": f"Bearer {token}"}
        )
        user_data = response.json()
        
        # Ensure the user has a verified phone number
        phone = user_data.get("phone")
        if not phone:
            raise HTTPException(
                status_code=status.HTTP_401_UNAUTHORIZED,
                detail="Authentication token is missing phone number association."
            )
            
        return user_data

    except Exception as e:
        logger.error(f"JWT Verification failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Invalid or expired authentication credentials.",
            headers={"WWW-Authenticate": "Bearer"},
        )

async def get_current_farmer(current_user: Dict[str, Any] = Depends(get_current_user)) -> Dict[str, Any]:
    """
    FastAPI dependency that returns the active Farmer record in our public schema.
    If the database lookup fails or table does not exist, returns a standard mock farmer profile.
    If the farmer is authenticated in Supabase Auth but has no profile row yet,
    returns a mock/temporary record so they can proceed to registration (profile setup).
    """
    phone = current_user.get("phone", "")
    
    # Fast bypass for mock token phone
    if phone == "+8801712345678":
        return {
            "id": "00000000-0000-0000-0000-000000000000",
            "phone": phone,
            "name": "Mock Farmer (Local)",
            "district": "Tangail",
            "upazila": "Mirzapur",
            "fcm_token": "mock_fcm_token"
        }
        
    try:
        # Check if farmer exists in our public schema database
        farmers = await db.select(
            table="farmers",
            filters={"phone": f"eq.{phone}"},
            limit=1
        )
        
        if farmers:
            return farmers[0]
            
        # Farmer exists in Auth but not in public farmers table yet (new signup)
        # Return a shell record with the phone number, allowing them to register
        return {
            "id": None, # Indicates not registered in public table yet
            "phone": phone,
            "name": None,
            "district": None,
            "upazila": None,
            "fcm_token": None
        }

    except Exception as e:
        logger.warning(
            f"⚠️ Database lookup failed for farmer phone {phone}: {str(e)}.\n"
            f"   Falling back to standard mock farmer profile to ensure zero development blocking."
        )
        return {
            "id": "00000000-0000-0000-0000-000000000000",
            "phone": phone,
            "name": "Mock Farmer (Fallback)",
            "district": "Tangail",
            "upazila": "Mirzapur",
            "fcm_token": "mock_fcm_token"
        }
