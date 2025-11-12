-- Create Hybrid Search Function
-- Combines keyword search (full-text) with semantic search (vector embeddings)
-- Run this in Supabase SQL Editor AFTER embeddings are generated
-- 
-- This creates a hybrid search that's smarter than keyword-only:
-- - "laptop" will find "computer", "macbook", etc.
-- - "bike" will find "bicycle", "cycling gear", etc.

-- Main hybrid search function
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
    keyword_weight FLOAT := 0.6;  -- 60% weight for keyword matching
    semantic_weight FLOAT := 0.4;  -- 40% weight for semantic similarity
    keyword_score REAL;
    semantic_score REAL;
BEGIN
    -- Generate embedding for search query (if text provided)
    IF query_text IS NOT NULL AND query_text != '' THEN
        BEGIN
            SELECT ai.openai_embed(
                'text-embedding-3-small',
                query_text,
                api_key => current_setting('app.settings.openai_api_key', true)
            ) INTO query_embedding;
        EXCEPTION
            WHEN OTHERS THEN
                -- If embedding generation fails, fall back to keyword-only search
                RAISE NOTICE 'Embedding generation failed, using keyword-only search: %', SQLERRM;
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
        -- Hybrid relevance score
        CASE 
            WHEN query_text IS NOT NULL AND query_text != '' THEN
                -- Calculate keyword score
                CASE WHEN query_embedding IS NOT NULL AND l.embedding IS NOT NULL THEN
                    -- Both keyword and semantic
                    (
                        keyword_weight * ts_rank(l.tsv, plainto_tsquery('english', query_text)) +
                        semantic_weight * (1 - (l.embedding <=> query_embedding))
                    )::REAL
                ELSE
                    -- Keyword only (fallback)
                    ts_rank(l.tsv, plainto_tsquery('english', query_text))::REAL
                END
            ELSE 
                1.0::REAL  -- No search text, all equal relevance
        END as relevance_score,
        u.name as user_name,
        u.email as user_email,
        u.campus as user_campus,
        u.profile_pic as user_avatar_url,
        u.trust_score as user_trust_score
    FROM listings l
    INNER JOIN users u ON l.user_id = u.id::uuid
    WHERE 
        -- Only active, non-archived, non-sold listings
        l.status = 'active'
        AND l.archived = false
        AND l.is_sold = false
        -- Hybrid text search filter
        AND (
            query_text IS NULL 
            OR query_text = '' 
            OR l.tsv @@ plainto_tsquery('english', query_text)  -- Keyword match
            OR (
                query_embedding IS NOT NULL 
                AND l.embedding IS NOT NULL 
                AND (l.embedding <=> query_embedding) < 0.5  -- Semantic similarity threshold
            )
        )
        -- Category filter
        AND (category_filter IS NULL OR l.category = category_filter)
        -- Price range filter
        AND (min_price IS NULL OR l.price >= min_price)
        AND (max_price IS NULL OR l.price <= max_price)
        -- Intent filter (offer/seek)
        AND (intent_filter IS NULL OR l.intent = intent_filter)
        -- Service location filter
        AND (service_location_filter IS NULL OR l.service_location = service_location_filter)
        -- Trust score filter
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION hybrid_search_listings TO authenticated;

-- Create a simpler search function that doesn't require all parameters
-- This makes it easier to call from the app
CREATE OR REPLACE FUNCTION quick_search(
    search_text TEXT,
    max_results INTEGER DEFAULT 20
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    price DECIMAL,
    category TEXT,
    photo TEXT,
    relevance_score REAL
)
LANGUAGE sql
AS $$
    SELECT 
        id,
        title,
        price,
        category,
        photo,
        relevance_score
    FROM hybrid_search_listings(
        query_text := search_text,
        limit_count := max_results
    );
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION quick_search TO authenticated;

-- Verify the functions were created
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('hybrid_search_listings', 'quick_search')
ORDER BY routine_name;

-- Test the hybrid search function
-- Uncomment to test with your data:
-- SELECT title, category, relevance_score
-- FROM hybrid_search_listings(
--     query_text := 'laptop computer'::text,
--     limit_count := 10
-- )
-- ORDER BY relevance_score DESC;

-- Compare with keyword-only search to see the difference
-- SELECT title, category, 
--     ts_rank(tsv, plainto_tsquery('english', 'laptop computer')) as keyword_score
-- FROM listings
-- WHERE tsv @@ plainto_tsquery('english', 'laptop computer')
-- AND status = 'active' AND archived = false
-- ORDER BY keyword_score DESC
-- LIMIT 10;

