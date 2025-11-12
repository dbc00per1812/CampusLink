-- Simple Test - Returns Visible Results
-- This will show you exactly what's working and what's not

-- Test 1: Check Vault Secret (returns a row)
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM vault.decrypted_secrets WHERE name = 'OPEN_AI_KEY'
        ) THEN '✅ Vault secret exists'
        ELSE '❌ Vault secret NOT found'
    END as vault_status,
    (SELECT COUNT(*) FROM vault.decrypted_secrets WHERE name = 'OPEN_AI_KEY') as secret_count;

-- Test 2: Check Extensions
SELECT 
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector')
        THEN '✅ Enabled' ELSE '❌ Missing' END as pgvector,
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'http')
        THEN '✅ Enabled' ELSE '❌ Missing' END as http_extension;

-- Test 3: Check embedding column
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'embedding'
    )
    THEN '✅ Exists' ELSE '❌ Missing' END as embedding_column;

-- Test 4: Check if function exists
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.routines 
        WHERE routine_name = 'generate_listing_embedding_openai'
    )
    THEN '✅ Exists' ELSE '❌ Missing' END as embedding_function;

-- Test 5: Check listings status
SELECT 
    COUNT(*) as total_listings,
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as have_embeddings,
    COUNT(*) FILTER (WHERE embedding IS NULL) as need_embeddings
FROM listings
WHERE status = 'active' AND archived = false;
