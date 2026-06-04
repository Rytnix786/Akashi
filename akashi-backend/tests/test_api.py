"""
Akashi — FastAPI Integration Test Suite
=======================================
Implements comprehensive integration tests to verify REST API correctness, Pydantic
validations, custom E.164 phone checks, and mock fallbacks under pytest.

Reference: Akashi MVP Spec v1.0, Section 5
"""

import sys
from pathlib import Path
from fastapi.testclient import TestClient

# Add project root to path so we can import app modules
sys.path.append(str(Path(__file__).parent.parent))

from main import app

client = TestClient(app)

# ─── 1. Health Check Tests ────────────────────────────────────────────────────

def test_api_root_health():
    """Verifies that the API root endpoint is active and returns healthy status."""
    response = client.get("/")
    assert response.status_code == 200
    json_data = response.json()
    assert json_data["app"] == "Akashi (আকাশি)"
    assert json_data["status"] == "healthy"

def test_system_health_endpoint():
    """Verifies that the new system health endpoint performs live database metrics check and returns healthy status."""
    from unittest.mock import patch, AsyncMock
    mock_farmers = [{"id": "farmer-1"}, {"id": "farmer-2"}]
    mock_fields = [{"area_acres": 1.5}, {"area_acres": 2.3}]
    
    with patch("app.db.connection.db.select", new_callable=AsyncMock) as mock_select:
        mock_select.side_effect = [mock_farmers, mock_fields]
        
        response = client.get("/health")
        assert response.status_code == 200
        data = response.json()
        assert data["status"] == "healthy"
        assert data["database"] == "connected"
        assert data["metrics"]["total_farmers"] == 2
        assert data["metrics"]["monitored_acreage_acres"] == 3.8

# ─── 2. Phone OTP Authentication Tests ────────────────────────────────────────

def test_send_otp_valid_phone():
    """Verifies that a valid Bangladeshi phone number triggers OTP dispatch successfully."""
    from unittest.mock import patch, AsyncMock
    with patch("app.db.connection.db.send_otp", new_callable=AsyncMock, return_value={"status": "success"}):
        response = client.post("/auth/otp/send", json={"phone": "+8801712345678"})
        assert response.status_code == 200
        assert response.json()["status"] == "success"

def test_send_otp_invalid_prefix():
    """Verifies that phone numbers lacking the +880 prefix are rejected (Pydantic validation)."""
    response = client.post("/auth/otp/send", json={"phone": "01712345678"})
    assert response.status_code == 422  # Unprocessable Entity
    assert "must start with +880 prefix" in response.text

def test_send_otp_invalid_length():
    """Verifies that phone numbers with incorrect digit lengths are rejected."""
    response = client.post("/auth/otp/send", json={"phone": "+88017123456"})
    assert response.status_code == 422
    assert "exactly 10 digits after +880 prefix" in response.text

def test_verify_otp_mock_code():
    """Verifies that the OTP verification issues a valid session JWT token."""
    mock_supabase_response = {
        "session": {
            "access_token": "valid_mock_jwt_token",
            "token_type": "bearer",
            "expires_in": 3600
        },
        "user": {
            "id": "supabase-user-uuid",
            "phone": "+8801712345678",
            "role": "authenticated",
            "email": ""
        }
    }
    from unittest.mock import patch, AsyncMock
    with patch("app.db.connection.db.verify_otp", new_callable=AsyncMock, return_value=mock_supabase_response):
        response = client.post("/auth/otp/verify", json={
            "phone": "+8801712345678",
            "token": "654321"
        })
        assert response.status_code == 200
        data = response.json()
        assert "access_token" in data
        assert data["token_type"] == "bearer"
        assert data["user"]["phone"] == "+8801712345678"

def test_verify_otp_invalid_token():
    """Verifies that non-numeric or non-6-digit tokens are rejected by schema."""
    response = client.post("/auth/otp/verify", json={
        "phone": "+8801712345678",
        "token": "123a5"
    })
    assert response.status_code == 422

# ─── 3. Authenticated Route & Fallback Tests ──────────────────────────────────

def test_get_me_unauthorized():
    """Verifies that accessing protected profile routes without JWT is blocked."""
    response = client.get("/farmers/me")
    assert response.status_code == 401  # Unauthorized

def test_get_weather_fallback():
    """Verifies that the weather endpoint returns correct formats under mock fallbacks."""
    from app.api.auth import get_current_user
    app.dependency_overrides[get_current_user] = lambda: {
        "id": "supabase-user-uuid",
        "phone": "+8801712345678",
        "email": "farmer@gmail.com"
    }
    try:
        response = client.get("/weather/23.6850/90.3563")
        assert response.status_code == 200
        data = response.json()
        assert "current" in data
        assert "forecast" in data
        assert len(data["forecast"]) == 5
        assert "advisory_bn" in data
    finally:
        app.dependency_overrides.clear()

def test_get_gov_district_health_fallback():
    """Verifies that government district metrics are retrieved correctly under database success."""
    from app.api.gov import get_current_gov_user
    from unittest.mock import patch, AsyncMock
    app.dependency_overrides[get_current_gov_user] = lambda: {
        "email": "officer@gov.bd",
        "role": "district_officer",
        "district": "Tangail"
    }
    mock_db_result = [{
        "district": "Tangail",
        "farmer_count": 10,
        "field_count": 12,
        "green_fields": 8,
        "yellow_fields": 3,
        "red_fields": 1,
        "avg_ndvi": 0.55,
        "last_updated": "2026-05-30"
    }]
    try:
        with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=mock_db_result):
            response = client.get("/gov/districts/Tangail/health")
            assert response.status_code == 200
            data = response.json()
            assert data["district"] == "Tangail"
            assert "farmer_count" in data
            assert "field_count" in data
            assert "green_fields" in data
    finally:
        app.dependency_overrides.clear()
