-- Backfill Embeddings for Existing Listings
-- This script generates embeddings for existing listings that don't have them
-- Run this MULTIPLE TIMES until all listings have embeddings
-- Run in Supabase SQL Editor AFTER running create_embedding_function.sql

-- Step 1: Check current status
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as with_embeddings,
    COUNT(*) FILTER (WHERE embedding IS NULL) as without_embeddings,
    COUNT(*) as total_active
FROM listings
WHERE status = 'active' AND archived = false;

-- Step 2: Backfill embeddings in batches
-- Process 100 listings at a time to avoid timeout
-- Run this block multiple times until without_embeddings = 0
DO $$
DECLARE
    listing_record RECORD;
    processed_count INTEGER := 0;
    failed_count INTEGER := 0;
BEGIN
    RAISE NOTICE 'Starting backfill batch...';
    
    FOR listing_record IN 
        SELECT id, title 
        FROM listings 
        WHERE status = 'active' 
        AND archived = false 
        AND embedding IS NULL
        ORDER BY created_at DESC
        LIMIT 100  -- Process 100 at a time
    LOOP
        BEGIN
            PERFORM generate_listing_embedding(listing_record.id);
            processed_count := processed_count + 1;
            
            -- Log progress every 10 listings
            IF processed_count % 10 = 0 THEN
                RAISE NOTICE 'Processed % listings...', processed_count;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                failed_count := failed_count + 1;
                RAISE NOTICE 'Failed to generate embedding for "%" (ID: %): %', 
                    listing_record.title, listing_record.id, SQLERRM;
        END;
    END LOOP;
    
    RAISE NOTICE 'Backfill batch complete. Processed: %, Failed: %', processed_count, failed_count;
END $$;

-- Step 3: Check progress after running the backfill
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as with_embeddings,
    COUNT(*) FILTER (WHERE embedding IS NULL) as without_embeddings,
    COUNT(*) as total_active,
    ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / COUNT(*), 2) as completion_percentage
FROM listings
WHERE status = 'active' AND archived = false;

-- Step 4: Show samples of listings with and without embeddings
-- Listings WITH embeddings
SELECT 
    id, 
    title,
    category,
    listing_type,
    created_at,
    CASE WHEN embedding IS NOT NULL THEN 'Yes' ELSE 'No' END as has_embedding
FROM listings
WHERE status = 'active' AND archived = false AND embedding IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- Listings WITHOUT embeddings (to identify issues)
SELECT 
    id, 
    title,
    category,
    listing_type,
    created_at,
    CASE WHEN embedding IS NOT NULL THEN 'Yes' ELSE 'No' END as has_embedding
FROM listings
WHERE status = 'active' AND archived = false AND embedding IS NULL
ORDER BY created_at DESC
LIMIT 5;

-- ALTERNATIVE: Use the helper function to backfill in smaller batches
-- Uncomment and run multiple times:
-- SELECT * FROM regenerate_all_embeddings(50);

-- MANUAL: Generate embedding for a specific listing
-- Replace the ID with an actual listing ID:
-- SELECT generate_listing_embedding('REPLACE-WITH-ACTUAL-UUID'::uuid);

