-- Fix Embeddings - Simple Test First
-- Run this to diagnose why embeddings aren't generating

-- Test 1: Check if AI is available
DO $$
BEGIN
    -- Try to use Supabase AI
    BEGIN
        PERFORM (
            SELECT embedding 
            FROM ai.embeddings 
            WHERE model = 'text-embedding-3-small' 
            AND content = 'test'
            LIMIT 1
        );
        RAISE NOTICE '✅ Supabase AI is available';
    EXCEPTION
        WHEN undefined_table THEN
            RAISE NOTICE '❌ ERROR: ai.embeddings table does not exist';
            RAISE NOTICE 'FIX: Go to Supabase Dashboard → Project Settings → AI';
            RAISE NOTICE '     Toggle ON "Enable Database Functions"';
            RAISE NOTICE '     Wait 30 seconds, then run this file again';
        WHEN OTHERS THEN
            RAISE NOTICE '❌ ERROR: %', SQLERRM;
    END;
END $$;

-- Test 2: Manually generate ONE embedding to test
DO $$
DECLARE
    test_id UUID;
    result jsonb;
BEGIN
    -- Get one listing
    SELECT id INTO test_id
    FROM listings
    WHERE status = 'active' AND archived = false
    LIMIT 1;
    
    IF test_id IS NULL THEN
        RAISE NOTICE '❌ No active listings found';
        RETURN;
    END IF;
    
    RAISE NOTICE 'Testing embedding generation for listing: %', test_id;
    
    -- Try to generate
    result := generate_listing_embedding(test_id);
    
    RAISE NOTICE 'Result: %', result;
    
    IF (result->>'success')::boolean THEN
        RAISE NOTICE '✅ Embedding generation WORKS!';
        RAISE NOTICE 'Run backfill to generate all embeddings';
    ELSE
        RAISE NOTICE '❌ Embedding generation FAILED';
        RAISE NOTICE 'Error: %', result->>'error';
    END IF;
END $$;

