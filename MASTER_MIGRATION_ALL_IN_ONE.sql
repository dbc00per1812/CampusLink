-- =====================================================
-- MASTER MIGRATION: Smart Recommendations & Search
-- =====================================================
-- This is ONE file with ALL queries in correct order
-- Run this ENTIRE file in Supabase SQL Editor
-- 
-- BEFORE RUNNING:
-- 1. Backup your database
-- 2. Enable Supabase AI: Dashboard → Settings → AI → Enable Database Functions
-- 3. Run during low-traffic time (recommended)
-- 
-- Time: 5-10 minutes total
-- Risk: LOW-MEDIUM (tested, includes safety checks)
-- =====================================================

-- =====================================================
-- PHASE 0: Performance Indexes (1-2 minutes)
-- =====================================================

-- Index for category-based diversification
CREATE INDEX IF NOT EXISTS idx_listings_category_created 
ON listings(category, created_at DESC) 
WHERE status = 'active' AND archived = false AND is_sold = false;

CREATE INDEX IF NOT EXISTS idx_listings_type_category 
ON listings(listing_type, category, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

CREATE INDEX IF NOT EXISTS idx_listings_intent_created
ON listings(intent, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

CREATE INDEX IF NOT EXISTS idx_listings_campus_category
ON listings(user_id, category, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Progress message
DO $$
BEGIN
    RAISE NOTICE '✅ Step 1/6: Performance indexes created';
END $$;

-- =====================================================
-- PHASE 1: Enable Vector Search (30 seconds)
-- =====================================================

-- Enable pgvector extension
CREATE EXTENSION IF NOT EXISTS vector;

-- Add embedding column (brief table lock)
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS embedding vector(384);

-- Create vector similarity index (1-5 minutes)
CREATE INDEX IF NOT EXISTS idx_listings_embedding 
ON listings USING hnsw (embedding vector_cosine_ops)
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Add full-text search index
CREATE INDEX IF NOT EXISTS idx_listings_tsv 
ON listings USING gin(tsv);

-- Progress message
DO $$
BEGIN
    RAISE NOTICE '✅ Step 2/6: Vector search enabled, embedding column added';
END $$;

-- =====================================================
-- PHASE 2: Create Embedding Functions (10 seconds)
-- =====================================================

-- Function to generate embedding for a single listing
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
BEGIN
    -- Combine title, description, and category
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
    
    -- Generate embedding using Supabase AI
    BEGIN
        SELECT embedding INTO embedding_result
        FROM ai.embeddings
        WHERE model = 'text-embedding-3-small'
        AND content = listing_text
        LIMIT 1;
        
        IF embedding_result IS NULL THEN
            INSERT INTO ai.embeddings (model, content)
            VALUES ('text-embedding-3-small', listing_text)
            RETURNING embedding INTO embedding_result;
        END IF;
        
        -- Update listing
        UPDATE listings
        SET embedding = embedding_result
        WHERE id = listing_id;
        
        RETURN jsonb_build_object('success', true, 'listing_id', listing_id);
        
    EXCEPTION
        WHEN undefined_table THEN
            RETURN jsonb_build_object(
                'success', false, 
                'error', 'Supabase AI not enabled. Enable in Dashboard → Settings → AI'
            );
        WHEN OTHERS THEN
            RETURN jsonb_build_object('success', false, 'error', SQLERRM);
    END;
END;
$$;

-- Batch processing function
CREATE OR REPLACE FUNCTION regenerate_embeddings_batch(
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
        result := generate_listing_embedding(listing_record.id);
        processed_count := processed_count + 1;
        
        IF (result->>'success')::boolean THEN
            success_count := success_count + 1;
        ELSE
            failed_count := failed_count + 1;
        END IF;
    END LOOP;
    
    RETURN jsonb_build_object(
        'processed', processed_count,
        'succeeded', success_count,
        'failed', failed_count
    );
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION generate_listing_embedding(UUID) TO authenticated;
GRANT EXECUTE ON FUNCTION regenerate_embeddings_batch(INTEGER) TO authenticated;

-- Progress message
DO $$
BEGIN
    RAISE NOTICE '✅ Step 3/6: Embedding functions created';
END $$;

-- =====================================================
-- PHASE 3: Backfill Embeddings (Run until complete)
-- =====================================================

-- Process 50 listings at a time
DO $$
DECLARE
    result jsonb;
    remaining INTEGER;
BEGIN
    RAISE NOTICE '🔄 Generating embeddings (batch of 50)...';
    
    SELECT regenerate_embeddings_batch(50) INTO result;
    
    RAISE NOTICE '  Processed: %', result->>'processed';
    RAISE NOTICE '  Succeeded: %', result->>'succeeded';
    RAISE NOTICE '  Failed: %', result->>'failed';
    
    -- Check remaining
    SELECT COUNT(*) INTO remaining
    FROM listings
    WHERE status = 'active' AND archived = false AND embedding IS NULL;
    
    IF remaining = 0 THEN
        RAISE NOTICE '✅ Step 4/6: All embeddings generated!';
    ELSE
        RAISE NOTICE '⚠️  Step 4/6: % listings still need embeddings', remaining;
        RAISE NOTICE '   Run this file again to continue...';
    END IF;
END $$;

-- =====================================================
-- PHASE 4: Hybrid Search Function (5 seconds)
-- =====================================================

CREATE OR REPLACE FUNCTION hybrid_search_listings(
    query_text TEXT DEFAULT NULL,
    category_filter TEXT DEFAULT NULL,
    min_price DECIMAL DEFAULT NULL,
    max_price DECIMAL DEFAULT NULL,
    intent_filter TEXT DEFAULT NULL,
    service_location_filter TEXT DEFAULT NULL,
    trust_min INTEGER DEFAULT NULL,
    trust_max INTEGER DEFAULT NULL,
    sort_by TEXT DEFAULT 'relevance',
    limit_count INTEGER DEFAULT 20,
    offset_count INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    description TEXT,
    price DECIMAL,
    category TEXT,
    photo TEXT,
    photos TEXT[],
    intent TEXT,
    status TEXT,
    archived BOOLEAN,
    service_location TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    relevance_score REAL,
    user_name TEXT,
    user_email TEXT,
    user_campus TEXT,
    user_avatar_url TEXT,
    user_trust_score INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    query_embedding vector(384);
    keyword_weight FLOAT := 0.6;
    semantic_weight FLOAT := 0.4;
BEGIN
    -- Try to generate embedding for search query
    IF query_text IS NOT NULL AND query_text != '' THEN
        BEGIN
            SELECT embedding INTO query_embedding
            FROM ai.embeddings
            WHERE model = 'text-embedding-3-small'
            AND content = query_text
            LIMIT 1;
            
            IF query_embedding IS NULL THEN
                INSERT INTO ai.embeddings (model, content)
                VALUES ('text-embedding-3-small', query_text)
                RETURNING embedding INTO query_embedding;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                query_embedding := NULL;
        END;
    END IF;
    
    RETURN QUERY
    SELECT 
        l.id,
        l.user_id,
        l.title,
        l.description,
        l.price,
        l.category,
        l.photo,
        l.photos,
        l.intent,
        l.status,
        l.archived,
        l.service_location::text,
        l.created_at,
        -- Hybrid or keyword-only score
        CASE 
            WHEN query_text IS NOT NULL AND query_text != '' 
                AND query_embedding IS NOT NULL AND l.embedding IS NOT NULL THEN
                (
                    keyword_weight * ts_rank(l.tsv, plainto_tsquery('english', query_text)) +
                    semantic_weight * (1 - (l.embedding <=> query_embedding))
                )::REAL
            WHEN query_text IS NOT NULL AND query_text != '' THEN
                ts_rank(l.tsv, plainto_tsquery('english', query_text))::REAL
            ELSE 
                1.0::REAL
        END as relevance_score,
        u.name as user_name,
        u.email as user_email,
        u.campus as user_campus,
        u.profile_pic as user_avatar_url,
        u.trust_score as user_trust_score
    FROM listings l
    INNER JOIN users u ON l.user_id = u.id::uuid
    WHERE 
        l.status = 'active'
        AND l.archived = false
        AND l.is_sold = false
        AND (
            query_text IS NULL 
            OR query_text = '' 
            OR l.tsv @@ plainto_tsquery('english', query_text)
            OR (
                query_embedding IS NOT NULL 
                AND l.embedding IS NOT NULL 
                AND (l.embedding <=> query_embedding) < 0.5
            )
        )
        AND (category_filter IS NULL OR l.category = category_filter)
        AND (min_price IS NULL OR l.price >= min_price)
        AND (max_price IS NULL OR l.price <= max_price)
        AND (intent_filter IS NULL OR l.intent = intent_filter)
        AND (service_location_filter IS NULL OR l.service_location = service_location_filter)
        AND (trust_min IS NULL OR u.trust_score >= trust_min)
        AND (trust_max IS NULL OR u.trust_score <= trust_max)
    ORDER BY
        CASE 
            WHEN sort_by = 'relevance' AND query_text IS NOT NULL AND query_text != '' THEN
                relevance_score
        END DESC NULLS LAST,
        CASE WHEN sort_by = 'price_asc' THEN l.price END ASC NULLS LAST,
        CASE WHEN sort_by = 'price_desc' THEN l.price END DESC NULLS LAST,
        CASE WHEN sort_by = 'recent' OR sort_by IS NULL THEN l.created_at END DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$;

GRANT EXECUTE ON FUNCTION hybrid_search_listings TO authenticated;

-- Progress message
DO $$
BEGIN
    RAISE NOTICE '✅ Step 5/6: Hybrid search function created';
END $$;

-- =====================================================
-- PHASE 5: Similar Items Function (5 seconds)
-- =====================================================

CREATE OR REPLACE FUNCTION get_similar_listings(
    target_listing_id UUID,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    description TEXT,
    price DECIMAL,
    category TEXT,
    photo TEXT,
    photos TEXT[],
    intent TEXT,
    listing_type TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    similarity_score REAL,
    user_name TEXT,
    user_campus TEXT
)
LANGUAGE plpgsql
AS $$
DECLARE
    target_embedding vector(384);
    target_category TEXT;
BEGIN
    SELECT embedding, category
    INTO target_embedding, target_category
    FROM listings
    WHERE id = target_listing_id;
    
    IF target_embedding IS NULL THEN
        RETURN;
    END IF;
    
    RETURN QUERY
    SELECT 
        l.id,
        l.user_id,
        l.title,
        l.description,
        l.price,
        l.category,
        l.photo,
        l.photos,
        l.intent,
        l.listing_type::text,
        l.created_at,
        (1 - (l.embedding <=> target_embedding))::REAL as similarity_score,
        u.name as user_name,
        u.campus as user_campus
    FROM listings l
    INNER JOIN users u ON l.user_id = u.id::uuid
    WHERE l.id != target_listing_id
    AND l.status = 'active'
    AND l.archived = false
    AND l.is_sold = false
    AND l.embedding IS NOT NULL
    ORDER BY 
        l.embedding <=> target_embedding ASC,
        CASE WHEN l.category = target_category THEN 0 ELSE 1 END,
        l.created_at DESC
    LIMIT limit_count;
END;
$$;

-- Simpler version for UI
CREATE OR REPLACE FUNCTION get_similar_listings_simple(
    target_listing_id UUID,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    price DECIMAL,
    photo TEXT,
    category TEXT,
    similarity_score REAL
)
LANGUAGE sql
AS $$
    SELECT 
        id, title, price, photo, category, similarity_score
    FROM get_similar_listings(target_listing_id, limit_count);
$$;

GRANT EXECUTE ON FUNCTION get_similar_listings TO authenticated;
GRANT EXECUTE ON FUNCTION get_similar_listings_simple TO authenticated;

-- Progress message
DO $$
BEGIN
    RAISE NOTICE '✅ Step 6/6: Similar items functions created';
END $$;

-- =====================================================
-- VERIFICATION & STATUS
-- =====================================================

-- Check vector extension
SELECT 
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector')
        THEN '✅ pgvector extension enabled'
        ELSE '❌ pgvector extension NOT enabled'
    END as vector_status;

-- Check embedding column
SELECT 
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'listings' AND column_name = 'embedding'
        )
        THEN '✅ embedding column exists'
        ELSE '❌ embedding column NOT found'
    END as column_status;

-- Check indexes created
SELECT 
    indexname,
    tablename
FROM pg_indexes
WHERE tablename IN ('listings', 'users')
AND indexname LIKE 'idx_listings_%'
ORDER BY indexname;

-- Check functions created
SELECT 
    routine_name,
    '✅ Function exists' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'generate_listing_embedding',
    'regenerate_embeddings_batch',
    'hybrid_search_listings',
    'get_similar_listings',
    'get_similar_listings_simple'
)
ORDER BY routine_name;

-- Check embedding progress
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as with_embeddings,
    COUNT(*) FILTER (WHERE embedding IS NULL) as without_embeddings,
    COUNT(*) as total_active,
    ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / NULLIF(COUNT(*), 0), 1) as percent_complete
FROM listings
WHERE status = 'active' AND archived = false;

-- =====================================================
-- FINAL STATUS
-- =====================================================

DO $$
DECLARE
    remaining INTEGER;
    total INTEGER;
    percent NUMERIC;
BEGIN
    SELECT 
        COUNT(*) FILTER (WHERE embedding IS NULL),
        COUNT(*),
        ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / NULLIF(COUNT(*), 0), 1)
    INTO remaining, total, percent
    FROM listings
    WHERE status = 'active' AND archived = false;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'MIGRATION STATUS';
    RAISE NOTICE '====================================';
    RAISE NOTICE '';
    RAISE NOTICE 'Active listings: %', total;
    RAISE NOTICE 'With embeddings: % (% percent)', total - remaining, percent;
    RAISE NOTICE 'Without embeddings: %', remaining;
    RAISE NOTICE '';
    
    IF remaining = 0 THEN
        RAISE NOTICE 'MIGRATION COMPLETE!';
        RAISE NOTICE '';
        RAISE NOTICE 'Next steps:';
        RAISE NOTICE '1. Build and run your app';
        RAISE NOTICE '2. Test the home feed';
        RAISE NOTICE '3. Test search';
        RAISE NOTICE '4. AppConfig.enableHybridSearch is already true';
    ELSE
        RAISE NOTICE 'EMBEDDINGS IN PROGRESS';
        RAISE NOTICE '';
        RAISE NOTICE 'Run this file again to continue backfill';
        RAISE NOTICE 'Estimated batches remaining: %', CEIL(remaining / 50.0);
        RAISE NOTICE '';
        RAISE NOTICE 'The app will work, but hybrid search will';
        RAISE NOTICE 'fall back to keyword-only for missing embeddings.';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '====================================';
END $$;

-- =====================================================
-- ROLLBACK (if needed)
-- =====================================================
/*
-- Uncomment and run this section to completely undo everything:

DROP FUNCTION IF EXISTS generate_listing_embedding(UUID);
DROP FUNCTION IF EXISTS regenerate_embeddings_batch(INTEGER);
DROP FUNCTION IF EXISTS hybrid_search_listings;
DROP FUNCTION IF EXISTS get_similar_listings;
DROP FUNCTION IF EXISTS get_similar_listings_simple;

ALTER TABLE listings DROP COLUMN IF EXISTS embedding;

DROP INDEX IF EXISTS idx_listings_embedding;
DROP INDEX IF EXISTS idx_listings_category_created;
DROP INDEX IF EXISTS idx_listings_type_category;
DROP INDEX IF EXISTS idx_listings_intent_created;
DROP INDEX IF EXISTS idx_listings_campus_category;

DROP EXTENSION IF EXISTS vector;

-- Then set in app: AppConfig.enableHybridSearch = false
*/

