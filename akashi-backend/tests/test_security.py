"""
Akashi — Security & Compliance Audit Unit Tests
===============================================
Tests CORS preflight filters, regional ABAC scoping access bounds,
government JWT logins, and DB compliance consent flows.
"""

import sys
import datetime
import pytest
from pathlib import Path
from unittest.mock import AsyncMock, patch, MagicMock, ANY
from fastapi.testclient import TestClient

# Add project root to path
sys.path.append(str(Path(__file__).parent.parent))

from main import app
from app.services.audit import log_audit_action

client = TestClient(app)


# ─── 1. CORS Origin Verification Checks ──────────────────────────────────────

def test_cors_preflight_trusted_origin():
    """Verifies that CORS preflight headers approve requests from trusted dashboard domains."""
    response = client.options(
        "/",
        headers={
            "Origin": "http://localhost:3000",
            "Access-Control-Request-Method": "GET",
            "Access-Control-Request-Headers": "content-type"
        }
    )
    assert response.status_code == 200
    assert response.headers.get("access-control-allow-origin") == "http://localhost:3000"


def test_cors_preflight_untrusted_origin_refusal():
    """Verifies that CORS preflight headers do NOT approve requests from untrusted hacker domains."""
    response = client.options(
        "/",
        headers={
            "Origin": "http://hacker-website.com",
            "Access-Control-Request-Method": "GET"
        }
    )
    # The preflight response shouldn't echo back the malicious origin
    assert response.headers.get("access-control-allow-origin") != "http://hacker-website.com"


# ─── 2. DAE Government Authentications & ABAC Scoping ────────────────────────

def test_government_login_jwt_issue():
    """Verifies that POST `/gov/login` successfully verifies, logs, and issues signed JWT tokens."""
    payload = {
        "email": "officer@tangail.gov.bd",
        "password": "secure_password_123"
    }
    
    import bcrypt
    hashed = bcrypt.hashpw(b"secure_password_123", bcrypt.gensalt()).decode('utf-8')
    mock_user = {
        "email": "officer@tangail.gov.bd",
        "name": "দায়িত্বরত উপ-সহকারী কৃষি কর্মকর্তা",
        "role": "district_officer",
        "district": "Tangail",
        "password_hash": hashed
    }
    
    with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=[mock_user]):
        with patch("app.db.connection.db.insert", new_callable=AsyncMock) as mock_db_insert:
            response = client.post("/gov/login", json=payload)
            
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "success"
            assert "access_token" in data
            assert data["user"]["district"] == "Tangail"


@pytest.mark.asyncio
async def test_abac_district_scope_allow():
    """Verifies that an officer assigned to Tangail can successfully query Tangail health summaries."""
    from app.api.gov import get_current_gov_user
    app.dependency_overrides[get_current_gov_user] = lambda: {
        "email": "officer@gov.bd",
        "role": "district_officer",
        "district": "Tangail"
    }
    
    try:
        # Mock PostGIS views queries
        mock_db_res = [{
            "district": "Tangail",
            "farmer_count": 140,
            "field_count": 220,
            "green_fields": 160,
            "yellow_fields": 40,
            "red_fields": 20,
            "avg_ndvi": 0.6134,
            "last_updated": "2026-05-30"
        }]
        
        with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=mock_db_res):
            response = client.get("/gov/districts/Tangail/health")
            assert response.status_code == 200
            assert response.json()["district"] == "Tangail"
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_abac_district_scope_refusal():
    """Verifies that a Tangail officer is blocked (403 Forbidden) from querying Sylhet datasets."""
    from app.api.gov import get_current_gov_user
    app.dependency_overrides[get_current_gov_user] = lambda: {
        "email": "officer@gov.bd",
        "role": "district_officer",
        "district": "Tangail"
    }
    
    try:
        response = client.get("/gov/districts/Sylhet/health")
        # Enforces strict 403 Forbidden!
        assert response.status_code == 403
        assert "অননুমোদিত: আপনি শুধুমাত্র আপনার নিজের জেলার" in response.json()["detail"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_abac_national_officer_bypass():
    """Verifies that a national-level officer is allowed to query any regional district."""
    from app.api.gov import get_current_gov_user
    app.dependency_overrides[get_current_gov_user] = lambda: {
        "email": "officer@gov.bd",
        "role": "national_officer",
        "district": None
    }
    
    try:
        mock_db_res = [{"district": "Sylhet", "farmer_count": 80}]
        with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=mock_db_res):
            response = client.get("/gov/districts/Sylhet/health")
            assert response.status_code == 200
    finally:
        app.dependency_overrides.clear()


# ─── 3. Centralized Audit Logging Verification ──────────────────────────────

@pytest.mark.asyncio
async def test_log_audit_action_payload():
    """Verifies that the async log_audit_action successfully formats and saves audit transactions."""
    with patch("app.db.connection.db.insert", new_callable=AsyncMock) as mock_db_insert:
        await log_audit_action(
            actor_id="farmer-id-789",
            actor_role="farmer",
            action="field_created",
            district="Tangail",
            payload={"acres": 1.42}
        )
        
        mock_db_insert.assert_called_once_with(
            "audit_logs",
            {
                "actor_id": "farmer-id-789",
                "actor_role": "farmer",
                "action": "field_created",
                "district": "Tangail",
                "payload": {"acres": 1.42}
            }
        )


# ─── 4. Farmer Privacy Consent Flows Tests ───────────────────────────────────

@pytest.mark.asyncio
async def test_farmer_registration_privacy_consent():
    """Verifies that farmer registration saves explicit privacy policy consent and logs it."""
    from app.api.auth import get_current_user
    mock_user = {
        "id": "supabase-user-uuid",
        "phone": "+8801712345678",
        "email": "farmer@gmail.com"
    }
    app.dependency_overrides[get_current_user] = lambda: mock_user

    # Register payload including consent_given = True
    payload = {
        "name": "আব্দুল করিম",
        "district": "Tangail",
        "upazila": "Mirzapur",
        "fcm_token": "fcm_push_token_abc",
        "consent_given": True
    }

    try:
        with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=[]):
            with patch("app.db.connection.db.insert", new_callable=AsyncMock) as mock_db_insert:
                
                response = client.post("/farmers/register", json=payload)
                assert response.status_code == 200
                
                # Check DB insert arguments to verify consent parameters are mapped
                mock_db_insert.assert_any_call(
                    table="farmers",
                    data={
                        "phone": "+8801712345678",
                        "name": "আব্দুল করিম",
                        "district": "Tangail",
                        "upazila": "Mirzapur",
                        "fcm_token": "fcm_push_token_abc",
                        "consent_given": True,
                        "consent_timestamp": ANY # Dynamically set timestamp
                    }
                )
    finally:
        app.dependency_overrides.clear()


# ─── 5. Mock OTP Bypass & IDOR Security Checks ────────────────────────────────

def test_mock_otp_bypass():
    """Verifies that the OTP verify endpoint bypasses external auth when token is '123456'."""
    payload = {
        "phone": "+8801700000000",
        "token": "123456"
    }
    with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=[]):
        response = client.post("/auth/otp/verify", json=payload)
        assert response.status_code == 200
        data = response.json()
        assert data["access_token"] == "mock_jwt_token_+8801700000000"
        assert data["user"]["phone"] == "+8801700000000"
        assert data["user"]["id"] == "00000000-0000-0000-0000-000000000000"


@pytest.mark.asyncio
async def test_field_endpoints_idor_refusal():
    """Verifies that field endpoints return 403 if field does not belong to current farmer."""
    from app.api.auth import get_current_farmer
    app.dependency_overrides[get_current_farmer] = lambda: {
        "id": "farmer-owner-111",
        "phone": "+8801711111111",
        "name": "Karim",
        "district": "Tangail",
        "upazila": "Mirzapur"
    }

    try:
        # Mock DB response returning a field belonging to farmer-owner-222
        mock_field_belongs_to_other = [{"farmer_id": "farmer-owner-222"}]
        
        with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=mock_field_belongs_to_other):
            # 1. Check flood-risk
            response = client.get("/fields/field-uuid-xyz/flood-risk")
            assert response.status_code == 403
            assert "অননুমোদিত অ্যাক্সেস" in response.json()["detail"]

            # 2. Check health
            response = client.get("/fields/field-uuid-xyz/health")
            assert response.status_code == 403
            assert "অননুমোদিত অ্যাক্সেস" in response.json()["detail"]

            # 3. Check history
            response = client.get("/fields/field-uuid-xyz/history")
            assert response.status_code == 403
            assert "অননুমোদিত অ্যাক্সেস" in response.json()["detail"]
    finally:
        app.dependency_overrides.clear()


@pytest.mark.asyncio
async def test_field_endpoints_idor_allow():
    """Verifies that field endpoints allow access when field belongs to current farmer."""
    from app.api.auth import get_current_farmer
    app.dependency_overrides[get_current_farmer] = lambda: {
        "id": "farmer-owner-111",
        "phone": "+8801711111111",
        "name": "Karim",
        "district": "Tangail",
        "upazila": "Mirzapur"
    }

    try:
        # Mock DB response returning field metadata belonging to farmer-owner-111
        mock_field_info = [{"farmer_id": "farmer-owner-111", "crop_type": "ধান"}]
        mock_health_reading = [{
            "id": "reading-1",
            "field_id": "field-uuid-xyz",
            "reading_date": "2026-06-01",
            "ndvi_mean": 0.65,
            "ndwi_mean": 0.25,
            "cloud_cover": 10.0,
            "health_status": "green",
            "pixel_count": 100,
            "raw_response": "{}"
        }]
        mock_flood_risk = {
            "status": "safe",
            "risk_level": "low",
            "water_level": 5.2,
            "danger_level": 8.0,
            "station_name": "Tangail Station"
        }

        # Setup mock db selects
        async def mock_db_select_impl(table, **kwargs):
            if table == "fields":
                return mock_field_info
            elif table == "health_readings":
                return mock_health_reading
            return []

        with patch("app.db.connection.db.select", side_effect=mock_db_select_impl):
            with patch("app.services.flood_monitor.flood_monitor_service.check_flood_risk", new_callable=AsyncMock, return_value=mock_flood_risk):
                # 1. Check flood-risk
                response = client.get("/fields/field-uuid-xyz/flood-risk")
                assert response.status_code == 200
                assert response.json()["status"] == "safe"

                # 2. Check health
                response = client.get("/fields/field-uuid-xyz/health")
                assert response.status_code == 200
                assert response.json()["health_status"] == "green"

                # 3. Check history
                response = client.get("/fields/field-uuid-xyz/history")
                assert response.status_code == 200
                assert len(response.json()) == 1
                assert response.json()[0]["health_status"] == "green"
    finally:
        app.dependency_overrides.clear()

