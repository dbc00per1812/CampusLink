-- =====================================================
-- OpenAI Embeddings Migration (Production Safe)
-- =====================================================
-- This uses OpenAI API directly instead of Supabase AI
-- 
-- BEFORE RUNNING:
-- 1. Get OpenAI API key from: https://platform.openai.com/api-keys
-- 2. Store it in Supabase Vault as "openai_api_key"
--    OR run: ALTER DATABASE postgres SET app.settings.openai_api_key = 'sk-YOUR-KEY';
-- 3. Run this entire file
-- 
-- Cost: ~$0.03 for 71 listings (very cheap!)
-- Time: 2-5 minutes
-- =====================================================

-- =====================================================
-- STEP 1: Create Embedding Function Using OpenAI API
-- =====================================================

CREATE OR REPLACE FUNCTION generate_listing_embedding_openai(
    listing_id UUID
)
RETURNS jsonb
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    listing_text TEXT;
    api_key TEXT;
    api_response jsonb;
    embedding_array float[];
    embedding_result vector(384);
BEGIN
    -- Get API key from settings
    BEGIN
        api_key := current_setting('app.settings.openai_api_key', true);
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'OpenAI API key not configured. Run: ALTER DATABASE postgres SET app.settings.openai_api_key = ''sk-YOUR-KEY'';'
            );
    END;
    
    IF api_key IS NULL OR api_key = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'OpenAI API key is empty'
        );
    END IF;
    
    -- Get listing text
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
    
    IF listing_text IS NULL OR TRIM(listing_text) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'No text found');
    END IF;
    
    -- Call OpenAI API using http extension
    BEGIN
        -- Make HTTP request to OpenAI
        SELECT content::jsonb INTO api_response
        FROM http((
            'POST',
            'https://api.openai.com/v1/embeddings',
            ARRAY[
                http_header('Authorization', 'Bearer ' || api_key),
                http_header('Content-Type', 'application/json')
            ],
            'application/json',
            jsonb_build_object(
                'input', listing_text,
                'model', 'text-embedding-3-small',
                'encoding_format', 'float'
            )::text
        ));
        
        -- Extract embedding from response
        embedding_array := ARRAY(
            SELECT jsonb_array_elements_text(api_response->'data'->0->'embedding')::float
        );
        
        -- Convert to vector
        embedding_result := embedding_array::vector(384);
        
        -- Update listing
        UPDATE listings
        SET embedding = embedding_result
        WHERE id = listing_id;
        
        RETURN jsonb_build_object(
            'success', true,
            'listing_id', listing_id,
            'text_length', LENGTH(listing_text)
        );
        
    EXCEPTION
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', SQLERRM,
                'listing_id', listing_id
            );
    END;
END;
$$;

-- Batch function for OpenAI
CREATE OR REPLACE FUNCTION generate_embeddings_openai_batch(
    batch_size INTEGER DEFAULT 10
)
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
    listing_record RECORD;
    processed_count INTEGER := 0;
    success_count INTEGER := 0;
    failed_count INTEGER := 0;
    result jsonb;
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
        result := generate_listing_embedding_openai(listing_record.id);
        processed_count := processed_count + 1;
        
        IF (result->>'success')::boolean THEN
            success_count := success_count + 1;
        ELSE
            failed_count := failed_count + 1;
            RAISE NOTICE 'Failed for "%": %', listing_record.title, result->>'error';
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'processed', processed_count,
        'succeeded', success_count,
        'failed', failed_count
    );
END;
$$;

GRANT EXECUTE ON FUNCTION generate_listing_embedding_openai(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_embeddings_openai_batch(INTEGER) TO authenticated;

-- Progress
DO $$
BEGIN
    RAISE NOTICE '✅ OpenAI embedding functions created';
END $$;

-- =====================================================
-- STEP 2: Enable HTTP Extension (Required for API calls)
-- =====================================================

CREATE EXTENSION IF NOT EXISTS http;

DO $$
BEGIN
    RAISE NOTICE '✅ HTTP extension enabled';
END $$;

-- =====================================================
-- STEP 3: Test with ONE listing
-- =====================================================

DO $$
DECLARE
    test_id UUID;
    result jsonb;
BEGIN
    SELECT id INTO test_id
    FROM listings
    WHERE status = 'active' AND archived = false
    LIMIT 1;
    
    IF test_id IS NULL THEN
        RAISE NOTICE '❌ No listings found to test';
        RETURN;
    END IF;
    
    RAISE NOTICE '🧪 Testing OpenAI embedding generation...';
    RAISE NOTICE 'Test listing ID: %', test_id;
    
    result := generate_listing_embedding_openai(test_id);
    
    RAISE NOTICE '';
    RAISE NOTICE 'Result: %', result;
    RAISE NOTICE '';
    
    IF (result->>'success')::boolean THEN
        RAISE NOTICE '✅ ✅ ✅ SUCCESS! ✅ ✅ ✅';
        RAISE NOTICE 'OpenAI embeddings are working!';
        RAISE NOTICE '';
        RAISE NOTICE 'Continue to Step 4 below...';
    ELSE
        RAISE NOTICE '❌ FAILED: %', result->>'error';
        RAISE NOTICE '';
        RAISE NOTICE 'Check:';
        RAISE NOTICE '1. API key is correct';
        RAISE NOTICE '2. API key starts with sk-';
        RAISE NOTICE '3. You have OpenAI credits';
    END IF;
END $$;

-- =====================================================
-- STEP 4: Generate All Embeddings (Run if test passed)
-- =====================================================

-- Generate embeddings in batches of 20
-- Run this multiple times until all done
DO $$
DECLARE
    result jsonb;
    remaining INTEGER;
BEGIN
    RAISE NOTICE '🔄 Generating embeddings for batch of 20...';
    
    result := generate_embeddings_openai_batch(20);
    
    RAISE NOTICE 'Processed: %', result->>'processed';
    RAISE NOTICE 'Succeeded: %', result->>'succeeded';
    RAISE NOTICE 'Failed: %', result->>'failed';
    
    -- Check progress
    SELECT COUNT(*) INTO remaining
    FROM listings
    WHERE status = 'active' AND archived = false AND embedding IS NULL;
    
    RAISE NOTICE '';
    IF remaining = 0 THEN
        RAISE NOTICE '✅ ALL DONE! All embeddings generated!';
    ELSE
        RAISE NOTICE '⚠️  % listings remaining', remaining;
        RAISE NOTICE 'Run this file again to continue...';
        RAISE NOTICE 'Estimated runs needed: %', CEIL(remaining / 20.0);
    END IF;
END $$;

-- =====================================================
-- FINAL STATUS
-- =====================================================

SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as embeddings_ready,
    COUNT(*) FILTER (WHERE embedding IS NULL) as embeddings_missing,
    COUNT(*) as total_active,
    ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / NULLIF(COUNT(*), 0)) as percent_complete
FROM listings
WHERE status = 'active' AND archived = false;

-- =====================================================
-- NOTES
-- =====================================================
/*
This approach:
- ✅ Works on any Supabase plan
- ✅ Uses OpenAI API directly (more reliable)
- ✅ Costs ~$0.03 for 71 listings
- ✅ Production-safe with error handling

If you get errors:
1. Check API key is stored correctly
2. Verify you have OpenAI credits
3. Check http extension is enabled
*/

