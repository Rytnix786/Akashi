"""
Akashi — Firebase Cloud Messaging (FCM) Notification Service
============================================================
Handles sending localized, rule-based Bengali push notifications to farmers.

Includes an auto-detecting MOCK FALLBACK when the Firebase Service Account JSON
is missing, printing notifications directly to the server logs and updating the DB,
ensuring zero development blockages.

Features:
  - Strict compliance with Bangladesh timezone (GMT+6) quiet hours (6:00 AM - 9:00 PM only)
  - Pre-written standard Bengali notification copy (no LLM translation)
  - Graceful mock console fallback when SDK credentials are not present

Reference: Akashi MVP Spec v1.0, Section 9
"""

import os
import logging
from datetime import datetime, time, timezone, timedelta
from typing import Optional
from pathlib import Path

logger = logging.getLogger("akashi.notifications")

# Global flag to track FCM Admin SDK status
FCM_READY = False

import sys
import base64
import json

IS_TESTING = "pytest" in sys.modules or any("pytest" in arg for arg in sys.argv)

try:
    import firebase_admin
    from firebase_admin import credentials, messaging
    
    cred_b64 = os.getenv("FIREBASE_CREDENTIALS_B64")
    cred_path = os.getenv("GOOGLE_APPLICATION_CREDENTIALS", "./firebase-service-account.json")
    
    if cred_b64:
        cred_json = json.loads(base64.b64decode(cred_b64).decode("utf-8"))
        cred = credentials.Certificate(cred_json)
        firebase_admin.initialize_app(cred)
        FCM_READY = True
        logger.info("🔥 Firebase Admin SDK initialized successfully from B64 env var.")
    elif Path(cred_path).exists():
        cred = credentials.Certificate(cred_path)
        firebase_admin.initialize_app(cred)
        FCM_READY = True
        logger.info("🔥 Firebase Admin SDK initialized successfully from credentials file.")
    elif os.getenv("APP_ENV") == "production":
        raise RuntimeError("Firebase credentials required in production")
    else:
        logger.warning(
            "⚠️ Firebase credentials not found.\n"
            "   Operating in MOCK/CONSOLE NOTIFICATION MODE. Notifications will be printed to stdout."
        )
except Exception as e:
    if os.getenv("APP_ENV") == "production":
        raise RuntimeError(f"Failed to initialize Firebase Admin SDK: {str(e)}") from e
    logger.error(f"❌ Failed to initialize Firebase Admin SDK: {str(e)}")
    logger.warning("   Operating in MOCK/CONSOLE NOTIFICATION MODE.")


class NotificationService:
    """Service to handle notification checks, frequency capping, and deliveries."""

    @staticmethod
    def is_quiet_hours() -> bool:
        """
        Quiet hours compliance: No notifications between 9:00 PM and 6:00 AM Bangladesh Time (GMT+6).
        Spec Reference: Section 9
        """
        # Bangladesh time is UTC + 6
        bd_time = datetime.now(timezone.utc) + timedelta(hours=6)
        current_hour = bd_time.hour
        
        # Quiet hours: before 6:00 AM or after 9:00 PM (21:00)
        return current_hour < 6 or current_hour >= 21

    async def send_push_notification(
        self,
        farmer_id: str,
        fcm_token: Optional[str],
        title: str,
        body: str,
        field_id: Optional[str] = None,
        notification_type: str = "health_alert"
    ) -> bool:
        """
        Sends push notification via FCM Admin SDK. Falls back to console output if SDK not ready.
        Enforces Bangladesh time quiet hours (delays or suppresses).
        """
        # 1. Enforce quiet hours
        if self.is_quiet_hours():
            logger.warning(f"🔇 Suppression: Quiet hours active in Bangladesh (9pm-6am). Skipping notification for farmer {farmer_id}.")
            return False

        # 2. Log database entry (always done so farmer gets list in-app)
        from app.db.connection import db
        try:
            await db.insert("notifications", {
                "farmer_id": farmer_id,
                "field_id": field_id,
                "type": notification_type,
                "title_bn": title,
                "body_bn": body,
                "sent_at": datetime.now(timezone.utc).isoformat(),
                "delivered": True if (fcm_token and FCM_READY) else False
            })
            logger.info(f"💾 Logged notification in database for farmer {farmer_id}")
        except Exception as e:
            logger.error(f"Failed to log notification in DB: {str(e)}")

        # 3. Handle physical FCM delivery
        if not fcm_token:
            logger.warning(f"⚠️ Farmer {farmer_id} has no registered FCM token. Notification logged but not delivered.")
            return False

        if not FCM_READY:
            # Console Mock Mode
            print("\n" + "🔔" * 30)
            print("   AKASHI PUSH NOTIFICATION (MOCK CONSOLE DELIVERY)")
            print("🔔" * 30)
            print(f"   To Farmer ID : {farmer_id}")
            print(f"   FCM Token    : {fcm_token[:30]}...")
            print(f"   Field ID     : {field_id}")
            print(f"   Type         : {notification_type}")
            print(f"   Title (BN)   : {title}")
            print(f"   Body (BN)    : {body}")
            print("🔔" * 30 + "\n")
            return True

        # Send via Real Firebase Messaging SDK
        try:
            message = messaging.Message(
                notification=messaging.Notification(
                    title=title,
                    body=body,
                ),
                data={
                    "field_id": field_id or "",
                    "click_action": "FLUTTER_NOTIFICATION_CLICK"
                },
                token=fcm_token,
            )
            response = messaging.send(message)
            logger.info(f"🚀 FCM push sent successfully. Response: {response}")
            return True
        except Exception as e:
            logger.error(f"FCM delivery exception for token {fcm_token[:15]}...: {str(e)}")
            return False

    async def check_and_notify_health_degradation(
        self,
        farmer_id: str,
        fcm_token: Optional[str],
        field_id: str,
        field_name: str,
        old_status: str,
        new_status: str
    ) -> bool:
        """
        Checks health transition and triggers appropriate notification based on spec.
        Spec Reference: Section 9
        """
        # Trigger copies
        title_alert = "ফসলের স্বাস্থ্য সতর্কতা"
        title_urgent = "জরুরি ফসল সতর্কতা"
        
        # 1. Green -> Yellow
        if old_status == "green" and new_status == "yellow":
            body = f"সতর্কতা: আপনার '{field_name}' জমির ফসলে মনোযোগ প্রয়োজন। স্বাস্থ্য কিছুটা দুর্বল।"
            return await self.send_push_notification(
                farmer_id=farmer_id,
                fcm_token=fcm_token,
                title=title_alert,
                body=body,
                field_id=field_id,
                notification_type="health_alert"
            )

        # 2. Yellow -> Red OR Green -> Red
        elif new_status == "red":
            body = f"জরুরি: আপনার '{field_name}' জমির ফসলে গুরুতর সমস্যা দেখা দিয়েছে। এখনই বিস্তারিত দেখুন এবং যত্ন নিন।"
            return await self.send_push_notification(
                farmer_id=farmer_id,
                fcm_token=fcm_token,
                title=title_urgent,
                body=body,
                field_id=field_id,
                notification_type="health_alert"
            )
            
        return False

# Singleton instance
notification_service = NotificationService()
