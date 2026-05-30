"""
Akashi — FastAPI Backend Application
====================================
Main entry point for the crop health satellite monitoring backend API.
Configures CORS, mounts all sub-routers, sets up logging, and orchestrates
the background async APScheduler satellite synchronization cron job.

Reference: Akashi MVP Spec v1.0, Section 5
"""

import os
import logging
from contextlib import asynccontextmanager
from fastapi import FastAPI, Depends, HTTPException, status, Header
from fastapi.middleware.cors import CORSMiddleware
from apscheduler.schedulers.asyncio import AsyncIOScheduler
from dotenv import load_dotenv

# Load env variables before routing imports
load_dotenv()

# Setup logging config
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s [%(levelname)s] %(name)s: %(message)s",
)
logger = logging.getLogger("akashi.main")

from app.api import farmers, fields, health, weather, gov
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
    # Runs every 5 days. We also use a jitter of 1 hour to prevent API stampedes
    # on Sentinel Hub servers.
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

# CORS configurations — allows frontend web dashboard to fetch dashboard data
app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],  # Restrict this to Vercel/localhost domains in production
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

@app.get("/")
async def root():
    """Root endpoint for basic health checks."""
    return {
        "app": "Akashi (আকাশি)",
        "status": "healthy",
        "api_version": "1.0.0",
        "scheduler_running": scheduler.running
    }

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
