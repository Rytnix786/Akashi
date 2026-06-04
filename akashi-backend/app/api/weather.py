"""
Akashi — Bengali Weather Forecast API Routes
============================================
Delivers localized 7-day weather summaries and agronomic rain warnings in Bengali.

Features:
  - Fetches real-time forecasts from OpenWeatherMap (using client keys)
  - Translates weather conditions, day names, and alerts into authentic Bengali
  - Generates agricultural fertilizing advisories based on multi-day rain thresholds
  - Resilient mock weather generator fallback to guarantee runtime uptime

Reference: Akashi MVP Spec v1.0, Screen 8
"""

import os
import logging
import math
from datetime import datetime, timezone, timedelta
from typing import Dict, Any, List
from fastapi import APIRouter, Depends, HTTPException, status
import httpx
from app.api.auth import get_current_farmer

logger = logging.getLogger("akashi.weather")
router = APIRouter(prefix="/weather", tags=["Bilingual Weather Forecast"])

# English to Bengali mappings
BENGALI_DAYS = {
    "Monday": "সোমবার",
    "Tuesday": "মঙ্গলবার",
    "Wednesday": "বুধবার",
    "Thursday": "বৃহস্পতিবার",
    "Friday": "শুক্রবার",
    "Saturday": "শনিবার",
    "Sunday": "রবিবার"
}

BENGALI_CONDITIONS = {
    "Clear": "রৌদ্রোজ্জ্বল",
    "Clouds": "মেঘলা আকাশ",
    "Rain": "বৃষ্টি",
    "Drizzle": "ঝিরিঝিরি বৃষ্টি",
    "Thunderstorm": "বজ্রঝড় ও বৃষ্টি",
    "Mist": "কুয়াশা",
    "Fog": "ঘন কুয়াশা",
    "Haze": "কুয়াশাচ্ছন্ন",
    "Snow": "তুষারপাত"
}

def translate_day_name(dt_timestamp: int) -> str:
    """Converts unix timestamp to Bengali day name."""
    day_en = datetime.fromtimestamp(dt_timestamp, tz=timezone.utc).strftime("%A")
    return BENGALI_DAYS.get(day_en, day_en)

def get_bengali_condition(main_cond: str) -> str:
    """Translates standard weather group to Bengali."""
    return BENGALI_CONDITIONS.get(main_cond, "আংশিক মেঘলা")


def generate_mock_weather(lat: float, lon: float) -> Dict[str, Any]:
    """Generates highly realistic mock weather forecast in Bengali for Bangladesh delta coordinates."""
    logger.info("🌤️ Generating mock weather forecast...")
    
    # Establish realistic baseline based on Bangladesh's hot climate
    now = datetime.now(timezone.utc)
    
    # Current condition baseline
    current_temp = 32.5
    humidity = 78
    wind_speed = 4.2
    
    forecast_days = []
    has_heavy_rain = False

    # Generate 5 days of forecast (matches OpenWeather free tier)
    for i in range(5):
        day_date = now + timedelta(days=i)
        day_name = BENGALI_DAYS.get(day_date.strftime("%A"), day_date.strftime("%A"))
        
        # Periodic weather changes
        if i in [1, 2]: # High rain forecast days
            cond = "Rain"
            rain_prob = 85
            temp_max = 29.0
            temp_min = 24.5
            has_heavy_rain = True
        elif i == 3:
            cond = "Clouds"
            rain_prob = 40
            temp_max = 31.5
            temp_min = 25.0
        else:
            cond = "Clear"
            rain_prob = 10
            temp_max = 34.0
            temp_min = 26.5

        forecast_days.append({
            "day_name": day_name,
            "temp_max": round(temp_max, 1),
            "temp_min": round(temp_min, 1),
            "rain_probability": rain_prob,
            "condition_bn": get_bengali_condition(cond),
            "condition_icon": cond.lower()
        })

    # Agronomic rain advisory check (Spec Screen 8)
    advisory = "ফসলের অবস্থা ভালো আছে। স্বাভাবিক পরিচর্যা করুন।"
    if has_heavy_rain:
        advisory = "পরবর্তী ৩ দিন বৃষ্টির সম্ভাবনা বেশি — সার দেওয়া আপাতত পরিহার করুন।"

    return {
        "current": {
            "temp": round(current_temp, 1),
            "humidity": humidity,
            "wind_speed": round(wind_speed, 1),
            "condition_bn": "রৌদ্রোজ্জ্বল ও গরম",
            "condition_icon": "clear"
        },
        "forecast": forecast_days,
        "advisory_bn": advisory
    }


@router.get("/{lat}/{lon}", response_model=Dict[str, Any])
async def get_weather(
    lat: float,
    lon: float,
    current_farmer: Dict[str, Any] = Depends(get_current_farmer)
):
    """
    Fetches localized weather forecast and builds Bengali agricultural advisories.
    Spec Reference: Screen 8, Weather Screen
    """
    app_env = os.getenv("APP_ENV", "development")
    api_key = os.getenv("OPENWEATHER_API_KEY", "")
    
    if not api_key or api_key == "your_openweather_key_here":
        if app_env == "production":
            raise HTTPException(
                status_code=status.HTTP_503_SERVICE_UNAVAILABLE,
                detail="Weather service not configured"
            )
        logger.warning("OpenWeatherMap API Key missing. Falling back to Mock Weather.")
        return generate_mock_weather(lat, lon)

    # 5-day / 3-hour forecast URL (highly robust free tier API)
    url = f"https://api.openweathermap.org/data/2.5/forecast"
    params = {
        "lat": lat,
        "lon": lon,
        "appid": api_key,
        "units": "metric"  # Standard Celsius units
    }

    async with httpx.AsyncClient(timeout=15.0) as client:
        try:
            response = await client.get(url, params=params)
            
            if response.status_code != 200:
                logger.error(f"OpenWeatherMap returned status {response.status_code}.")
                if app_env == "production":
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Weather service temporarily unavailable"
                    )
                return generate_mock_weather(lat, lon)
                
            data = response.json()
            forecast_list = data.get("list", [])
            
            if not forecast_list:
                logger.error("Empty list returned from OpenWeatherMap.")
                if app_env == "production":
                    raise HTTPException(
                        status_code=status.HTTP_502_BAD_GATEWAY,
                        detail="Weather service temporarily unavailable"
                    )
                return generate_mock_weather(lat, lon)

            # 1. Parse current weather (first item in response)
            current_raw = forecast_list[0]
            current_main = current_raw.get("main", {})
            current_wind = current_raw.get("wind", {})
            current_weather = current_raw.get("weather", [{}])[0]
            
            current_weather_group = current_weather.get("main", "Clear")

            # 2. Parse 5-day forecast (OpenWeather lists in 3-hour blocks, so we aggregate per day)
            daily_aggregates = {}
            for block in forecast_list:
                dt = block.get("dt")
                date_str = datetime.fromtimestamp(dt, tz=timezone.utc).strftime("%Y-%m-%d")
                
                main_info = block.get("main", {})
                weather_info = block.get("weather", [{}])[0]
                
                temp = main_info.get("temp", 28.0)
                rain_prob = block.get("pop", 0.0) * 100.0 # pop = probability of precipitation (0.0 to 1.0)
                cond = weather_info.get("main", "Clear")
                
                if date_str not in daily_aggregates:
                    daily_aggregates[date_str] = {
                        "temps": [],
                        "rain_probs": [],
                        "conditions": [],
                        "timestamp": dt
                    }
                
                daily_aggregates[date_str]["temps"].append(temp)
                daily_aggregates[date_str]["rain_probs"].append(rain_prob)
                daily_aggregates[date_str]["conditions"].append(cond)

            # Build forecast days (Ascending order)
            forecast_days = []
            has_heavy_rain = False

            for date_str, agg in sorted(daily_aggregates.items())[:5]: # OpenWeather free is 5 days
                temps = agg["temps"]
                rain_probs = agg["rain_probs"]
                conditions = agg["conditions"]
                
                max_t = max(temps)
                min_t = min(temps)
                avg_rain_prob = max(rain_probs) # Use peak probability
                
                # Use most frequent condition
                most_frequent_cond = max(set(conditions), key=conditions.count)

                if avg_rain_prob > 70.0:
                    has_heavy_rain = True

                forecast_days.append({
                    "day_name": translate_day_name(agg["timestamp"]),
                    "temp_max": round(max_t, 1),
                    "temp_min": round(min_t, 1),
                    "rain_probability": round(avg_rain_prob),
                    "condition_bn": get_bengali_condition(most_frequent_cond),
                    "condition_icon": most_frequent_cond.lower()
                })

            # Agronomic rain advisory check (Spec Screen 8)
            advisory = "ফসলের অবস্থা ভালো আছে। স্বাভাবিক পরিচর্যা করুন।"
            if has_heavy_rain:
                advisory = "পরবর্তী ৩ দিন বৃষ্টির সম্ভাবনা বেশি — সার দেওয়া আপাতত পরিহার করুন।"

            return {
                "current": {
                    "temp": round(current_main.get("temp", 30.0), 1),
                    "humidity": current_main.get("humidity", 70),
                    "wind_speed": round(current_wind.get("speed", 3.5), 1),
                    "condition_bn": get_bengali_condition(current_weather_group),
                    "condition_icon": current_weather_group.lower()
                },
                "forecast": forecast_days,
                "advisory_bn": advisory
            }

        except Exception as e:
            logger.error(f"Weather API request exception: {str(e)}.")
            if app_env == "production":
                raise HTTPException(
                    status_code=status.HTTP_502_BAD_GATEWAY,
                    detail="Weather service temporarily unavailable"
                )
            logger.warning("Fallback to mock activated.")
            return generate_mock_weather(lat, lon)
