-- Migration: Create Audit Logs Table
-- Reference: Phase 2 Security Audit / Session E
-- Creates the audit_logs table to track government officer and farmer administrative actions.

CREATE TABLE IF NOT EXISTS audit_logs (
    id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    actor_id    TEXT NOT NULL,          -- Farmer UUID, Gov Email, or System Cron
    actor_role  TEXT NOT NULL,          -- farmer | district_officer | national_officer | system
    action      TEXT NOT NULL,          -- login | field_created | dashboard_access | export | ndvi_sync
    district    TEXT,                   -- Scoped district for reporting queries
    payload     JSONB,                  -- Additional metadata (e.g. coordinates, browser specs)
    timestamp   TIMESTAMPTZ DEFAULT NOW()
);

-- Index for high-fidelity audit trails
CREATE INDEX IF NOT EXISTS idx_audit_logs_actor ON audit_logs(actor_id);
CREATE INDEX IF NOT EXISTS idx_audit_logs_action ON audit_logs(action);
CREATE INDEX IF NOT EXISTS idx_audit_logs_timestamp ON audit_logs(timestamp DESC);
