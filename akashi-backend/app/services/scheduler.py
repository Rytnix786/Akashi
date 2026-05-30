"""
Akashi — APScheduler Cron Service
=================================
Handles periodic satellite NDVI synchronization every 5 days for all registered fields.

Features:
  - Batching (processes 50 fields at a time)
  - Error isolation (individual field failure does not disrupt the sync run)
  - Real-time comparison to trigger push notifications on health degradation
  - Manual sync trigger endpoint capability

Reference: Akashi MVP Spec v1.0, Section 5.3 & 11 (Phase 4)
"""

import asyncio
import logging
from datetime import datetime, timezone
from typing import Dict, Any, List
from app.db.connection import db
from app.services.sentinel import sentinel_service
from app.services.notifications import notification_service

logger = logging.getLogger("akashi.scheduler")

class CronSchedulerService:
    """Service to orchestrate background NDVI data pulls and health updates."""

    async def sync_single_field(self, field: Dict[str, Any]) -> bool:
        """
        Syncs a single field with Sentinel Hub, updates DB, and checks for degradation.
        Returns True if successful, False otherwise.
        """
        field_id = field["id"]
        farmer_id = field["farmer_id"]
        field_name = field.get("name", "আমার জমি")
        crop_type = field["crop_type"]
        polygon = field["polygon"]
        
        logger.info(f"Syncing field {field_id} (Farmer: {farmer_id}, Crop: {crop_type})...")

        try:
            # 1. Fetch latest reading from Sentinel Hub (or mock fallback)
            reading = await sentinel_service.get_field_ndvi(
                polygon=polygon,
                crop_type=crop_type,
                field_id_str=field_id
            )

            # 2. Get current latest reading status in DB for comparison
            latest_db_reading = await db.select(
                table="health_readings",
                select_fields="health_status",
                filters={"field_id": f"eq.{field_id}"},
                order_by="reading_date.desc",
                limit=1
            )
            
            old_status = "green"  # Default if no previous readings exist
            if latest_db_reading:
                old_status = latest_db_reading[0].get("health_status", "green")

            # 3. Write new reading to DB
            new_status = reading["health_status"]
            
            await db.insert("health_readings", {
                "field_id": field_id,
                "reading_date": datetime.now(timezone.utc).date().isoformat(),
                "ndvi_mean": reading["ndvi_mean"],
                "ndwi_mean": reading["ndwi_mean"],
                "cloud_cover": reading["cloud_cover"],
                "health_status": new_status,
                "pixel_count": reading["pixel_count"],
                "raw_response": reading["raw_response"]
            })
            logger.info(f"Saved reading for field {field_id}. Status: {new_status}")

            # 4. Check for degradation and trigger push notification
            if new_status != old_status:
                logger.info(f"Health transition detected for field {field_id}: {old_status} -> {new_status}")
                # Fetch farmer's FCM token
                farmer_data = await db.select(
                    table="farmers",
                    select_fields="fcm_token",
                    filters={"id": f"eq.{farmer_id}"},
                    limit=1
                )
                
                if farmer_data:
                    fcm_token = farmer_data[0].get("fcm_token")
                    await notification_service.check_and_notify_health_degradation(
                        farmer_id=farmer_id,
                        fcm_token=fcm_token,
                        field_id=field_id,
                        field_name=field_name,
                        old_status=old_status,
                        new_status=new_status
                    )

            return True

        except Exception as e:
            logger.error(f"Error syncing field {field_id}: {str(e)}")
            return False

    async def run_ndvi_for_all_fields(self, batch_size: int = 50) -> Dict[str, Any]:
        """
        Runs full NDVI sync for all active fields in the database.
        Processes fields in isolated batches of `batch_size`.
        """
        logger.info("📅 Starting background NDVI sync job for all active fields...")
        start_time = datetime.now(timezone.utc)
        
        try:
            # Query all active fields from DB
            active_fields = await db.select(
                table="fields",
                select_fields="id, farmer_id, name, crop_type, polygon",
                filters={"is_active": "eq.true"}
            )
        except Exception as e:
            logger.error(f"Failed to fetch active fields from Supabase: {str(e)}")
            return {"status": "failed", "error": str(e)}

        total_fields = len(active_fields)
        logger.info(f"Found {total_fields} active fields to process.")

        if total_fields == 0:
            return {
                "status": "success",
                "processed": 0,
                "success_count": 0,
                "duration_seconds": 0
            }

        success_count = 0
        failed_count = 0

        # Process in batches of 50
        for i in range(0, total_fields, batch_size):
            batch = active_fields[i:i + batch_size]
            logger.info(f"Processing batch {i//batch_size + 1} ({len(batch)} fields)...")
            
            # Run batch concurrently using asyncio.gather
            tasks = [self.sync_single_field(field) for field in batch]
            results = await asyncio.gather(*tasks)
            
            for res in results:
                if res:
                    success_count += 1
                else:
                    failed_count += 1

        duration = (datetime.now(timezone.utc) - start_time).total_seconds()
        logger.info(
            f"Finished sync run. Processed: {total_fields}, "
            f"Success: {success_count}, Failed: {failed_count}, Duration: {duration:.2f}s"
        )
        
        return {
            "status": "success",
            "processed": total_fields,
            "success_count": success_count,
            "failed_count": failed_count,
            "duration_seconds": round(duration, 2)
        }

# Singleton instance
cron_scheduler_service = CronSchedulerService()
