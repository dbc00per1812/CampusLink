-- STEP 3: Enable Vector Search (PRODUCTION SAFE)
-- Risk: MEDIUM - Adds column (brief table lock ~10-30 seconds)
-- Rollback: Easy - see bottom of file
-- Estimated time: 10 seconds (column) + 1-5 minutes (index)
-- Impact: Brief write lock during ALTER TABLE

-- Check if already exists
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'embedding'
    ) THEN
        RAISE NOTICE '⚠️  WARNING: embedding column already exists, skipping...';
    ELSE
        RAISE NOTICE '✅ Proceeding with migration...';
    END IF;
END $$;

-- Enable the pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Verify extension was created
DO $$
BEGIN
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        RAISE NOTICE '✅ pgvector extension enabled';
    ELSE
        RAISE EXCEPTION '❌ Failed to enable pgvector extension';
    END IF;
END $$;

-- Add embedding column (THIS WILL BRIEFLY LOCK THE TABLE)
-- Plan this for low-traffic time if possible
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS embedding vector(384);

-- Verify column was added
DO $$
BEGIN
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'embedding'
    ) THEN
        RAISE NOTICE '✅ embedding column added successfully';
    ELSE
        RAISE EXCEPTION '❌ Failed to add embedding column';
    END IF;
END $$;

-- Create index for fast similarity search
-- Note: Removed CONCURRENTLY because Supabase SQL Editor runs in transaction mode
-- This will take 1-5 minutes and may briefly lock, but completes successfully
CREATE INDEX IF NOT EXISTS idx_listings_embedding 
ON listings USING hnsw (embedding vector_cosine_ops)
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Add GIN index on tsv if not exists (for full-text search)
CREATE INDEX IF NOT EXISTS idx_listings_tsv 
ON listings USING gin(tsv);

-- Verify indexes
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'listings'
AND indexname IN ('idx_listings_embedding', 'idx_listings_tsv');

-- Check table structure
SELECT 
    column_name,
    data_type,
    is_nullable
FROM information_schema.columns
WHERE table_name = 'listings' 
AND column_name IN ('embedding', 'tsv')
ORDER BY column_name;

-- Count listings (for reference)
SELECT 
    COUNT(*) as total_active_listings,
    COUNT(embedding) as with_embeddings,
    COUNT(*) - COUNT(embedding) as missing_embeddings
FROM listings
WHERE status = 'active' AND archived = false;

-- SUCCESS MESSAGE
DO $$
BEGIN
    RAISE NOTICE '✅ Step 3 Complete: Vector search infrastructure ready';
    RAISE NOTICE 'embedding column added, indexes created';
    RAISE NOTICE 'Next Step: Run create_embedding_function_safe.sql';
END $$;

-- ROLLBACK INSTRUCTIONS (if needed):
/*
-- WARNING: This will remove the embedding column and all embeddings
-- Only run if you need to completely undo this step

ALTER TABLE listings DROP COLUMN IF EXISTS embedding;
DROP INDEX IF EXISTS idx_listings_embedding;
DROP INDEX IF EXISTS idx_listings_tsv; -- only if you want to remove it
DROP EXTENSION IF EXISTS vector;

-- Verify rollback
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'listings' AND column_name = 'embedding';
-- Should return 0 rows
*/

