"""
Akashi — BWDB River Station Flood Warning Service Unit Tests
============================================================
Tests the Haversine distance mapping, nearby station filtering, coordinate parsing,
and flood risk evaluation states (Green/Warning/Critical) with mocked database responses.
"""

import sys
import pytest
from pathlib import Path
from unittest.mock import AsyncMock, patch, MagicMock

# Add project root to path
sys.path.append(str(Path(__file__).parent.parent))

from app.services.flood_monitor import FloodMonitorService, flood_monitor_service


# ─── 1. Distance Calculation Tests ──────────────────────────────────────────

def test_haversine_distance_accuracy():
    """Verifies that the Haversine formula calculates coordinates correctly."""
    # Coords of Hardinge Bridge (24.0744, 89.0296) and Mawa (23.3833, 90.3167)
    # Distance is approximately 151.9 km
    distance = FloodMonitorService.haversine_distance(24.0744, 89.0296, 23.3833, 90.3167)
    assert round(distance, 1) == 151.9

    # Distance to the same point must be exactly zero
    assert FloodMonitorService.haversine_distance(24.0744, 89.0296, 24.0744, 89.0296) == 0.0


# ─── 2. Geometry Coordinate Parsing Tests ────────────────────────────────────

def test_parse_coordinates_geojson_dict():
    """Verifies coordinate extraction from GeoJSON dictionary representation [lon, lat]."""
    geojson = {
        "type": "Point",
        "coordinates": [89.0296, 24.0744]
    }
    coords = flood_monitor_service._parse_coordinates(geojson)
    assert coords == (24.0744, 89.0296)


def test_parse_coordinates_wkt_string():
    """Verifies coordinate extraction from PostGIS WKT string formats."""
    wkt_simple = "POINT(89.0296 24.0744)"
    coords = flood_monitor_service._parse_coordinates(wkt_simple)
    assert coords == (24.0744, 89.0296)

    wkt_srid = "SRID=4326;POINT(89.0296 24.0744)"
    coords = flood_monitor_service._parse_coordinates(wkt_srid)
    assert coords == (24.0744, 89.0296)


def test_parse_coordinates_invalid_fallback():
    """Verifies that unparseable geometry triggers a clean None response (triggers fallback)."""
    assert flood_monitor_service._parse_coordinates(None) is None
    assert flood_monitor_service._parse_coordinates("INVALID_HEX_STRING") is None


# ─── 3. Nearby River Station Extraction Tests ────────────────────────────────

def test_get_nearby_stations():
    """Verifies that river stations within the 50km radius are fetched and sorted by proximity."""
    # Coordinate located near Sirajganj (24.4536, 89.7160)
    # The nearest stations should be Sirajganj and Kazipur
    stations = flood_monitor_service.get_nearby_stations(24.45, 89.70, radius_km=50.0)
    
    assert len(stations) >= 2
    # Ensure they are sorted by proximity (distance_km ascending)
    assert stations[0]["distance_km"] <= stations[1]["distance_km"]
    assert stations[0]["id"] == "SW90.5L"  # Sirajganj station


# ─── 4. Flood Risk Evaluation Tests ──────────────────────────────────────────

@pytest.mark.asyncio
async def test_check_flood_risk_green():
    """Tests 'green' safety warning status when water levels are normal."""
    field_id = "field-green-uuid"
    mock_field_record = [{
        "id": field_id,
        "name": "উত্তর মাঠ",
        "district": "Sirajganj",
        "center_point": "SRID=4326;POINT(89.7160 24.4536)"
    }]

    with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=mock_field_record):
        # Mock dynamic water level as normal (70% danger level)
        with patch.object(flood_monitor_service, "fetch_live_water_level", new_callable=AsyncMock, return_value=900.0):
            res = await flood_monitor_service.check_flood_risk(field_id)
            
            assert res["field_id"] == field_id
            assert res["status"] == "green"
            assert "নিরাপদ স্তরে" in res["message"]
            assert len(res["stations_evaluated"]) > 0


@pytest.mark.asyncio
async def test_check_flood_risk_warning():
    """Tests 'warning' proximity notification status when water levels are high."""
    field_id = "field-warning-uuid"
    mock_field_record = [{
        "id": field_id,
        "name": "মধ্য মাঠ",
        "district": "Sirajganj",
        "center_point": "SRID=4326;POINT(89.7160 24.4536)"
    }]

    # Sirajganj station danger level is 1380 cm. 85% of it is 1173 cm, which exceeds 80% (1104 cm) -> Warning
    warning_level = 1380 * 0.85

    with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=mock_field_record):
        with patch.object(flood_monitor_service, "fetch_live_water_level", new_callable=AsyncMock, return_value=warning_level):
            res = await flood_monitor_service.check_flood_risk(field_id)
            
            assert res["field_id"] == field_id
            assert res["status"] == "warning"
            assert "বিপদসীমার কাছাকাছি" in res["message"]


@pytest.mark.asyncio
async def test_check_flood_risk_critical():
    """Tests 'critical' active flood risk notification status when water levels exceed danger lines."""
    field_id = "field-critical-uuid"
    mock_field_record = [{
        "id": field_id,
        "name": "দক্ষিণ মাঠ",
        "district": "Sirajganj",
        "center_point": "SRID=4326;POINT(89.7160 24.4536)"
    }]

    # Exceeds Sirajganj danger level (1380 cm)
    critical_level = 1450.0

    with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=mock_field_record):
        with patch.object(flood_monitor_service, "fetch_live_water_level", new_callable=AsyncMock, return_value=critical_level):
            res = await flood_monitor_service.check_flood_risk(field_id)
            
            assert res["field_id"] == field_id
            assert res["status"] == "critical"
            assert "পানি বিপদসীমা অতিক্রম" in res["message"]
            assert res["stations_evaluated"][0]["status"] == "critical"


@pytest.mark.asyncio
async def test_fetch_live_water_level_simulation():
    """Verifies that fetch_live_water_level respects simulation environment variables."""
    import os
    from unittest.mock import patch
    
    service = FloodMonitorService()
    station_id = "SW90.5L" # Sirajganj station
    
    # 1. Test simulation: critical
    with patch.dict(os.environ, {"SIMULATE_FLOOD_STATION": station_id, "SIMULATE_FLOOD_LEVEL": "critical"}):
        level = await service.fetch_live_water_level(station_id)
        # Danger level for Sirajganj is 1380
        assert level > 1380.0
        
    # 2. Test simulation: warning
    with patch.dict(os.environ, {"SIMULATE_FLOOD_STATION": "all", "SIMULATE_FLOOD_LEVEL": "warning"}):
        level = await service.fetch_live_water_level(station_id)
        # 1380 * 0.85 = 1173
        assert level == 1380.0 * 0.85

    # 3. Test simulation: green
    with patch.dict(os.environ, {"SIMULATE_FLOOD_STATION": "all", "SIMULATE_FLOOD_LEVEL": "green"}):
        level = await service.fetch_live_water_level(station_id)
        # 1380 * 0.5 = 690
        assert level == 1380.0 * 0.5
