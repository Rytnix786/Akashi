-- Migration: Add SAR Columns to health_readings table
-- Adds a data_source column to identify if crop health is from Sentinel-2 optical or Sentinel-1 SAR.

ALTER TABLE health_readings ADD COLUMN IF NOT EXISTS data_source TEXT DEFAULT 'sentinel-2';
