-- Migration: Enable pgvector and Create Knowledge Chunks Table
-- Reference: Akashi MVP Spec Section 4 / Phase 2
-- Enables pgvector extension, creates knowledge_chunks table (768 dimensions for text-embedding-004),
-- builds an HNSW index, and compiles the match_knowledge_chunks database matching function.

-- Enable pgvector extension (Supabase supports this natively)
CREATE EXTENSION IF NOT EXISTS vector;

-- Create table to store parsed PDF knowledge segments
CREATE TABLE IF NOT EXISTS knowledge_chunks (
    id            UUID PRIMARY KEY DEFAULT gen_random_uuid(),
    content       TEXT NOT NULL,
    source_file   TEXT NOT NULL,
    chunk_index   INTEGER NOT NULL,
    embedding     vector(768), -- Dimensions for Google text-embedding-004
    created_at    TIMESTAMPTZ DEFAULT NOW()
);

-- Index using HNSW for high-performance cosine similarity lookups
CREATE INDEX IF NOT EXISTS idx_knowledge_chunks_embedding_hnsw 
ON knowledge_chunks 
USING hnsw (embedding vector_cosine_ops);

-- Create standard Supabase Database RPC function for cosine similarity retrieval
-- PostgREST doesn't support vector calculations via direct REST, so we call this RPC
CREATE OR REPLACE FUNCTION match_knowledge_chunks (
  query_embedding vector(768),
  match_threshold float,
  match_count int
)
RETURNS TABLE (
  id UUID,
  content TEXT,
  source_file TEXT,
  chunk_index INT,
  similarity float
)
LANGUAGE plpgsql
AS $$
BEGIN
  RETURN QUERY
  SELECT
    kc.id,
    kc.content,
    kc.source_file,
    kc.chunk_index,
    (1 - (kc.embedding <=> query_embedding))::float AS similarity
  FROM knowledge_chunks kc
  WHERE (1 - (kc.embedding <=> query_embedding)) > match_threshold
  ORDER BY kc.embedding <=> query_embedding
  LIMIT match_count;
END;
$$;
