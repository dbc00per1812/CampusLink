-- STEP 7: Create Hybrid Search Function (PRODUCTION SAFE)
-- Risk: LOW - Just creates a function, doesn't change data
-- Rollback: Easy - just drop the function
-- Estimated time: 5 seconds
-- Impact: NONE until you enable it in app with AppConfig.enableHybridSearch = true

-- Hybrid search function with graceful fallback
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
    has_embeddings BOOLEAN;
BEGIN
    -- Check if we have embeddings available
    SELECT EXISTS (
        SELECT 1 FROM listings WHERE embedding IS NOT NULL LIMIT 1
    ) INTO has_embeddings;
    
    -- Try to generate embedding for search query (if text provided and embeddings exist)
    IF query_text IS NOT NULL AND query_text != '' AND has_embeddings THEN
        BEGIN
            -- Try to get embedding for search query
            SELECT embedding INTO query_embedding
            FROM ai.embeddings
            WHERE model = 'text-embedding-3-small'
            AND content = query_text
            LIMIT 1;
            
            -- If not found, try to generate
            IF query_embedding IS NULL THEN
                INSERT INTO ai.embeddings (model, content)
                VALUES ('text-embedding-3-small', query_text)
                RETURNING embedding INTO query_embedding;
            END IF;
        EXCEPTION
            WHEN OTHERS THEN
                -- If embedding generation fails, just use keyword search
                RAISE NOTICE 'Embedding generation failed, using keyword-only search: %', SQLERRM;
                query_embedding := NULL;
        END;
    END IF;
    
    -- Return hybrid or keyword-only results based on what's available
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
        -- Hybrid relevance score (graceful fallback)
        CASE 
            -- Hybrid: both keyword and semantic
            WHEN query_text IS NOT NULL AND query_text != '' 
                AND query_embedding IS NOT NULL AND l.embedding IS NOT NULL THEN
                (
                    keyword_weight * ts_rank(l.tsv, plainto_tsquery('english', query_text)) +
                    semantic_weight * (1 - (l.embedding <=> query_embedding))
                )::REAL
            -- Keyword only: no embeddings available
            WHEN query_text IS NOT NULL AND query_text != '' THEN
                ts_rank(l.tsv, plainto_tsquery('english', query_text))::REAL
            -- No search text: all equal
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
        -- Only active, non-archived, non-sold listings
        l.status = 'active'
        AND l.archived = false
        AND l.is_sold = false
        -- Text search filter (keyword OR semantic)
        AND (
            query_text IS NULL 
            OR query_text = '' 
            OR l.tsv @@ plainto_tsquery('english', query_text)  -- Keyword match
            OR (
                query_embedding IS NOT NULL 
                AND l.embedding IS NOT NULL 
                AND (l.embedding <=> query_embedding) < 0.5  -- Semantic similarity
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

-- Create simple wrapper for common searches
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION hybrid_search_listings TO authenticated;
GRANT EXECUTE ON FUNCTION quick_search TO authenticated;

-- Verify functions were created
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN ('hybrid_search_listings', 'quick_search')
ORDER BY routine_name;

-- SUCCESS MESSAGE & TESTING
DO $$
BEGIN
    RAISE NOTICE '✅ Step 7 Complete: Hybrid search function created';
    RAISE NOTICE '';
    RAISE NOTICE '🧪 TEST IT:';
    RAISE NOTICE 'Run: SELECT * FROM quick_search(''laptop'', 5);';
    RAISE NOTICE '';
    RAISE NOTICE 'Next Steps:';
    RAISE NOTICE '1. Test the function (see above)';
    RAISE NOTICE '2. Enable in app: AppConfig.enableHybridSearch = true';
    RAISE NOTICE '3. Run: create_similar_items_safe.sql';
END $$;

-- TEST IT:
-- SELECT title, category, relevance_score
-- FROM hybrid_search_listings(
--     query_text := 'laptop',
--     limit_count := 5
-- )
-- ORDER BY relevance_score DESC;

-- Compare hybrid vs keyword-only:
-- SELECT title, 
--     ts_rank(tsv, plainto_tsquery('english', 'laptop')) as keyword_score
-- FROM listings
-- WHERE tsv @@ plainto_tsquery('english', 'laptop')
-- AND status = 'active' AND archived = false
-- ORDER BY keyword_score DESC
-- LIMIT 5;

-- ROLLBACK INSTRUCTIONS (if needed):
/*
DROP FUNCTION IF EXISTS hybrid_search_listings;
DROP FUNCTION IF EXISTS quick_search;
*/

