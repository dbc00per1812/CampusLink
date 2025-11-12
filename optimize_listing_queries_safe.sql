-- STEP 1: Add Performance Indexes (PRODUCTION SAFE)
-- Risk: LOW - Just adds indexes, no data changes
-- Rollback: Easy - just drop the indexes
-- Estimated time: 1-2 minutes
-- Impact: NONE - indexes are added concurrently

-- Add indexes for category-based diversification
-- Note: Removed CONCURRENTLY because Supabase SQL Editor runs in transaction mode
-- These will briefly lock but complete quickly (1-2 minutes max)
CREATE INDEX IF NOT EXISTS idx_listings_category_created 
ON listings(category, created_at DESC) 
WHERE status = 'active' AND archived = false AND is_sold = false;

CREATE INDEX IF NOT EXISTS idx_listings_type_category 
ON listings(listing_type, category, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

CREATE INDEX IF NOT EXISTS idx_listings_intent_created
ON listings(intent, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

CREATE INDEX IF NOT EXISTS idx_listings_campus_category
ON listings(user_id, category, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Verify indexes were created
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'listings'
AND indexname LIKE 'idx_listings_%'
ORDER BY indexname;

-- Check index sizes
SELECT 
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE tablename = 'listings'
AND indexname LIKE 'idx_listings_%'
ORDER BY pg_relation_size(indexrelid) DESC;

-- SUCCESS MESSAGE
DO $$
BEGIN
    RAISE NOTICE '✅ Step 1 Complete: Performance indexes created successfully';
    RAISE NOTICE 'Impact: NONE - these indexes improve query performance';
    RAISE NOTICE 'Next Step: Run enable_vector_search_safe.sql';
END $$;

