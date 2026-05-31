"""
Akashi — Centralized Security & Compliance Audit Logger
======================================================
Implements async database insertions of administrative trails (logins, fields creation,
satellite sync overrides, and DAE regional dashboard queries).

Reference: Phase 2 Security Audit / Session E
"""

import logging
from typing import Dict, Any, Optional
from app.db.connection import db

logger = logging.getLogger("akashi.audit")

async def log_audit_action(
    actor_id: str,
    actor_role: str,
    action: str,
    district: Optional[str] = None,
    payload: Optional[Dict[str, Any]] = None
) -> None:
    """
    Inserts a security audit trail record asynchronously into the Supabase PostgreSQL database.
    Ensures that failures in logging do not crash the primary API transaction.
    """
    try:
        await db.insert("audit_logs", {
            "actor_id": actor_id,
            "actor_role": actor_role,
            "action": action,
            "district": district,
            "payload": payload or {}
        })
        logger.info(f"🔑 [AUDIT] {actor_role.upper()} ({actor_id}) executed '{action}' successfully.")
    except Exception as e:
        logger.error(f"Failed to record administrative audit log to database: {str(e)}")
