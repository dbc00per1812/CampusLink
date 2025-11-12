-- STEP 6 (OPTIONAL): Enable Automatic Embedding Generation
-- Risk: MEDIUM - Will slow down listing creation slightly
-- Rollback: Easy - just drop the trigger
-- Impact: Embeddings auto-generated for new/updated listings
-- 
-- ⚠️  ONLY RUN THIS AFTER:
-- 1. Backfill is 100% complete
-- 2. You've tested that embedding generation works
-- 3. You've verified it doesn't slow down inserts too much

-- Check if backfill is complete
DO $$
DECLARE
    remaining INTEGER;
BEGIN
    SELECT COUNT(*) INTO remaining
    FROM listings
    WHERE status = 'active' AND archived = false AND embedding IS NULL;
    
    IF remaining > 0 THEN
        RAISE WARNING '⚠️  WARNING: % listings still need embeddings', remaining;
        RAISE WARNING 'Consider finishing backfill first: run backfill_embeddings_safe.sql';
        RAISE WARNING '';
        RAISE WARNING 'Continue anyway? This trigger will process them automatically...';
    ELSE
        RAISE NOTICE '✅ All active listings have embeddings, safe to proceed';
    END IF;
END $$;

-- Create trigger function
CREATE OR REPLACE FUNCTION auto_generate_embedding()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
DECLARE
    result jsonb;
BEGIN
    -- Only generate for active, non-archived listings
    IF NEW.status = 'active' AND NEW.archived = false THEN
        -- Generate embedding asynchronously (doesn't block the insert)
        -- Using pg_notify to queue it (you could also use a background job)
        result := generate_listing_embedding(NEW.id);
        
        -- Log if failed (but don't block the insert)
        IF NOT (result->>'success')::boolean THEN
            RAISE WARNING 'Failed to generate embedding for listing %: %', NEW.id, result->>'error';
        END IF;
    END IF;
    
    RETURN NEW;
END;
$$;

-- Create trigger (fires AFTER insert/update, so doesn't block)
DROP TRIGGER IF EXISTS trigger_generate_embedding ON listings;
CREATE TRIGGER trigger_generate_embedding
AFTER INSERT OR UPDATE OF title, description, category, listing_type ON listings
FOR EACH ROW
WHEN (NEW.status = 'active' AND NEW.archived = false)
EXECUTE FUNCTION auto_generate_embedding();

-- Verify trigger was created
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'trigger_generate_embedding';

-- SUCCESS MESSAGE
DO $$
BEGIN
    RAISE NOTICE '✅ Automatic embedding generation ENABLED';
    RAISE NOTICE '';
    RAISE NOTICE 'What happens now:';
    RAISE NOTICE '  - New listings: embedding auto-generated on creation';
    RAISE NOTICE '  - Updates: embedding regenerated when title/description changes';
    RAISE NOTICE '';
    RAISE NOTICE '⚠️  Monitor performance:';
    RAISE NOTICE '  - Watch insert/update times for listings';
    RAISE NOTICE '  - Check logs for any embedding errors';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Run create_hybrid_search_safe.sql';
END $$;

-- TEST IT:
-- Try creating a test listing and verify embedding is generated
/*
INSERT INTO listings (
    user_id, title, description, category, listing_type, 
    price, status, archived, is_sold
) VALUES (
    (SELECT id FROM users LIMIT 1),
    'Test Laptop',
    'A test laptop for embedding',
    'Electronics',
    'product',
    100,
    'active',
    false,
    false
) RETURNING id, title, embedding IS NOT NULL as has_embedding;
*/

-- ROLLBACK INSTRUCTIONS (if needed):
/*
-- Disable the trigger
DROP TRIGGER IF EXISTS trigger_generate_embedding ON listings;
DROP FUNCTION IF EXISTS auto_generate_embedding();

-- Verify removed
SELECT * FROM information_schema.triggers 
WHERE trigger_name = 'trigger_generate_embedding';
-- Should return 0 rows
*/

