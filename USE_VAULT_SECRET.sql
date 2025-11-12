-- Use OpenAI Key from Supabase Vault
-- This reads your OPEN_AI_KEY from Vault (more secure!)
-- Run this ENTIRE file in Supabase SQL Editor

-- =====================================================
-- STEP 1: Create Embedding Function Using Vault Secret
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
    -- Get API key from Vault
    -- Note: Vault secret name is OPEN_AI_KEY
    BEGIN
        SELECT decrypted_secret INTO api_key
        FROM vault.decrypted_secrets
        WHERE name = 'OPEN_AI_KEY'
        LIMIT 1;
    EXCEPTION
        WHEN undefined_table THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Vault not available. Using database setting instead.'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'Could not read from Vault: ' || SQLERRM
            );
    END;
    
    IF api_key IS NULL OR api_key = '' THEN
        RETURN jsonb_build_object(
            'success', false,
            'error', 'OPEN_AI_KEY not found in Vault. Check secret name and try again.'
        );
    END IF;
    
    -- Get listing text
    SELECT 
        COALESCE(title, '') || ' ' || 
        COALESCE(description, '') || ' ' || 
        COALESCE(category, '')
    INTO listing_text
    FROM listings
    WHERE id = listing_id;
    
    IF listing_text IS NULL OR TRIM(listing_text) = '' THEN
        RETURN jsonb_build_object('success', false, 'error', 'No text found');
    END IF;
    
    -- Call OpenAI API
    BEGIN
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
        
        -- Check for API errors
        IF api_response ? 'error' THEN
            RETURN jsonb_build_object(
                'success', false,
                'error', 'OpenAI API Error: ' || (api_response->'error'->>'message'),
                'listing_id', listing_id
            );
        END IF;
        
        -- Extract embedding array
        embedding_array := ARRAY(
            SELECT jsonb_array_elements_text(api_response->'data'->0->'embedding')::float
        );
        
        -- Convert to vector(384)
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
                'error', 'Exception: ' || SQLERRM,
                'listing_id', listing_id
            );
    END;
END;
$$;

-- Batch function
CREATE OR REPLACE FUNCTION generate_embeddings_batch(
    batch_size INTEGER DEFAULT 20
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
    first_error TEXT := NULL;
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
            -- Capture first error for debugging
            IF first_error IS NULL THEN
                first_error := result->>'error';
            END IF;
        END IF;
        
        -- Show progress every 5
        IF processed_count % 5 = 0 THEN
            RAISE NOTICE 'Progress: %/%...', success_count, processed_count;
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'processed', processed_count,
        'succeeded', success_count,
        'failed', failed_count,
        'first_error', first_error
    );
END;
$$;

GRANT EXECUTE ON FUNCTION generate_listing_embedding_openai(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION generate_embeddings_batch(INTEGER) TO authenticated;

-- =====================================================
-- STEP 2: Enable HTTP Extension
-- =====================================================

CREATE EXTENSION IF NOT EXISTS http;

DO $$
BEGIN
    RAISE NOTICE '✅ HTTP extension enabled (for API calls)';
END $$;

-- =====================================================
-- STEP 3: Test with ONE Listing
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
        RAISE NOTICE '❌ No listings found';
        RETURN;
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '🧪 Testing OpenAI embedding generation...';
    RAISE NOTICE 'Test listing: %', test_id;
    RAISE NOTICE '';
    
    result := generate_listing_embedding_openai(test_id);
    
    RAISE NOTICE 'Result: %', result;
    RAISE NOTICE '';
    
    IF (result->>'success')::boolean THEN
        RAISE NOTICE '✅ ✅ ✅ SUCCESS! ✅ ✅ ✅';
        RAISE NOTICE 'OpenAI is working with your Vault secret!';
        RAISE NOTICE '';
        RAISE NOTICE 'Continue to Step 4...';
    ELSE
        RAISE NOTICE '❌ FAILED: %', result->>'error';
        RAISE NOTICE '';
        RAISE NOTICE 'Common fixes:';
        RAISE NOTICE '1. Check secret name is exactly: OPEN_AI_KEY';
        RAISE NOTICE '2. Check key starts with sk-';
        RAISE NOTICE '3. Verify you have OpenAI credits';
    END IF;
END $$;

-- =====================================================
-- STEP 4: Generate All Embeddings
-- =====================================================

-- Generate 20 at a time
-- Run this section multiple times until done
DO $$
DECLARE
    result jsonb;
    remaining INTEGER;
BEGIN
    RAISE NOTICE '';
    RAISE NOTICE '🔄 Generating embeddings (batch of 20)...';
    
    result := generate_embeddings_batch(20);
    
    RAISE NOTICE '';
    RAISE NOTICE 'Batch results:';
    RAISE NOTICE '  Processed: %', result->>'processed';
    RAISE NOTICE '  Succeeded: %', result->>'succeeded';
    RAISE NOTICE '  Failed: %', result->>'failed';
    
    IF result->>'first_error' IS NOT NULL THEN
        RAISE NOTICE '  First error: %', result->>'first_error';
    END IF;
    
    -- Check remaining
    SELECT COUNT(*) INTO remaining
    FROM listings
    WHERE status = 'active' AND archived = false AND embedding IS NULL;
    
    RAISE NOTICE '';
    IF remaining = 0 THEN
        RAISE NOTICE '====================================';
        RAISE NOTICE '✅ ALL EMBEDDINGS COMPLETE!';
        RAISE NOTICE '====================================';
        RAISE NOTICE '';
        RAISE NOTICE 'Next steps:';
        RAISE NOTICE '1. Set AppConfig.enableHybridSearch = true';
        RAISE NOTICE '2. Build and run app';
        RAISE NOTICE '3. Test smart search!';
    ELSE
        RAISE NOTICE '⚠️  % listings remaining', remaining;
        RAISE NOTICE 'Run this file again (% more times)', CEIL(remaining / 20.0);
    END IF;
    RAISE NOTICE '';
END $$;

-- Final status
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as done,
    COUNT(*) FILTER (WHERE embedding IS NULL) as remaining,
    COUNT(*) as total,
    ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / COUNT(*)) as percent_done
FROM listings
WHERE status = 'active' AND archived = false;

