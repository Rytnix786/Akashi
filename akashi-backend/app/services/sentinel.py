"""
Akashi — Sentinel Hub Service Layer
===================================
Handles all interactions with the ESA Sentinel-2 satellite constellation via the
Sentinel Hub Statistical API v3. 

Includes a senior-grade automatic MOCK FALLBACK when credentials are not configured or invalid,
ensuring uninterrupted end-to-end application testing and developer productivity.

Reference: Akashi MVP Spec v1.0, Section 5.3 & 12
"""

import os
import logging
import random
import hashlib
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, Optional, Tuple
import httpx
from app.models.schemas import GeoJsonPolygon

logger = logging.getLogger("akashi.sentinel")

# Sentinel Hub API endpoints
TOKEN_URL = "https://services.sentinel-hub.com/auth/realms/main/protocol/openid-connect/token"
STATISTICS_URL = "https://services.sentinel-hub.com/api/v1/statistics"

# Exact NDVI Evalscript from Spec (masks clouds, shadows, and cirrus via SCL)
NDVI_EVALSCRIPT = """//VERSION=3
function setup() {
  return {
    input: [{
      bands: ["B04", "B08", "SCL"],
      units: "DN"
    }],
    output: [
      { id: "ndvi", bands: 1, sampleType: "FLOAT32" },
      { id: "dataMask", bands: 1, sampleType: "UINT8" }
    ]
  };
}

function evaluatePixel(s) {
  // Mask clouds (8, 9, 10), cloud shadows (3), and cirrus (11)
  if ([3, 8, 9, 10, 11].includes(s.SCL[0])) {
    return { ndvi: [NaN], dataMask: [0] };
  }
  const ndvi = (s.B08[0] - s.B04[0]) / (s.B08[0] + s.B04[0]);
  return { ndvi: [ndvi], dataMask: [1] };
}
"""

# Sentinel-1 SAR GRD Radar Evalscript (polarizations VV + VH)
SAR_EVALSCRIPT = """//VERSION=3
function setup() {
  return {
    input: [{
      bands: ["VV", "VH", "dataMask"]
    }],
    output: [
      { id: "vv", bands: 1, sampleType: "FLOAT32" },
      { id: "vh", bands: 1, sampleType: "FLOAT32" },
      { id: "dataMask", bands: 1, sampleType: "UINT8" }
    ]
  };
}

function evaluatePixel(samples) {
  return {
    vv: [samples.VV],
    vh: [samples.VH],
    dataMask: [samples.dataMask]
  };
}
"""


class SentinelHubService:
    """Service class encapsulating OAuth2 and Statistical API calls."""
    
    def __init__(self):
        self.client_id = os.getenv("SENTINEL_HUB_CLIENT_ID", "")
        self.client_secret = os.getenv("SENTINEL_HUB_CLIENT_SECRET", "")
        self.token: Optional[str] = None
        self.token_expiry: Optional[datetime] = None

    def _is_mock_mode(self) -> bool:
        """Returns True if Sentinel Hub keys are not configured or are set to placeholders."""
        if not self.client_id or not self.client_secret:
            return True
        if self.client_id == "your_client_id_here" or self.client_secret == "your_client_secret_here":
            return True
        return False

    async def get_access_token(self, force_refresh: bool = False) -> Optional[str]:
        """
        Retrieves OAuth2 access token. Caches token in memory until expiry.
        Returns None if authentication fails, triggering mock fallback.
        """
        if self._is_mock_mode():
            logger.warning("Sentinel Hub credentials not set. Operating in DEMO/MOCK mode.")
            return None

        # Check if cached token is still valid
        if not force_refresh and self.token and self.token_expiry and datetime.now(timezone.utc) < self.token_expiry:
            return self.token

        logger.info("🔑 Refreshing Sentinel Hub OAuth2 Token...")
        async with httpx.AsyncClient(timeout=15.0) as client:
            try:
                response = await client.post(
                    TOKEN_URL,
                    data={
                        "grant_type": "client_credentials",
                        "client_id": self.client_id,
                        "client_secret": self.client_secret
                    },
                    headers={"Content-Type": "application/x-www-form-urlencoded"}
                )
                if response.status_code != 200:
                    logger.error(f"Sentinel Hub OAuth failed: {response.status_code} - {response.text}")
                    return None
                
                data = response.json()
                self.token = data.get("access_token")
                expires_in = data.get("expires_in", 3600)
                # Expire token 1 minute early for safety
                self.token_expiry = datetime.now(timezone.utc) + timedelta(seconds=expires_in - 60)
                logger.info("✅ Sentinel Hub token refreshed successfully.")
                return self.token
            except Exception as e:
                logger.error(f"Error fetching Sentinel Hub OAuth token: {str(e)}")
                return None

    def _generate_mock_ndvi(self, field_id_str: str, crop_type: str) -> Dict[str, Any]:
        """
        Generates deterministic, highly realistic mock NDVI readings based on
        hashing the field's ID and crop type. This ensures the reading is stable
        yet realistic for the front-end to showcase green/yellow/red health cards.
        """
        # Create a stable seed from field_id
        seed = int(hashlib.md5(field_id_str.encode()).hexdigest(), 16)
        r = random.Random(seed)

        # Decide health status deterministically based on seed
        # 70% chance Green, 20% chance Yellow, 10% chance Red
        rand_val = r.random()
        
        is_rice = crop_type in ["ধান", "rice", "boro", "aman", "aus"]

        if rand_val < 0.70:
            # Green (Healthy)
            ndvi = r.uniform(0.52, 0.78) if is_rice else r.uniform(0.48, 0.72)
            ndwi = r.uniform(0.1, 0.4) # Hydrated
            status = "green"
        elif rand_val < 0.90:
            # Yellow (Stressed/Attention Needed)
            ndvi = r.uniform(0.32, 0.49) if is_rice else r.uniform(0.28, 0.44)
            ndwi = r.uniform(-0.1, 0.09) # Moderately dry
            status = "yellow"
        else:
            # Red (Urgent Care Needed)
            ndvi = r.uniform(0.15, 0.29) if is_rice else r.uniform(0.12, 0.24)
            ndwi = r.uniform(-0.4, -0.11) # Severe water stress
            status = "red"

        now = datetime.now(timezone.utc)
        return {
            "ndvi_mean": round(ndvi, 4),
            "ndwi_mean": round(ndwi, 4),
            "cloud_cover": round(r.uniform(0.0, 15.0), 1),
            "health_status": status,
            "pixel_count": r.randint(400, 1200),
            "date_from": (now - timedelta(days=5)).strftime("%Y-%m-%dT%H:%M:%SZ"),
            "date_to": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
            "raw_response": {"mock": True, "generated_at": now.isoformat()}
        }

    async def get_field_ndvi(
        self,
        polygon: Dict[str, Any],
        crop_type: str,
        field_id_str: str,
        days_back: int = 5,
        max_cloud_coverage: int = 30
    ) -> Dict[str, Any]:
        """
        Queries the Sentinel Hub Statistical API for the specified field polygon.
        Ensures that failures raise exceptions instead of silently falling back to mock data.
        """
        # Validate polygon geometry
        from shapely.geometry import shape
        try:
            geom = shape(polygon)
            if not geom.is_valid:
                raise ValueError("Invalid polygon geometry: Geometry is self-intersecting or invalid.")
        except Exception as e:
            raise ValueError(f"Invalid polygon geometry: {str(e)}")

        if self._is_mock_mode():
            logger.info(f"Sentinel Hub operating in MOCK/DEMO mode. Returning deterministic NDVI fallback for field {field_id_str}.")
            return self._generate_mock_ndvi(field_id_str, crop_type)

        token = await self.get_access_token()
        
        if not token:
            raise RuntimeError("Sentinel Hub authentication failed. Access token is empty or invalid.")

        now = datetime.now(timezone.utc)
        start = now - timedelta(days=days_back)

        # Build standard Statistics API payload
        payload = {
            "input": {
                "bounds": {
                    "geometry": polygon,
                    "properties": {"crs": "http://www.opengis.net/def/crs/EPSG/0/4326"},
                },
                "data": [{
                    "type": "sentinel-2-l2a",
                    "dataFilter": {
                        "maxCloudCoverage": max_cloud_coverage,
                    },
                }],
            },
            "aggregation": {
                "timeRange": {
                    "from": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "to": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                },
                "aggregationInterval": {
                    "of": "P5D",
                },
                "evalscript": NDVI_EVALSCRIPT,
                # 0.00009 degrees is approximately 10m in unit distance at WGS84 for Bangladesh
                "resx": 0.00009,
                "resy": 0.00009,
            },
            "calculations": {
                "ndvi": {
                    "statistics": {
                        "default": {
                            "percentiles": {"k": [25, 50, 75]}
                        }
                    }
                }
            },
        }

        logger.info(f"📡 Querying Sentinel Hub Statistics API for field {field_id_str}...")
        async with httpx.AsyncClient(timeout=45.0) as client:
            try:
                response = await client.post(
                    STATISTICS_URL,
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json",
                        "Accept": "application/json"
                    }
                )
                
                # Check response. If API key expired, force refresh and retry once
                if response.status_code == 401:
                    logger.warning("Sentinel token expired or 401 received. Attempting to force refresh and retry...")
                    token = await self.get_access_token(force_refresh=True)
                    if not token:
                        raise RuntimeError("Sentinel Hub authentication failed after 401 token refresh retry.")
                    response = await client.post(
                        STATISTICS_URL,
                        json=payload,
                        headers={
                            "Authorization": f"Bearer {token}",
                            "Content-Type": "application/json",
                            "Accept": "application/json"
                        }
                    )

                if response.status_code == 400:
                    raise ValueError(f"Sentinel Statistics API returned 400 Bad Request: {response.text}")

                if response.status_code != 200:
                    raise RuntimeError(f"Sentinel Statistics API returned {response.status_code}: {response.text}")

                data = response.json()
                results = data.get("data", [])
                
                if not results:
                    raise ValueError(f"No satellite data returned for field {field_id_str}. Check date range and cloud cover.")

                latest = results[-1]
                interval = latest.get("interval", {})
                outputs = latest.get("outputs", {})

                ndvi_bands = outputs.get("ndvi", {}).get("bands", {})
                band_data = ndvi_bands.get("B0", {})
                stats = band_data.get("statistics", {})

                ndvi_mean = stats.get("mean")
                sample_count = stats.get("sampleCount", 0)
                no_data_count = stats.get("noDataCount", 0)

                # Estimate cloud cover as ratio of no-data (cloud-masked) pixels
                cloud_cover_pct = 0.0
                if sample_count > 0:
                    cloud_cover_pct = (no_data_count / sample_count) * 100.0

                # Return null NDVI if cloud cover is above 60% or no valid data
                is_cloudy = cloud_cover_pct > 60.0
                is_empty = ndvi_mean is None or (sample_count > 0 and no_data_count == sample_count)

                if is_cloudy or is_empty:
                    reason = "high_cloud_cover" if is_cloudy else "no_valid_pixels"
                    logger.warning(f"Optical Sentinel-2 data unavailable. Reason: {reason} (cloud_cover: {cloud_cover_pct:.1f}%). Falling back to Sentinel-1 SAR...")
                    try:
                        return await self.fetch_sar_backscatter(
                            polygon=polygon,
                            crop_type=crop_type,
                            field_id_str=field_id_str,
                            days_back=30
                        )
                    except Exception as sar_err:
                        logger.error(f"Sentinel-1 SAR fallback failed: {str(sar_err)}")
                        return {
                            "ndvi": None,
                            "ndvi_mean": None,
                            "ndwi_mean": None,
                            "cloud_cover": round(cloud_cover_pct, 1),
                            "health_status": "unknown",
                            "pixel_count": 0,
                            "reason": reason,
                            "data_source": "sentinel-2",
                            "date_from": interval.get("from") if interval else start.strftime("%Y-%m-%dT%H:%M:%SZ"),
                            "date_to": interval.get("to") if interval else now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                            "raw_response": data
                        }

                valid_pixels = sample_count - no_data_count

                # Calculate health status using spec thresholds
                status = self.calculate_health_status(ndvi_mean, crop_type)

                return {
                    "ndvi": round(ndvi_mean, 4),
                    "ndvi_mean": round(ndvi_mean, 4),
                    "ndwi_mean": None, # Default Processing API v3 needs separate NDWI evalscript
                    "cloud_cover": round(cloud_cover_pct, 1),
                    "health_status": status,
                    "pixel_count": valid_pixels,
                    "data_source": "sentinel-2",
                    "date_from": interval.get("from"),
                    "date_to": interval.get("to"),
                    "raw_response": data
                }

            except (ValueError, RuntimeError):
                raise
            except Exception as e:
                logger.error(f"Exception querying Sentinel Hub Statistics API: {str(e)}")
                raise RuntimeError(f"Exception querying Sentinel Hub Statistics API: {str(e)}")

    async def fetch_sar_backscatter(
        self,
        polygon: Dict[str, Any],
        crop_type: str,
        field_id_str: str,
        days_back: int = 30
    ) -> Dict[str, Any]:
        """
        Queries Sentinel-1 GRD radar data via the Statistical API.
        Used as a robust fallback during the cloudy monsoon season.
        """
        if self._is_mock_mode():
            logger.info(f"Sentinel Hub operating in MOCK/DEMO mode. Returning deterministic SAR fallback for field {field_id_str}.")
            import hashlib
            import random
            seed = int(hashlib.md5(field_id_str.encode()).hexdigest(), 16)
            r = random.Random(seed)
            rand_val = r.random()
            status = "green" if rand_val < 0.70 else "yellow" if rand_val < 0.90 else "red"
            vh_mean = -11.5 if status == "green" else -13.5 if status == "yellow" else -16.5
            vv_mean = vh_mean + 6.0
            now = datetime.now(timezone.utc)
            return {
                "ndvi": None,
                "ndvi_mean": None,
                "ndwi_mean": None,
                "cloud_cover": 0.0,
                "health_status": status,
                "pixel_count": r.randint(400, 1200),
                "data_source": "sentinel-1",
                "date_from": (now - timedelta(days=30)).strftime("%Y-%m-%dT%H:%M:%SZ"),
                "date_to": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                "raw_response": {
                    "vh_mean": round(vh_mean, 4),
                    "vv_mean": round(vv_mean, 4),
                    "data_source": "sentinel-1",
                    "original_response": {"mock": True, "generated_at": now.isoformat()}
                }
            }

        token = await self.get_access_token()
        if not token:
            raise RuntimeError("Sentinel Hub authentication failed for Sentinel-1 query.")

        now = datetime.now(timezone.utc)
        start = now - timedelta(days=days_back if days_back >= 30 else 30)

        payload = {
            "input": {
                "bounds": {
                    "geometry": polygon,
                    "properties": {"crs": "http://www.opengis.net/def/crs/EPSG/0/4326"},
                },
                "data": [{
                    "type": "sentinel-1-grd",
                    "dataFilter": {
                        "acquisitionMode": "IW",
                        "polarization": "DV",
                        "resolution": "HIGH"
                    },
                    "processing": {
                        "backscatterCoeff": "SIGMA0_DB",
                        "orthorectify": True
                    }
                }],
            },
            "aggregation": {
                "timeRange": {
                    "from": start.strftime("%Y-%m-%dT%H:%M:%SZ"),
                    "to": now.strftime("%Y-%m-%dT%H:%M:%SZ"),
                },
                "aggregationInterval": {
                    "of": "P5D",
                },
                "evalscript": SAR_EVALSCRIPT,
                "resx": 0.00009,
                "resy": 0.00009,
            },
            "calculations": {
                "vv": {
                    "statistics": {
                        "default": {
                            "percentiles": {"k": [50]}
                        }
                    }
                },
                "vh": {
                    "statistics": {
                        "default": {
                            "percentiles": {"k": [50]}
                        }
                    }
                }
            },
        }

        logger.info(f"📡 Querying Sentinel-1 SAR Statistics API for field {field_id_str}...")
        async with httpx.AsyncClient(timeout=45.0) as client:
            try:
                response = await client.post(
                    STATISTICS_URL,
                    json=payload,
                    headers={
                        "Authorization": f"Bearer {token}",
                        "Content-Type": "application/json",
                        "Accept": "application/json"
                    }
                )

                if response.status_code == 401:
                    logger.warning("Sentinel token expired or 401 received during SAR query. Attempting to force refresh and retry...")
                    token = await self.get_access_token(force_refresh=True)
                    if not token:
                        raise RuntimeError("Sentinel Hub authentication failed after 401 token refresh retry inside SAR.")
                    response = await client.post(
                        STATISTICS_URL,
                        json=payload,
                        headers={
                            "Authorization": f"Bearer {token}",
                            "Content-Type": "application/json",
                            "Accept": "application/json"
                        }
                    )

                if response.status_code == 400:
                    raise ValueError(f"Sentinel-1 SAR Statistics API returned 400 Bad Request: {response.text}")

                if response.status_code != 200:
                    raise RuntimeError(f"Sentinel-1 SAR Statistics API returned {response.status_code}: {response.text}")

                data = response.json()
                results = data.get("data", [])

                if not results:
                    raise ValueError(f"No Sentinel-1 SAR acquisition intervals returned for field {field_id_str}.")

                latest = results[-1]
                interval = latest.get("interval", {})
                outputs = latest.get("outputs", {})

                vh_bands = outputs.get("vh", {}).get("bands", {})
                vh_stats = vh_bands.get("B0", {}).get("stats", {}) or vh_bands.get("B0", {}).get("statistics", {})
                vh_mean_linear = vh_stats.get("mean")

                vv_bands = outputs.get("vv", {}).get("bands", {})
                vv_stats = vv_bands.get("B0", {}).get("stats", {}) or vv_bands.get("B0", {}).get("statistics", {})
                vv_mean_linear = vv_stats.get("mean")

                if vh_mean_linear is None or vv_mean_linear is None:
                    raise ValueError("Sentinel-1 SAR statistics values are empty.")

                # Convert linear intensity to decibels (dB) scale: 10 * log10(intensity)
                import math
                vh_mean = 10 * math.log10(vh_mean_linear) if vh_mean_linear > 0 else -999.0
                vv_mean = 10 * math.log10(vv_mean_linear) if vv_mean_linear > 0 else -999.0

                # Calculate trend from database
                prev_vh = None
                from app.db.connection import db
                try:
                    latest_readings = await db.select(
                        table="health_readings",
                        select_fields="raw_response, data_source",
                        filters={"field_id": f"eq.{field_id_str}"},
                        order_by="reading_date.desc",
                        limit=1
                    )
                    if latest_readings and latest_readings[0].get("data_source") == "sentinel-1":
                        raw_resp = latest_readings[0].get("raw_response", {})
                        prev_vh = raw_resp.get("vh_mean")
                except Exception as ex:
                    logger.error(f"Error querying previous reading for trend calculation: {str(ex)}")

                # Map backscatter: VH > -12 dB with decreasing trend = yellow, < -15 dB = red, else green
                is_decreasing = prev_vh is not None and vh_mean < prev_vh
                
                if vh_mean < -15.0:
                    status = "red"
                elif vh_mean > -12.0 and is_decreasing:
                    status = "yellow"
                else:
                    status = "green"

                logger.info(f"Sentinel-1 SAR analysis: VH={vh_mean:.2f}dB (prev={prev_vh}dB, decr={is_decreasing}) -> Status: {status}")

                pixel_count = vh_stats.get("sampleCount", 0)

                return {
                    "ndvi": None,
                    "ndvi_mean": None,
                    "ndwi_mean": None,
                    "cloud_cover": 0.0,
                    "health_status": status,
                    "pixel_count": pixel_count,
                    "data_source": "sentinel-1",
                    "date_from": interval.get("from"),
                    "date_to": interval.get("to"),
                    "raw_response": {
                        "vh_mean": round(vh_mean, 4),
                        "vv_mean": round(vv_mean, 4),
                        "data_source": "sentinel-1",
                        "original_response": data
                    }
                }

            except (ValueError, RuntimeError):
                raise
            except Exception as e:
                logger.error(f"Exception querying Sentinel-1 SAR Statistics API: {str(e)}")
                raise RuntimeError(f"Exception querying Sentinel-1 SAR Statistics API: {str(e)}")

    @staticmethod
    def calculate_health_status(ndvi: float, crop_type: str) -> str:
        """
        Calculates health status (green/yellow/red) based on crop specific thresholds.
        Spec Reference: Section 5.3 Step 3
        """
        # Rice (ধান) thresholds
        if crop_type in ["ধান", "rice", "boro", "aman", "aus"]:
            if ndvi >= 0.50:
                return "green"
            if ndvi >= 0.30:
                return "yellow"
            return "red"
        # Other standard crops (wheat, jute, etc.)
        else:
            if ndvi >= 0.45:
                return "green"
            if ndvi >= 0.25:
                return "yellow"
            return "red"

# Singleton instance
sentinel_service = SentinelHubService()
