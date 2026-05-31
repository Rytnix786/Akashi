"""
Akashi — FastAPI Backend Application
====================================
Main entry point for the crop health satellite monitoring backend API.
Configures CORS, mounts all sub-routers, sets up logging, and orchestrates
the background async APScheduler satellite synchronization cron job.

Reference: Akashi MVP Spec v1.0, Section 5
"""

import os
import time
import json
import logging
import datetime
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, status, Header, Request
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from dotenv import load_dotenv
import sentry_sdk
from sentry_sdk.integrations.fastapi import FastApiIntegration
from starlette.middleware.base import BaseHTTPMiddleware

# Load env variables before routing imports
load_dotenv()

# Setup logging config
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("akashi.main")

# Sentry SDK Error Tracking Integration (Session J)
sentry_dsn = os.getenv("SENTRY_DSN")
if sentry_dsn:
    sentry_sdk.init(
        dsn=sentry_dsn,
        integrations=[FastApiIntegration()],
        traces_sample_rate=1.0,
        profiles_sample_rate=1.0,
    )
    logger.info("🎯 Sentry SDK initialized for production error monitoring.")

from app.api import farmers, fields, health, weather, gov, chat
from app.services.scheduler import cron_scheduler_service

# Initialize background task scheduler
scheduler = AsyncIOScheduler()

@asynccontextmanager
async def lifespan(app: FastAPI):
    """
    Handles API lifecycle events: startup and shutdown.
    Orchestrates the periodic 5-day background NDVI sync cron job.
    """
    logger.info("🚀 Starting Akashi FastAPI Application...")
    
    # Register periodic satellite NDVI cron job (Spec Phase 4 / Section 11)
    scheduler.add_job(
        func=cron_scheduler_service.run_ndvi_for_all_fields,
        trigger="interval",
        days=5,
        id="satellite_ndvi_sync",
        name="Satellite 5-day NDVI Synchronization",
        replace_existing=True,
        coalesce=True
    )
    
    logger.info("📅 Background satellite sync scheduler configured (Runs every 5 days).")
    scheduler.start()
    
    yield
    
    logger.info("🛑 Shutting down background task scheduler...")
    scheduler.shutdown()
    logger.info("👋 Akashi FastAPI Application stopped successfully.")


# Initialize FastAPI app
app = FastAPI(
    title="আকাশি (Akashi) Crop Intelligence API",
    description="Satellite crop health alerting and weather advisory system for Bangladeshi farmers.",
    version="1.0.0",
    lifespan=lifespan
)

# Structured JSON Transaction Logging Middleware (Session J)
class StructuredLoggingMiddleware(BaseHTTPMiddleware):
    async def dispatch(self, request: Request, call_next):
        start_time = time.time()
        try:
            response = await call_next(request)
            process_time = (time.time() - start_time) * 1000
            
            log_payload = {
                "timestamp": datetime.datetime.now(datetime.UTC).isoformat(),
                "event": "http_request",
                "method": request.method,
                "path": request.url.path,
                "status_code": response.status_code,
                "duration_ms": round(process_time, 2),
                "client_ip": request.client.host if request.client else "unknown"
            }
            print(json.dumps(log_payload))
            return response
        except Exception as e:
            process_time = (time.time() - start_time) * 1000
            log_payload = {
                "timestamp": datetime.datetime.now(datetime.UTC).isoformat(),
                "event": "http_error",
                "method": request.method,
                "path": request.url.path,
                "error": str(e),
                "duration_ms": round(process_time, 2),
                "client_ip": request.client.host if request.client else "unknown"
            }
            print(json.dumps(log_payload))
            raise e

app.add_middleware(StructuredLoggingMiddleware)

# CORS configurations — allows frontend web dashboard to fetch dashboard data
allowed_origins = [
    "http://localhost:3000",
    "http://127.0.0.1:3000",
    "http://localhost:5173",  # Vite default
    "http://127.0.0.1:5173",
]
env_origins = os.getenv("ALLOWED_ORIGINS", "")
if env_origins:
    allowed_origins.extend([o.strip() for o in env_origins.split(",") if o.strip()])

app.add_middleware(
    CORSMiddleware,
    allow_origins=allowed_origins,
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# ─── Mount Routes ─────────────────────────────────────────────────────────────
app.include_router(farmers.router)      # /auth
app.include_router(farmers.farmer_router) # /farmers
app.include_router(fields.router)       # /fields
app.include_router(health.router)       # /fields (health summaries & timelines)
app.include_router(weather.router)     # /weather
app.include_router(gov.router)         # /gov (analytics dashboards & reports)
app.include_router(chat.router)        # /chat (agronomic conversational chatbot)

@app.get("/")
async def root():
    """Root endpoint for basic health checks."""
    return {
        "app": "Akashi (আকাশি)",
        "status": "healthy",
        "api_version": "1.0.0",
        "scheduler_running": scheduler.running
    }

@app.get("/health", tags=["System Observability"])
async def get_system_health():
    """
    Highly robust production health check endpoint.
    Performs live database connectivity validation and calculates operational metrics
    including registered farmer count and total monitored acreage dynamically.
    """
    from app.db.connection import db
    try:
        # 1. Validate database connection & count farmers
        farmers_res = await db.select(
            table="farmers",
            select_fields="id",
            limit=10000
        )
        total_farmers = len(farmers_res) if farmers_res else 0
        
        # 2. Retrieve fields to calculate total monitored acreage
        fields_res = await db.select(
            table="fields",
            select_fields="area_acres",
            limit=10000
        )
        total_acreage = sum(float(f["area_acres"]) for f in fields_res if f.get("area_acres") is not None) if fields_res else 0.0

        return {
            "status": "healthy",
            "database": "connected",
            "metrics": {
                "total_farmers": total_farmers,
                "monitored_acreage_acres": round(total_acreage, 2),
                "scheduler_running": scheduler.running
            }
        }
    except Exception as e:
        logger.error(f"❌ Observability health check failed: {str(e)}")
        raise HTTPException(
            status_code=status.HTTP_500_INTERNAL_SERVER_ERROR,
            detail={
                "status": "unhealthy",
                "database": "disconnected",
                "error": str(e)
            }
        )

# ─── Internal API for developer testing ───────────────────────────────────────

# Simple security check for internal API trigger using a header key
INTERNAL_API_KEY = os.getenv("API_SECRET_KEY", "change_this_to_a_random_secret_in_production")

@app.post("/internal/run-ndvi", tags=["Internal Testing"])
async def trigger_manual_ndvi_run(x_api_key: str = Header(..., description="API Secret key for auth")):
    """
    Admin endpoint allowing developers to manually trigger the full NDVI satellite sync run.
    Bypasses the 5-day wait interval for easy manual validation!
    """
    if x_api_key != INTERNAL_API_KEY:
        raise HTTPException(
            status_code=status.HTTP_401_UNAUTHORIZED,
            detail="Unauthorized trigger request. Invalid API secret key."
        )
        
    logger.info("⚡ Manual NDVI synchronization triggered via admin endpoint...")
    
    # Run the background sync in an asyncio task to prevent HTTP timeout
    import asyncio
    asyncio.create_task(cron_scheduler_service.run_ndvi_for_all_fields())
    
    return {
        "status": "triggered",
        "message": "NDVI satellite synchronization task launched in the background."
    }
