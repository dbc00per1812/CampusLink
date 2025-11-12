-- Enable Vector Search for Semantic Recommendations
-- This enables pgvector extension and adds embedding column to listings table
-- Run this in Supabase SQL Editor
-- 
-- IMPORTANT: This will add a new column to the listings table
-- Expected downtime: ~1 minute (depending on number of listings)

-- Step 1: Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Step 2: Add embedding column to listings table
-- Using vector(384) for Supabase's gte-small model (384 dimensions)
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS embedding vector(384);

-- Step 3: Create index for fast similarity search using HNSW algorithm
-- HNSW (Hierarchical Navigable Small World) is optimized for vector similarity search
-- This index only includes active, non-archived, non-sold listings to save space
CREATE INDEX IF NOT EXISTS idx_listings_embedding 
ON listings USING hnsw (embedding vector_cosine_ops)
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Step 4: Add a GIN index on the existing tsv column if not exists
-- This improves full-text search performance
CREATE INDEX IF NOT EXISTS idx_listings_tsv 
ON listings USING gin(tsv);

-- Verify the extension was enabled
SELECT * FROM pg_extension WHERE extname = 'vector';

-- Verify the embedding column was added
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'listings' AND column_name = 'embedding';

-- Check existing indexes on listings table
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'listings'
ORDER BY indexname;

-- Count how many listings need embeddings generated
SELECT 
    COUNT(*) as total_active_listings,
    COUNT(embedding) as with_embeddings,
    COUNT(*) - COUNT(embedding) as missing_embeddings
FROM listings
WHERE status = 'active' AND archived = false;

-- Show storage info
SELECT 
    pg_size_pretty(pg_total_relation_size('listings')) as total_size,
    pg_size_pretty(pg_relation_size('listings')) as table_size,
    pg_size_pretty(pg_total_relation_size('listings') - pg_relation_size('listings')) as indexes_size;

