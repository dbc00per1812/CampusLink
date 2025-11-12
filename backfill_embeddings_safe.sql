-- STEP 5: Backfill Embeddings (PRODUCTION SAFE)
-- Risk: LOW - Processes in tiny batches, can stop anytime
-- Rollback: N/A - just stop running it
-- Estimated time: ~100 listings per minute
-- Impact: NONE on users, runs in background

-- Check current status BEFORE starting
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as already_done,
    COUNT(*) FILTER (WHERE embedding IS NULL) as need_embeddings,
    COUNT(*) as total_active,
    ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / NULLIF(COUNT(*), 0), 1) as percent_complete
FROM listings
WHERE status = 'active' AND archived = false;

-- Process in SMALL batches (10 at a time)
-- This is safe - run multiple times until complete
DO $$
DECLARE
    result jsonb;
BEGIN
    RAISE NOTICE '🔄 Processing batch of 10 listings...';
    
    -- Call the batch function
    SELECT regenerate_embeddings_batch(10) INTO result;
    
    -- Show results
    RAISE NOTICE '';
    RAISE NOTICE '📊 Batch Results:';
    RAISE NOTICE '  Processed: %', result->>'processed';
    RAISE NOTICE '  Succeeded: %', result->>'succeeded';
    RAISE NOTICE '  Failed: %', result->>'failed';
    
    -- Show errors if any
    IF (result->>'failed')::int > 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '❌ Errors:';
        RAISE NOTICE '%', result->'errors';
    END IF;
END $$;

-- Check progress AFTER running
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as done,
    COUNT(*) FILTER (WHERE embedding IS NULL) as remaining,
    COUNT(*) as total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / NULLIF(COUNT(*), 0), 1) as percent_complete
FROM listings
WHERE status = 'active' AND archived = false;

-- Instructions
DO $$
DECLARE
    remaining_count INTEGER;
BEGIN
    SELECT COUNT(*) INTO remaining_count
    FROM listings
    WHERE status = 'active' AND archived = false AND embedding IS NULL;
    
    IF remaining_count = 0 THEN
        RAISE NOTICE '';
        RAISE NOTICE '✅ SUCCESS: All embeddings generated!';
        RAISE NOTICE '';
        RAISE NOTICE 'Next steps:';
        RAISE NOTICE '1. (Optional) Enable triggers: run enable_embedding_triggers.sql';
        RAISE NOTICE '2. Enable hybrid search: run create_hybrid_search_safe.sql';
    ELSE
        RAISE NOTICE '';
        RAISE NOTICE '🔄 Still processing... % listings remaining', remaining_count;
        RAISE NOTICE '';
        RAISE NOTICE 'To continue:';
        RAISE NOTICE 'Just run this script again!';
        RAISE NOTICE '';
        RAISE NOTICE 'Estimated batches remaining: %', CEIL(remaining_count / 10.0);
        RAISE NOTICE 'Estimated time: % minutes', CEIL(remaining_count / 10.0);
    END IF;
END $$;

-- SAMPLE EMBEDDINGS (verify they look correct)
SELECT 
    id,
    title,
    category,
    CASE WHEN embedding IS NOT NULL THEN 'Yes ✅' ELSE 'No ❌' END as has_embedding,
    created_at
FROM listings
WHERE status = 'active' AND archived = false
ORDER BY created_at DESC
LIMIT 10;

-- NO ROLLBACK NEEDED
-- If you want to clear embeddings and start over:
-- UPDATE listings SET embedding = NULL WHERE embedding IS NOT NULL;

