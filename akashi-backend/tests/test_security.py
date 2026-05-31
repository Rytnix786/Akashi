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
    """Verifies that POST `/gov/login` successfully registers, logs, and issues signed JWT tokens."""
    payload = {
        "email": "officer@tangail.gov.bd",
        "password": "secure_password_123"
    }
    
    with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=[]):
        with patch("app.db.connection.db.insert", new_callable=AsyncMock) as mock_db_insert:
            response = client.post("/gov/login", json=payload)
            
            assert response.status_code == 200
            data = response.json()
            assert data["status"] == "success"
            assert "access_token" in data
            assert data["user"]["district"] == "Tangail"
            
            # Verify auto-seed insert check occurred
            mock_db_insert.assert_any_call(
                "government_users",
                {
                    "email": "officer@tangail.gov.bd",
                    "name": "দায়িত্বরত উপ-সহকারী কৃষি কর্মকর্তা",
                    "role": "district_officer",
                    "district": "Tangail"
                }
            )


@pytest.mark.asyncio
async def test_abac_district_scope_allow():
    """Verifies that an officer assigned to Tangail can successfully query Tangail health summaries."""
    # We use a mock bypass token encoding Tangail scope
    headers = {"Authorization": "Bearer mock_gov_token_Tangail"}
    
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
        response = client.get("/gov/districts/Tangail/health", headers=headers)
        assert response.status_code == 200
        assert response.json()["district"] == "Tangail"


@pytest.mark.asyncio
async def test_abac_district_scope_refusal():
    """Verifies that a Tangail officer is blocked (403 Forbidden) from querying Sylhet datasets."""
    # Tangail scoped token
    headers = {"Authorization": "Bearer mock_gov_token_Tangail"}
    
    response = client.get("/gov/districts/Sylhet/health", headers=headers)
    
    # Enforces strict 403 Forbidden!
    assert response.status_code == 403
    assert "অননুমোদিত: আপনি শুধুমাত্র আপনার নিজের জেলার" in response.json()["detail"]


@pytest.mark.asyncio
async def test_abac_national_officer_bypass():
    """Verifies that a national-level officer is allowed to query any regional district."""
    # National scope token (district = None)
    headers = {"Authorization": "Bearer mock_gov_token_National"}
    
    mock_db_res = [{"district": "Sylhet", "farmer_count": 80}]
    with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=mock_db_res):
        response = client.get("/gov/districts/Sylhet/health", headers=headers)
        assert response.status_code == 200


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
    mock_user = {
        "id": "supabase-user-uuid",
        "phone": "+8801712345678",
        "email": "farmer@gmail.com"
    }

    # Register payload including consent_given = True
    payload = {
        "name": "আব্দুল করিম",
        "district": "Tangail",
        "upazila": "Mirzapur",
        "fcm_token": "fcm_push_token_abc",
        "consent_given": True
    }

    # Mock get_current_user, DB select, update, and insert log functions
    with patch("app.api.farmers.get_current_user", return_value=mock_user):
        with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=[]):
            with patch("app.db.connection.db.insert", new_callable=AsyncMock) as mock_db_insert:
                
                headers = {"Authorization": "Bearer mock_jwt_token_test"}
                response = client.post("/farmers/register", json=payload, headers=headers)
                
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
