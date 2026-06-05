"""
Akashi — Sentinel Hub Service Unit Tests
========================================
Tests the Sentinel Hub statistical service, ensuring correct cloud masking,
health status logic, error handling for invalid polygons, and token refresh retries.
"""

import sys
from pathlib import Path
import pytest
from unittest.mock import AsyncMock, patch, MagicMock

# Add project root to path
sys.path.append(str(Path(__file__).parent.parent))

from app.services.sentinel import SentinelHubService


# ─── Mock Response Builders ───────────────────────────────────────────────────

def build_mock_statistics_response(mean_ndvi: float, sample_count: int, no_data_count: int) -> dict:
    """Builds a standard mock Statistics API response dict."""
    return {
        "data": [
            {
                "interval": {
                    "from": "2026-05-25T00:00:00Z",
                    "to": "2026-05-30T00:00:00Z"
                },
                "outputs": {
                    "ndvi": {
                        "bands": {
                            "B0": {
                                "statistics": {
                                    "mean": mean_ndvi,
                                    "sampleCount": sample_count,
                                    "noDataCount": no_data_count
                                }
                            }
                        }
                    }
                }
            }
        ]
    }


# ─── Fixtures ─────────────────────────────────────────────────────────────────

@pytest.fixture
def sentinel_service():
    """Returns a SentinelHubService configured to bypass mock mode."""
    service = SentinelHubService()
    service.client_id = "mock_client_id"
    service.client_secret = "mock_client_secret"
    return service


# ─── Tests ────────────────────────────────────────────────────────────────────

def test_calculate_health_status(sentinel_service):
    """Verifies crop-specific health status thresholds (Green/Yellow/Red)."""
    # 1. Rice thresholds (धान, rice, boro, aman, aus)
    assert sentinel_service.calculate_health_status(0.55, "rice") == "green"
    assert sentinel_service.calculate_health_status(0.50, "ধান") == "green"
    assert sentinel_service.calculate_health_status(0.40, "boro") == "yellow"
    assert sentinel_service.calculate_health_status(0.30, "aman") == "yellow"
    assert sentinel_service.calculate_health_status(0.25, "aus") == "red"
    assert sentinel_service.calculate_health_status(0.15, "rice") == "red"

    # 2. General crops thresholds (wheat/গম, jute/পাট, vegetables)
    assert sentinel_service.calculate_health_status(0.50, "jute") == "green"
    assert sentinel_service.calculate_health_status(0.45, "গম") == "green"
    assert sentinel_service.calculate_health_status(0.35, "wheat") == "yellow"
    assert sentinel_service.calculate_health_status(0.25, "পাট") == "yellow"
    assert sentinel_service.calculate_health_status(0.20, "vegetables") == "red"


@pytest.mark.asyncio
async def test_get_field_ndvi_health_outcomes(sentinel_service):
    """Tests all three crop health status paths (Green/Yellow/Red) with mocked HTTP responses."""
    polygon = {
        "type": "Polygon",
        "coordinates": [[[89.9, 24.2], [90.0, 24.2], [90.0, 24.3], [89.9, 24.3], [89.9, 24.2]]]
    }

    # Green Health (NDVI = 0.70)
    mock_response_green = MagicMock()
    mock_response_green.status_code = 200
    mock_response_green.json.return_value = build_mock_statistics_response(0.70, 1000, 100)

    # Yellow Health (NDVI = 0.40)
    mock_response_yellow = MagicMock()
    mock_response_yellow.status_code = 200
    mock_response_yellow.json.return_value = build_mock_statistics_response(0.40, 1000, 100)

    # Red Health (NDVI = 0.20)
    mock_response_red = MagicMock()
    mock_response_red.status_code = 200
    mock_response_red.json.return_value = build_mock_statistics_response(0.20, 1000, 100)

    with patch("httpx.AsyncClient.post") as mock_post:
        # Patch authentication token
        with patch.object(sentinel_service, "get_access_token", return_value="mock_token"):
            
            # Test Green
            mock_post.return_value = mock_response_green
            res_green = await sentinel_service.get_field_ndvi(polygon, "rice", "field_green")
            assert res_green["health_status"] == "green"
            assert res_green["ndvi_mean"] == 0.70

            # Test Yellow
            mock_post.return_value = mock_response_yellow
            res_yellow = await sentinel_service.get_field_ndvi(polygon, "rice", "field_yellow")
            assert res_yellow["health_status"] == "yellow"
            assert res_yellow["ndvi_mean"] == 0.40

            # Test Red
            mock_post.return_value = mock_response_red
            res_red = await sentinel_service.get_field_ndvi(polygon, "rice", "field_red")
            assert res_red["health_status"] == "red"
            assert res_red["ndvi_mean"] == 0.20


@pytest.mark.asyncio
async def test_get_field_ndvi_high_cloud_cover(sentinel_service):
    """Tests that cloud cover > 60% returns a null NDVI and appropriate reason."""
    polygon = {
        "type": "Polygon",
        "coordinates": [[[89.9, 24.2], [90.0, 24.2], [90.0, 24.3], [89.9, 24.3], [89.9, 24.2]]]
    }

    # Setup statistics response where cloud cover = 70% (700 masked out of 1000 pixels)
    mock_response = MagicMock()
    mock_response.status_code = 200
    mock_response.json.return_value = build_mock_statistics_response(0.65, 1000, 700)

    with patch("httpx.AsyncClient.post", return_value=mock_response):
        with patch.object(sentinel_service, "get_access_token", return_value="mock_token"):
            res = await sentinel_service.get_field_ndvi(polygon, "rice", "field_cloudy")
            
            assert res["ndvi"] is None
            assert res["ndvi_mean"] is None
            assert res["cloud_cover"] == 70.0
            assert res["reason"] == "high_cloud_cover"
            assert res["health_status"] == "unknown"


@pytest.mark.asyncio
async def test_get_field_ndvi_no_valid_pixels(sentinel_service):
    """Tests that cloud cover <= 60% but all pixels are NaN returns reason no_valid_pixels and unknown health."""
    polygon = {
        "type": "Polygon",
        "coordinates": [[[89.9, 24.2], [90.0, 24.2], [90.0, 24.3], [89.9, 24.3], [89.9, 24.2]]]
    }

    # Setup statistics response where sampleCount > 0, noDataCount == sampleCount (100% NaN) but cloud cover is estimated as 0 if sampleCount is 0 or stats are empty
    mock_response = MagicMock()
    mock_response.status_code = 200
    # mean is None (all NaN), sampleCount=0, noDataCount=0
    mock_response.json.return_value = build_mock_statistics_response(None, 0, 0)

    with patch("httpx.AsyncClient.post", return_value=mock_response):
        with patch.object(sentinel_service, "get_access_token", return_value="mock_token"):
            res = await sentinel_service.get_field_ndvi(polygon, "rice", "field_empty")
            
            assert res["ndvi"] is None
            assert res["ndvi_mean"] is None
            assert res["reason"] == "no_valid_pixels"
            assert res["health_status"] == "unknown"


@pytest.mark.asyncio
async def test_get_field_ndvi_invalid_polygon(sentinel_service):
    """Tests that an invalid polygon returns a clean ValueError rather than causing a 500 error."""
    # Polygon with self-intersecting / invalid geometry
    invalid_polygon = {
        "type": "Polygon",
        "coordinates": [[[0, 0], [0, 2], [2, 0], [2, 2], [0, 0]]]
    }

    with pytest.raises(ValueError) as exc_info:
        await sentinel_service.get_field_ndvi(invalid_polygon, "rice", "field_invalid")
    
    assert "Invalid polygon geometry" in str(exc_info.value)


@pytest.mark.asyncio
async def test_get_field_ndvi_api_400_error(sentinel_service):
    """Tests that a 400 Bad Request from Sentinel API (e.g. bad coords) raises clean ValueError."""
    polygon = {
        "type": "Polygon",
        "coordinates": [[[89.9, 24.2], [90.0, 24.2], [90.0, 24.3], [89.9, 24.3], [89.9, 24.2]]]
    }

    mock_response = MagicMock()
    mock_response.status_code = 400
    mock_response.text = "Invalid bounding box"

    with patch("httpx.AsyncClient.post", return_value=mock_response):
        with patch.object(sentinel_service, "get_access_token", return_value="mock_token"):
            with pytest.raises(ValueError) as exc_info:
                await sentinel_service.get_field_ndvi(polygon, "rice", "field_bad_box")
            
            assert "returned 400 Bad Request" in str(exc_info.value)


@pytest.mark.asyncio
async def test_token_refresh_on_401_retry(sentinel_service):
    """Tests that a 401 response from the Statistics API triggers a token refresh and retry."""
    polygon = {
        "type": "Polygon",
        "coordinates": [[[89.9, 24.2], [90.0, 24.2], [90.0, 24.3], [89.9, 24.3], [89.9, 24.2]]]
    }

    # Mock first request as 401 Unauthorized, and second request as 200 OK
    mock_response_401 = MagicMock()
    mock_response_401.status_code = 401
    mock_response_401.text = "Unauthorized token"

    mock_response_200 = MagicMock()
    mock_response_200.status_code = 200
    mock_response_200.json.return_value = build_mock_statistics_response(0.68, 1000, 50)

    # We patch the httpx.AsyncClient.post method to return 401 first, then 200
    with patch("httpx.AsyncClient.post") as mock_post:
        mock_post.side_effect = [mock_response_401, mock_response_200]

        # Use an AsyncMock to track get_access_token calls
        with patch.object(
            sentinel_service,
            "get_access_token",
            new_callable=AsyncMock
        ) as mock_get_token:
            
            # Setup tokens returned on successive calls
            mock_get_token.side_effect = ["old_token", "refreshed_token"]

            res = await sentinel_service.get_field_ndvi(polygon, "rice", "field_retry")

            # Check that get_access_token was called twice
            assert mock_get_token.call_count == 2
            # Check that the second call was called with force_refresh=True
            mock_get_token.assert_called_with(force_refresh=True)

            # Ensure the call succeeded on the second attempt
            assert res["ndvi_mean"] == 0.68
            assert res["health_status"] == "green"


# ─── Sentinel-1 SAR Test Cases ────────────────────────────────────────────────

def build_mock_sar_response(mean_vh: float, mean_vv: float, sample_count: int = 100) -> dict:
    """Builds a standard mock Sentinel-1 GRD Statistics API response dict in linear intensity."""
    mean_vh_linear = 10 ** (mean_vh / 10.0)
    mean_vv_linear = 10 ** (mean_vv / 10.0)
    return {
        "data": [
            {
                "interval": {
                    "from": "2026-05-25T00:00:00Z",
                    "to": "2026-05-30T00:00:00Z"
                },
                "outputs": {
                    "vh": {
                        "bands": {
                            "B0": {
                                "statistics": {
                                    "mean": mean_vh_linear,
                                    "sampleCount": sample_count
                                }
                            }
                        }
                    },
                    "vv": {
                        "bands": {
                            "B0": {
                                "statistics": {
                                    "mean": mean_vv_linear,
                                    "sampleCount": sample_count
                                }
                            }
                        }
                    }
                }
            }
        ]
    }


@pytest.mark.asyncio
async def test_fetch_sar_backscatter_health_mapping(sentinel_service):
    """Tests Sentinel-1 VH backscatter health mapping for Red, Yellow, and Green states."""
    polygon = {
        "type": "Polygon",
        "coordinates": [[[89.9, 24.2], [90.0, 24.2], [90.0, 24.3], [89.9, 24.3], [89.9, 24.2]]]
    }

    # 1. Test Red (Waterlogged, VH < -15 dB)
    mock_res_red = MagicMock()
    mock_res_red.status_code = 200
    mock_res_red.json.return_value = build_mock_sar_response(-16.5, -8.0)

    # 2. Test Yellow (Stressed: VH > -12 dB with a decreasing trend)
    mock_res_yellow = MagicMock()
    mock_res_yellow.status_code = 200
    mock_res_yellow.json.return_value = build_mock_sar_response(-11.5, -6.0)

    # 3. Test Green (Healthy standard backscatter)
    mock_res_green = MagicMock()
    mock_res_green.status_code = 200
    mock_res_green.json.return_value = build_mock_sar_response(-13.5, -7.0)

    with patch("httpx.AsyncClient.post") as mock_post:
        with patch.object(sentinel_service, "get_access_token", return_value="mock_token"):
            
            # Scenario A: Red (VH = -16.5, always red regardless of database)
            mock_post.return_value = mock_res_red
            with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=[]):
                res = await sentinel_service.fetch_sar_backscatter(polygon, "rice", "field_red")
                assert res["health_status"] == "red"
                assert res["data_source"] == "sentinel-1"
                assert res["raw_response"]["vh_mean"] == -16.5

            # Scenario B: Yellow (VH = -11.5 with decreasing trend from -10.0 in DB)
            mock_post.return_value = mock_res_yellow
            db_response_prev = [{"data_source": "sentinel-1", "raw_response": {"vh_mean": -10.0}}]
            with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=db_response_prev):
                res = await sentinel_service.fetch_sar_backscatter(polygon, "rice", "field_yellow")
                assert res["health_status"] == "yellow"
                assert res["raw_response"]["vh_mean"] == -11.5

            # Scenario C: Green (VH = -11.5 but increasing trend from -12.0 in DB -> stays green)
            mock_post.return_value = mock_res_yellow
            db_response_inc = [{"data_source": "sentinel-1", "raw_response": {"vh_mean": -12.5}}]
            with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=db_response_inc):
                res = await sentinel_service.fetch_sar_backscatter(polygon, "rice", "field_green_trend")
                assert res["health_status"] == "green"

            # Scenario D: Green (VH = -13.5, within stable zone)
            mock_post.return_value = mock_res_green
            with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=[]):
                res = await sentinel_service.fetch_sar_backscatter(polygon, "rice", "field_green_stable")
                assert res["health_status"] == "green"


@pytest.mark.asyncio
async def test_get_field_ndvi_fallback_to_sar(sentinel_service):
    """Tests that high cloud cover (> 60%) in Sentinel-2 triggers fallback to Sentinel-1 SAR."""
    polygon = {
        "type": "Polygon",
        "coordinates": [[[89.9, 24.2], [90.0, 24.2], [90.0, 24.3], [89.9, 24.3], [89.9, 24.2]]]
    }

    # Optical response returning 70% cloud cover
    mock_opt_cloudy = MagicMock()
    mock_opt_cloudy.status_code = 200
    mock_opt_cloudy.json.return_value = build_mock_statistics_response(0.65, 1000, 700)

    # Radar response returning valid backscatter (VH = -13.0)
    mock_sar_ok = MagicMock()
    mock_sar_ok.status_code = 200
    mock_sar_ok.json.return_value = build_mock_sar_response(-13.0, -6.5)

    with patch("httpx.AsyncClient.post") as mock_post:
        # First request yields cloudy optical response, second yields radar
        mock_post.side_effect = [mock_opt_cloudy, mock_sar_ok]

        with patch.object(sentinel_service, "get_access_token", return_value="mock_token"):
            with patch("app.db.connection.db.select", new_callable=AsyncMock, return_value=[]):
                res = await sentinel_service.get_field_ndvi(polygon, "rice", "field_fallback_test")
                
                # Assert that we successfully routed to Sentinel-1 GRD SAR fallback!
                assert res["data_source"] == "sentinel-1"
                assert res["health_status"] == "green"
                assert res["ndvi_mean"] is None
                assert res["cloud_cover"] == 0.0
                assert res["raw_response"]["vh_mean"] == -13.0


@pytest.mark.asyncio
async def test_sentinel_service_mock_mode_fallback():
    """Verifies that sentinel_service correctly returns mock NDVI when in mock mode."""
    # Create a service with client_id/client_secret missing (mock mode)
    service = SentinelHubService()
    service.client_id = ""
    service.client_secret = ""
    assert service._is_mock_mode() is True
    
    polygon = {
        "type": "Polygon",
        "coordinates": [[[89.9, 24.2], [90.0, 24.2], [90.0, 24.3], [89.9, 24.3], [89.9, 24.2]]]
    }
    res = await service.get_field_ndvi(polygon, "rice", "field_mock_test")
    assert res["raw_response"]["mock"] is True
    assert res["health_status"] in ["green", "yellow", "red"]
    assert res["ndvi_mean"] is not None

