-- Migration: Chatbot Rate Limiting and Logging Schema
-- Reference: Akashi MVP Spec Section 5.3 & RAG Chatbot Phase 2
-- Alters farmers table to support daily rate limits and resets, and creates
-- chat_logs database table to log farmer interactions and source citations.

-- Alter farmers table to track dynamic chat quotas
ALTER TABLE farmers ADD COLUMN IF NOT EXISTS daily_chat_count INTEGER DEFAULT 0;
ALTER TABLE farmers ADD COLUMN IF NOT EXISTS chat_count_reset_date DATE DEFAULT CURRENT_DATE;

-- Create chat_logs table to store farmer conversational history
CREATE TABLE IF NOT EXISTS chat_logs (
    id                UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    farmer_id         UUID NOT NULL REFERENCES farmers(id) ON DELETE CASCADE,
    query             TEXT NOT NULL,
    response          TEXT NOT NULL,
    source_citations  JSONB, -- List of source files and similarity scores
    created_at        TIMESTAMPTZ DEFAULT NOW()
);

-- Index for quick farmer chat logs lookup
CREATE INDEX IF NOT EXISTS idx_chat_logs_farmer ON chat_logs(farmer_id);
CREATE INDEX IF NOT EXISTS idx_chat_logs_created_at ON chat_logs(created_at DESC);
