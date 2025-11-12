-- STEP 4: Create Embedding Functions (PRODUCTION SAFE - NO TRIGGERS)
-- Risk: LOW - Just creates functions, doesn't auto-run
-- Rollback: Easy - just drop functions
-- Estimated time: 10 seconds
-- Impact: NONE until you manually call the functions

-- Function to generate embedding for a single listing
-- SAFE: Includes error handling, won't crash if AI not configured
CREATE OR REPLACE FUNCTION generate_listing_embedding(
    listing_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    listing_text TEXT;
    embedding_result vector(384);
    result_json jsonb;
BEGIN
    -- Combine title, description, and category for embedding
    SELECT 
        COALESCE(title, '') || ' ' || 
        COALESCE(description, '') || ' ' || 
        COALESCE(category, '') || ' ' ||
        CASE 
            WHEN listing_type = 'product' THEN 'product'
            WHEN listing_type = 'service' THEN 'service'
            ELSE ''
        END
    INTO listing_text
    FROM listings
    WHERE id = listing_id;
    
    -- Check if we got any text
    IF listing_text IS NULL OR TRIM(listing_text) = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No text found for listing',
            'listing_id', listing_id
        );
    END IF;
    
    -- Try to generate embedding
    -- NOTE: This assumes Supabase AI is enabled
    -- If you get errors here, Supabase AI is not configured
    BEGIN
        -- OPTION 1: Try Supabase's built-in AI
        -- You may need to adjust this based on your Supabase plan
        SELECT embedding INTO embedding_result
        FROM ai.embeddings
        WHERE model = 'text-embedding-3-small'
        AND content = listing_text
        LIMIT 1;
        
        -- If no result, try generating
        IF embedding_result IS NULL THEN
            -- Insert to generate
            INSERT INTO ai.embeddings (model, content)
            VALUES ('text-embedding-3-small', listing_text)
            RETURNING embedding INTO embedding_result;
        END IF;
        
    EXCEPTION
        WHEN undefined_table THEN
            -- ai.embeddings doesn't exist, return helpful error
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Supabase AI not enabled. Enable in Dashboard → Settings → AI',
                'listing_id', listing_id,
                'fix', 'Go to Supabase Dashboard → Project Settings → AI → Enable Database Functions'
            );
        WHEN OTHERS THEN
            -- Other error
            RETURN jsonb_build_object(
                'success', false,
                'error', SQLERRM,
                'listing_id', listing_id,
                'text', LEFT(listing_text, 100)
            );
    END;
    
    -- Update listing with embedding
    IF embedding_result IS NOT NULL THEN
        UPDATE listings
        SET embedding = embedding_result
        WHERE id = listing_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'listing_id', listing_id,
            'text_length', LENGTH(listing_text)
        );
    ELSE
        RETURN jsonb_build_object(
            'success', false,
            'error', 'Failed to generate embedding',
            'listing_id', listing_id
        );
    END IF;
END;
$$;

-- Test function - generates embedding for ONE random listing
-- USE THIS TO TEST IF EVERYTHING IS WORKING
CREATE OR REPLACE FUNCTION test_embedding_generation()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    test_listing_id UUID;
    result jsonb;
BEGIN
    -- Get a random active listing
    SELECT id INTO test_listing_id
    FROM listings
    WHERE status = 'active' 
    AND archived = false
    AND embedding IS NULL
    LIMIT 1;
    
    IF test_listing_id IS NULL THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'No listings found to test (all may already have embeddings)'
        );
    END IF;
    
    -- Try to generate embedding
    result := generate_listing_embedding(test_listing_id);
    
    -- Add test info
    result := result || jsonb_build_object('test_listing_id', test_listing_id);
    
    RETURN result;
END;
$$;

-- Batch processing function - processes N listings at a time
-- SAFE: Processes in small batches, returns progress
CREATE OR REPLACE FUNCTION regenerate_embeddings_batch(
    batch_size INTEGER DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    listing_record RECORD;
    processed_count INTEGER := 0;
    failed_count INTEGER := 0;
    success_count INTEGER := 0;
    result jsonb;
    errors jsonb := '[]'::jsonb;
BEGIN
    FOR listing_record IN 
        SELECT id, title
        FROM listings 
        WHERE status = 'active' 
        AND archived = false 
        AND embedding IS NULL
        ORDER BY created_at DESC
        LIMIT batch_size
    LOOP
        -- Generate embedding
        result := generate_listing_embedding(listing_record.id);
        processed_count := processed_count + 1;
        
        -- Check if successful
        IF (result->>'success')::boolean THEN
            success_count := success_count + 1;
        ELSE
            failed_count := failed_count + 1;
            errors := errors || jsonb_build_object(
                'listing_id', listing_record.id,
                'title', listing_record.title,
                'error', result->>'error'
            );
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'processed', processed_count,
        'succeeded', success_count,
        'failed', failed_count,
        'errors', errors,
        'batch_size', batch_size
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_listing_embedding(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION test_embedding_generation() TO authenticated;
GRANT EXECUTE ON FUNCTION regenerate_embeddings_batch(INTEGER) TO authenticated;

-- Verify functions were created
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'generate_listing_embedding',
    'test_embedding_generation', 
    'regenerate_embeddings_batch'
)
ORDER BY routine_name;

-- SUCCESS MESSAGE & NEXT STEPS
DO $$
BEGIN
    RAISE NOTICE '✅ Step 4 Complete: Embedding functions created';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST IT NOW:';
    RAISE NOTICE 'Run: SELECT test_embedding_generation();';
    RAISE NOTICE '';
    RAISE NOTICE 'Expected results:';
    RAISE NOTICE '  ✅ {"success": true} = Working! Proceed to step 5';
    RAISE NOTICE '  ❌ Error about "ai.embeddings" = Enable Supabase AI first';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Step: Test, then run backfill_embeddings_safe.sql';
END $$;

-- TEST IT:
-- SELECT test_embedding_generation();

-- ROLLBACK INSTRUCTIONS (if needed):
/*
DROP FUNCTION IF EXISTS generate_listing_embedding(UUID);
DROP FUNCTION IF EXISTS test_embedding_generation();
DROP FUNCTION IF EXISTS regenerate_embeddings_batch(INTEGER);
*/

