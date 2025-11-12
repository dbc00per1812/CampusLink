-- Optimize Listing Queries for Category Diversification
-- This adds indexes to speed up category-based filtering for smart recommendations
-- Run this in Supabase SQL Editor

-- Index for category-based diversification queries
-- Speeds up queries that filter by category and sort by recency
CREATE INDEX IF NOT EXISTS idx_listings_category_created 
ON listings(category, created_at DESC) 
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Index for listing type + category combination
-- Enables fast filtering by both type (product/service) and category
CREATE INDEX IF NOT EXISTS idx_listings_type_category 
ON listings(listing_type, category, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Index for intent-based queries (offer/seek)
-- Optimizes the forSale and wanted tabs
CREATE INDEX IF NOT EXISTS idx_listings_intent_created
ON listings(intent, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Composite index for campus + category filtering
-- Speeds up campus-filtered, category-diversified queries
CREATE INDEX IF NOT EXISTS idx_listings_campus_category
ON listings(user_id, category, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Verify indexes were created successfully
SELECT 
    indexname,
    indexdef
FROM pg_indexes
WHERE tablename = 'listings'
AND indexname LIKE 'idx_listings_%'
ORDER BY indexname;

-- Check index sizes for monitoring
SELECT 
    schemaname,
    tablename,
    indexname,
    pg_size_pretty(pg_relation_size(indexrelid)) AS index_size
FROM pg_stat_user_indexes
WHERE tablename = 'listings'
AND indexname LIKE 'idx_listings_%'
ORDER BY pg_relation_size(indexrelid) DESC;

