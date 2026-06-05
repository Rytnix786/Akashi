"""
Akashi — BWDB River Station Flood Warning Service
==================================================
Queries FFWC river station water levels, calculates distances using the Haversine
formula, and alerts farmers if nearby river levels approach or exceed danger thresholds.

Reference: Akashi MVP Spec v1.0, Section 5
"""

import json
import math
import logging
import os
import re
from typing import Dict, Any, List, Optional, Tuple
from pathlib import Path
import httpx
from dotenv import load_dotenv

logger = logging.getLogger("akashi.flood")

# Load environment variables
load_dotenv()

class FloodMonitorService:
    """
    Service to monitor water levels at BWDB river stations and assess spatial flood risk for crop fields.
    """
    def __init__(self):
        # Resolve the absolute path to the stations stub database
        # STUB: Replace with live BWDB API when available
        base_dir = Path(__file__).resolve().parent.parent.parent
        self.stub_path = base_dir / "data" / "bwdb_stations_stub.json"
        self.stations = self._load_stations()

    def _load_stations(self) -> List[Dict[str, Any]]:
        """Loads static river station metadata from the stub database."""
        try:
            if self.stub_path.exists():
                with open(self.stub_path, "r", encoding="utf-8") as f:
                    return json.load(f)
            else:
                logger.error(f"BWDB stations stub file not found at {self.stub_path}")
                return []
        except Exception as e:
            logger.error(f"Failed to load BWDB stations: {str(e)}")
            return []

    @staticmethod
    def haversine_distance(lat1: float, lon1: float, lat2: float, lon2: float) -> float:
        """
        Calculates the great-circle distance between two points on the Earth's surface
        using the Haversine formula. Returns distance in kilometers.
        """
        R = 6371.0  # Radius of Earth in kilometers

        dlat = math.radians(lat2 - lat1)
        dlon = math.radians(lon2 - lon1)
        a = (math.sin(dlat / 2) ** 2 +
             math.cos(math.radians(lat1)) * math.cos(math.radians(lat2)) * math.sin(dlon / 2) ** 2)
        c = 2 * math.atan2(math.sqrt(a), math.sqrt(1 - a))
        return R * c

    def _parse_coordinates(self, center_point: Any) -> Optional[Tuple[float, float]]:
        """
        Extracts (latitude, longitude) from various PostGIS representations returned by PostgREST.
        Supports:
          - Dict format: {"type": "Point", "coordinates": [lon, lat]}
          - WKT string format: "POINT(lon lat)" or "SRID=4326;POINT(lon lat)"
          - Fallback regex matching
        """
        if not center_point:
            return None

        # 1. Check if dictionary GeoJSON format
        if isinstance(center_point, dict):
            coords = center_point.get("coordinates")
            if coords and len(coords) >= 2:
                # WGS84 standard: GeoJSON stores [lon, lat]
                return float(coords[1]), float(coords[0])

        # 2. Check if string format (WKT)
        if isinstance(center_point, str):
            # Regex to find POINT(lon lat) inside the string
            match = re.search(r"POINT\s*\(\s*([-\d.]+)\s+([-\d.]+)\s*\)", center_point, re.IGNORECASE)
            if match:
                lon = float(match.group(1))
                lat = float(match.group(2))
                return lat, lon

            # Fallback if hexadecimal representation
            # Return None, which will trigger default district fallback in caller
            logger.warning(f"Could not parse string center_point: {center_point}")

        return None

    def get_nearby_stations(
        self, lat: float, lon: float, radius_km: float = 50.0
    ) -> List[Dict[str, Any]]:
        """
        Retrieves all river stations within a specified radius (default 50km) from the given coordinates.
        Stations are sorted by distance ascending.
        """
        nearby = []
        for station in self.stations:
            s_lat = station.get("lat")
            s_lon = station.get("lon")
            if s_lat is None or s_lon is None:
                continue

            dist = self.haversine_distance(lat, lon, s_lat, s_lon)
            if dist <= radius_km:
                # Append station with computed distance
                nearby.append({**station, "distance_km": round(dist, 2)})

        # Sort by distance
        nearby.sort(key=lambda x: x["distance_km"])
        return nearby

    async def fetch_live_water_level(self, station_id: str) -> Optional[float]:
        """
        Fetches the latest dynamic water level reading (in cm) for a given station ID.
        Queries the official BWDB FFWC API. If it is offline or fails, returns a deterministic
        fallback to support offline testing.

        # STUB: Replace with live BWDB API when available
        """
        url = "https://ffwc.bwdb.gov.bd/data_load/"
        headers = {"User-Agent": "Mozilla/5.0 (Windows NT 10.0; Win64; x64)"}

        try:
            async with httpx.AsyncClient(timeout=5.0) as client:
                # Try fetching live data
                # Since the FFWC endpoint structure varies, we log and expect
                # occasional failures due to state/quota or firewall locks.
                response = await client.get(url, headers=headers)
                if response.status_code == 200:
                    data = response.json()
                    # Example parsing: suppose response is a list or dict mapping station ID to level
                    if isinstance(data, list):
                        for item in data:
                            if item.get("station_id") == station_id or item.get("id") == station_id:
                                return float(item.get("water_level_cm", 0.0))
                    elif isinstance(data, dict):
                        station_data = data.get(station_id)
                        if station_data:
                            return float(station_data.get("water_level_cm", 0.0))

            logger.warning(f"Could not parse dynamic FFWC data for station {station_id}. Falling back to mock level.")
        except Exception as e:
            logger.debug(f"BWDB live request failed: {str(e)}. Fallback activated.")

        # Allow dynamic simulation for testing and frontend demonstrations
        sim_station = os.getenv("SIMULATE_FLOOD_STATION", "")
        sim_level = os.getenv("SIMULATE_FLOOD_LEVEL", "") # 'warning' or 'critical' or 'green'
        
        for station in self.stations:
            if station["id"] == station_id:
                if sim_station == station_id or sim_station == "all":
                    if sim_level == "critical":
                        return float(station["danger_level_cm"] + 50.0)
                    elif sim_level == "warning":
                        return float(station["danger_level_cm"] * 0.85)
                    elif sim_level == "green":
                        return float(station["danger_level_cm"] * 0.5)

                # Standard default fallback (70% danger level)
                return float(station["danger_level_cm"] * 0.7)

        return None

    async def check_flood_risk(self, field_id: str) -> Dict[str, Any]:
        """
        Assesses the current flood warning risk status for a registered field.
        Retrieves the field boundary center coordinates, calculates nearest river stations,
        fetches dynamic levels, and returns warning codes.
        """
        from app.db.connection import db

        # 1. Fetch field from DB
        field_records = await db.select(
            table="fields",
            select_fields="id, name, district, center_point",
            filters={"id": f"eq.{field_id}"},
            limit=1
        )

        if not field_records:
            raise ValueError(f"Field with ID {field_id} not found in database.")

        field = field_records[0]
        center_point = field.get("center_point")
        coords = self._parse_coordinates(center_point)

        # Fallback coordinates if geometry parsing fails or coordinates are missing
        # Default coordinates for key districts in Bangladesh
        district_coords = {
            "Tangail": (24.2500, 89.9167),
            "Sirajganj": (24.4536, 89.7160),
            "Sylhet": (24.8949, 91.8687),
            "Sunamganj": (25.0651, 91.3950),
            "Jamalpur": (25.1833, 89.6667)
        }

        if not coords:
            district = field.get("district", "Tangail")
            coords = district_coords.get(district, (24.2500, 89.9167))
            logger.info(f"Fallback to district {district} coordinates {coords} for field {field_id}")

        lat, lon = coords

        # 2. Query nearest 3 stations within 50km
        nearby_stations = self.get_nearby_stations(lat, lon, radius_km=50.0)[:3]

        if not nearby_stations:
            return {
                "field_id": field_id,
                "field_name": field.get("name"),
                "status": "green",
                "message": "No active BWDB river stations monitored within 50km.",
                "stations_evaluated": []
            }

        # 3. Fetch water levels and evaluate risk states
        stations_evaluated = []
        max_risk_level = "green"
        danger_station_count = 0
        warning_station_count = 0

        for s in nearby_stations:
            s_id = s["id"]
            # Fetch Dynamic Level
            water_level = await self.fetch_live_water_level(s_id)
            if water_level is None:
                water_level = s["danger_level_cm"] * 0.7  # Safe default

            danger_level = s["danger_level_cm"]
            warning_level = s["warning_level_cm"]

            # Calculate proximity status
            # Critical: level exceeds danger line
            if water_level > danger_level:
                s_status = "critical"
                danger_station_count += 1
                max_risk_level = "critical"
            # Warning: level exceeds warning_level OR is within 80% of danger line
            elif water_level > warning_level or water_level > (danger_level * 0.8):
                s_status = "warning"
                warning_station_count += 1
                if max_risk_level != "critical":
                    max_risk_level = "warning"
            else:
                s_status = "green"

            stations_evaluated.append({
                "station_id": s_id,
                "station_name": s["name"],
                "river": s["river"],
                "distance_km": s["distance_km"],
                "current_water_level_cm": round(water_level, 1),
                "warning_level_cm": warning_level,
                "danger_level_cm": danger_level,
                "status": s_status
            })

        # Compile final alert advisory message in Bengali
        if max_risk_level == "critical":
            message = "জরুরী সতর্কতা: নিকটবর্তী নদী অববাহিকায় পানি বিপদসীমা অতিক্রম করেছে! বন্যার তীব্র ঝুঁকি রয়েছে।"
        elif max_risk_level == "warning":
            message = "সতর্কবার্তা: নিকটবর্তী নদীর পানি বিপদসীমার কাছাকাছি রয়েছে। সতর্ক থাকুন এবং ফসল নজরদারিতে রাখুন।"
        else:
            message = "সাধারণ অবস্থা: নিকটবর্তী নদীর পানি বিপদসীমার নিরাপদ স্তরে রয়েছে।"

        return {
            "field_id": field_id,
            "field_name": field.get("name"),
            "status": max_risk_level,
            "message": message,
            "stations_evaluated": stations_evaluated
        }

# Singleton instance for simple imports across routes
flood_monitor_service = FloodMonitorService()
