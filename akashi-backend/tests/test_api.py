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

# ─── 2. Phone OTP Authentication Tests ────────────────────────────────────────

def test_send_otp_valid_phone():
    """Verifies that a valid Bangladeshi phone number triggers OTP dispatch successfully."""
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
    """Verifies that the mock code '123456' issues a valid session JWT token."""
    response = client.post("/auth/otp/verify", json={
        "phone": "+8801712345678",
        "token": "123456"
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
    # We pass the mock token as authorization header
    headers = {"Authorization": "Bearer mock_jwt_token_for_frictionless_developer_testing_akashi"}
    response = client.get("/weather/23.6850/90.3563", headers=headers)
    assert response.status_code == 200
    data = response.json()
    assert "current" in data
    assert "forecast" in data
    assert len(data["forecast"]) == 5
    assert "advisory_bn" in data

def test_get_gov_district_health_fallback():
    """Verifies that government district metrics are retrieved correctly under fallbacks."""
    response = client.get("/gov/districts/Tangail/health")
    assert response.status_code == 200
    data = response.json()
    assert data["district"] == "Tangail"
    assert "farmer_count" in data
    assert "field_count" in data
    assert "green_fields" in data
