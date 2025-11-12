-- Debug OpenAI Setup - Find Out What's Wrong
-- Run this to see exactly what's failing

-- Test 1: Can we read the Vault secret?
DO $$
DECLARE
    api_key TEXT;
BEGIN
    RAISE NOTICE '====================================';
    RAISE NOTICE 'TEST 1: Reading Vault Secret';
    RAISE NOTICE '====================================';
    
    BEGIN
        SELECT decrypted_secret INTO api_key
        FROM vault.decrypted_secrets
        WHERE name = 'OPEN_AI_KEY'
        LIMIT 1;
        
        IF api_key IS NULL THEN
            RAISE NOTICE '❌ FAIL: Secret OPEN_AI_KEY not found in Vault';
            RAISE NOTICE '';
            RAISE NOTICE 'Possible fixes:';
            RAISE NOTICE '1. Check secret name is exactly: OPEN_AI_KEY (case-sensitive)';
            RAISE NOTICE '2. Re-create secret in Vault';
            RAISE NOTICE '3. Make sure secret is not empty';
        ELSIF LENGTH(api_key) < 20 THEN
            RAISE NOTICE '❌ FAIL: API key looks too short: % characters', LENGTH(api_key);
            RAISE NOTICE 'OpenAI keys should be 50+ characters';
        ELSIF NOT api_key LIKE 'sk-%' THEN
            RAISE NOTICE '❌ FAIL: API key does not start with sk-';
            RAISE NOTICE 'OpenAI keys should start with: sk-proj- or sk-';
        ELSE
            RAISE NOTICE '✅ PASS: Found API key in Vault';
            RAISE NOTICE 'Key length: % characters', LENGTH(api_key);
            RAISE NOTICE 'Key prefix: %...', SUBSTRING(api_key, 1, 10);
        END IF;
    EXCEPTION
        WHEN undefined_table THEN
            RAISE NOTICE '❌ FAIL: vault.decrypted_secrets table not found';
            RAISE NOTICE 'Vault may not be enabled on your Supabase plan';
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FAIL: Error reading Vault: %', SQLERRM;
    END;
    
    RAISE NOTICE '';
END $$;

-- Test 2: Is HTTP extension enabled?
DO $$
BEGIN
    RAISE NOTICE '====================================';
    RAISE NOTICE 'TEST 2: HTTP Extension';
    RAISE NOTICE '====================================';
    
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'http') THEN
        RAISE NOTICE '✅ PASS: HTTP extension is enabled';
    ELSE
        RAISE NOTICE '❌ FAIL: HTTP extension not enabled';
        RAISE NOTICE 'Run: CREATE EXTENSION IF NOT EXISTS http;';
    END IF;
    
    RAISE NOTICE '';
END $$;

-- Test 3: Check if vector column and extension exist
DO $$
BEGIN
    RAISE NOTICE '====================================';
    RAISE NOTICE 'TEST 3: Vector Support';
    RAISE NOTICE '====================================';
    
    IF EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector') THEN
        RAISE NOTICE '✅ PASS: pgvector extension enabled';
    ELSE
        RAISE NOTICE '❌ FAIL: pgvector extension not enabled';
        RAISE NOTICE 'Run: CREATE EXTENSION IF NOT EXISTS vector;';
    END IF;
    
    IF EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'embedding'
    ) THEN
        RAISE NOTICE '✅ PASS: embedding column exists';
    ELSE
        RAISE NOTICE '❌ FAIL: embedding column does not exist';
        RAISE NOTICE 'Run: ALTER TABLE listings ADD COLUMN embedding vector(384);';
    END IF;
    
    RAISE NOTICE '';
END $$;

-- Test 4: Try a simple HTTP request (not to OpenAI, just to test HTTP works)
DO $$
DECLARE
    test_response jsonb;
BEGIN
    RAISE NOTICE '====================================';
    RAISE NOTICE 'TEST 4: HTTP Requests';
    RAISE NOTICE '====================================';
    
    BEGIN
        SELECT content::jsonb INTO test_response
        FROM http((
            'GET',
            'https://httpbin.org/get',
            ARRAY[]::http_header[],
            NULL,
            NULL
        ));
        
        RAISE NOTICE '✅ PASS: HTTP requests work';
    EXCEPTION
        WHEN OTHERS THEN
            RAISE NOTICE '❌ FAIL: HTTP requests not working: %', SQLERRM;
            RAISE NOTICE 'This might be a Supabase network configuration issue';
    END;
    
    RAISE NOTICE '';
END $$;

-- Summary
DO $$
BEGIN
    RAISE NOTICE '====================================';
    RAISE NOTICE 'DIAGNOSTIC COMPLETE';
    RAISE NOTICE '====================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Look at the results above.';
    RAISE NOTICE 'Tell me which tests FAILED and I will help fix them.';
    RAISE NOTICE '';
END $$;

