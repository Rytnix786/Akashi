-- Migration: Add Farmer Privacy Consent Columns
-- Reference: Phase 2 Security Audit / Session F
-- Adds consent_given and consent_timestamp fields to the farmers table.

ALTER TABLE farmers ADD COLUMN IF NOT EXISTS consent_given BOOLEAN DEFAULT FALSE;
ALTER TABLE farmers ADD COLUMN IF NOT EXISTS consent_timestamp TIMESTAMPTZ;
