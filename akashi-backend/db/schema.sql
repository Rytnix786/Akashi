-- ═══════════════════════════════════════════════════════════════════════════
-- Akashi Database Schema — PostgreSQL + PostGIS
-- Phase 2: Run this in Supabase SQL Editor
-- ═══════════════════════════════════════════════════════════════════════════
-- Reference: Akashi MVP Spec v1.0, Section 4 — Database Schema
-- 
-- Run order:
--   1. Enable PostGIS extension (first!)
--   2. Create tables in order (farmers → fields → health_readings → notifications → government_users)
--   3. Create indexes
-- ═══════════════════════════════════════════════════════════════════════════

-- ─── Enable PostGIS ──────────────────────────────────────────────────────────
-- Required for GEOMETRY columns (field polygons, center points)
CREATE EXTENSION IF NOT EXISTS postgis;

-- ─── Table: farmers ──────────────────────────────────────────────────────────
-- One row per registered farmer. Phone is the primary identifier (no email/password).
-- fcm_token is updated silently on every app open (Spec Section 9).
CREATE TABLE IF NOT EXISTS farmers (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  phone       VARCHAR(15) UNIQUE NOT NULL,   -- e.g. +8801712345678
  name        TEXT,                          -- Optional — farmers may skip
  district    TEXT NOT NULL,                 -- One of 64 Bangladesh districts
  upazila     TEXT NOT NULL,                 -- Sub-district
  fcm_token   TEXT,                          -- Firebase push token (nullable until app opens)
  created_at  TIMESTAMPTZ DEFAULT NOW(),
  updated_at  TIMESTAMPTZ DEFAULT NOW()
);

-- Auto-update updated_at on every row change
CREATE OR REPLACE FUNCTION update_updated_at_column()
RETURNS TRIGGER AS $$
BEGIN
  NEW.updated_at = NOW();
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER farmers_updated_at
  BEFORE UPDATE ON farmers
  FOR EACH ROW
  EXECUTE FUNCTION update_updated_at_column();

-- ─── Table: fields ────────────────────────────────────────────────────────────
-- Each farmer can register multiple fields. The polygon column stores the
-- exact boundary drawn by the farmer on the map screen (Screen 6).
-- PostGIS GIST index enables efficient spatial queries.
CREATE TABLE IF NOT EXISTS fields (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id     UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
  name          TEXT DEFAULT 'আমার জমি',      -- 'My Land' in Bengali
  crop_type     TEXT NOT NULL,                -- ধান | গম | পাট | সবজি | অন্যান্য
  crop_season   TEXT,                         -- Boro | Aman | Aus | Rabi
  area_acres    DECIMAL(8,3),                 -- Calculated from polygon
  area_bigha    DECIMAL(8,3),                 -- 1 bigha = 0.33 acres in Bangladesh
  polygon       GEOMETRY(POLYGON, 4326),      -- WGS84 coordinates, drawn by farmer
  center_point  GEOMETRY(POINT, 4326),        -- Centroid — for quick spatial queries
  district      TEXT NOT NULL,                -- Denormalized from farmer for gov queries
  upazila       TEXT NOT NULL,
  is_active     BOOLEAN DEFAULT TRUE,
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Indexes for common query patterns
CREATE INDEX IF NOT EXISTS idx_fields_farmer     ON fields(farmer_id);
CREATE INDEX IF NOT EXISTS idx_fields_district   ON fields(district);
CREATE INDEX IF NOT EXISTS idx_fields_active     ON fields(is_active) WHERE is_active = TRUE;
CREATE INDEX IF NOT EXISTS idx_fields_polygon    ON fields USING GIST(polygon);
CREATE INDEX IF NOT EXISTS idx_fields_center     ON fields USING GIST(center_point);

-- ─── Table: health_readings ──────────────────────────────────────────────────
-- One row per NDVI reading per field. The cron job writes here every 5 days.
-- raw_response stores the full Sentinel Hub API response for debugging.
CREATE TABLE IF NOT EXISTS health_readings (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  field_id      UUID NOT NULL REFERENCES fields(id) ON DELETE CASCADE,
  reading_date  DATE NOT NULL DEFAULT CURRENT_DATE,
  ndvi_mean     DECIMAL(5,4),                 -- e.g. 0.6234
  ndwi_mean     DECIMAL(5,4),                 -- Water stress index (Phase 2 addition)
  cloud_cover   DECIMAL(5,2),                 -- % cloud cover (0-100)
  health_status TEXT CHECK (health_status IN ('green','yellow','red','unknown')),
  pixel_count   INTEGER,                      -- Valid (non-cloud) pixels analyzed
  data_source   TEXT DEFAULT 'sentinel-2',    -- sentinel-2 | sentinel-1
  raw_response  JSONB,                        -- Full Sentinel Hub response
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_readings_field   ON health_readings(field_id);
CREATE INDEX IF NOT EXISTS idx_readings_date    ON health_readings(reading_date DESC);
-- Composite index for the most common query: latest reading per field
CREATE INDEX IF NOT EXISTS idx_readings_field_date ON health_readings(field_id, reading_date DESC);

-- ─── Table: notifications ────────────────────────────────────────────────────
-- Push notifications sent to farmers. Only sent when health degrades.
-- All text is in Bengali — no LLM, pre-written strings from the rule table.
CREATE TABLE IF NOT EXISTS notifications (
  id          UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  farmer_id   UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
  field_id    UUID REFERENCES fields(id) ON DELETE SET NULL,
  type        TEXT CHECK (type IN ('health_alert', 'weather', 'seasonal')),
  title_bn    TEXT NOT NULL,                  -- Bengali notification title
  body_bn     TEXT NOT NULL,                  -- Bengali notification body
  sent_at     TIMESTAMPTZ,
  delivered   BOOLEAN DEFAULT FALSE,
  created_at  TIMESTAMPTZ DEFAULT NOW()
);

CREATE INDEX IF NOT EXISTS idx_notifications_farmer   ON notifications(farmer_id);
CREATE INDEX IF NOT EXISTS idx_notifications_sent_at  ON notifications(sent_at DESC);

-- ─── Table: government_users ─────────────────────────────────────────────────
-- Agricultural officers with access to the Next.js dashboard.
-- district = NULL means national-level access (all districts).
CREATE TABLE IF NOT EXISTS government_users (
  id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
  email         TEXT UNIQUE NOT NULL,
  name          TEXT,
  role          TEXT DEFAULT 'district_officer',
  district      TEXT,                           -- NULL = national access
  password_hash TEXT,                           -- Bcrypt password hash
  created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- ─── Useful Views ─────────────────────────────────────────────────────────────
-- Latest health reading per field (for home screen and gov dashboard)
CREATE OR REPLACE VIEW field_latest_health AS
SELECT DISTINCT ON (hr.field_id)
  hr.field_id,
  hr.reading_date,
  hr.ndvi_mean,
  hr.cloud_cover,
  hr.health_status,
  hr.pixel_count,
  hr.created_at AS reading_created_at,
  f.name AS field_name,
  f.crop_type,
  f.district,
  f.upazila,
  f.farmer_id,
  f.area_acres,
  f.area_bigha
FROM health_readings hr
JOIN fields f ON f.id = hr.field_id
WHERE f.is_active = TRUE
ORDER BY hr.field_id, hr.reading_date DESC;

-- District health summary (for government dashboard)
CREATE OR REPLACE VIEW district_health_summary AS
SELECT
  f.district,
  COUNT(DISTINCT f.farmer_id) AS farmer_count,
  COUNT(DISTINCT f.id)        AS field_count,
  COUNT(CASE WHEN flh.health_status = 'green'   THEN 1 END) AS green_fields,
  COUNT(CASE WHEN flh.health_status = 'yellow'  THEN 1 END) AS yellow_fields,
  COUNT(CASE WHEN flh.health_status = 'red'     THEN 1 END) AS red_fields,
  ROUND(AVG(flh.ndvi_mean)::numeric, 4) AS avg_ndvi,
  MAX(flh.reading_date) AS last_updated
FROM fields f
LEFT JOIN field_latest_health flh ON flh.field_id = f.id
WHERE f.is_active = TRUE
GROUP BY f.district
ORDER BY f.district;

-- ─── Sample Data (for development testing) ───────────────────────────────────
-- Remove this block before production deployment
-- INSERT INTO farmers (phone, name, district, upazila) VALUES
--   ('+8801712345678', 'আব্দুল করিম', 'Tangail', 'Basail'),
--   ('+8801987654321', 'রহিমা বেগম', 'Mymensingh', 'Trishal');
