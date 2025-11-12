-- STEP 8: Create Similar Items Functions (PRODUCTION SAFE)
-- Risk: LOW - Just creates functions, doesn't change data
-- Rollback: Easy - just drop the functions
-- Estimated time: 5 seconds
-- Impact: NONE until you call these functions

-- Main similar items function
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
    -- Get the embedding and category of the target listing
    SELECT embedding, category
    INTO target_embedding, target_category
    FROM listings
    WHERE id = target_listing_id;
    
    -- If no embedding exists, return empty (graceful handling)
    IF target_embedding IS NULL THEN
        RAISE NOTICE 'No embedding found for listing %. Run backfill_embeddings_safe.sql first.', target_listing_id;
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
        -- Similarity score: 1 = identical, 0 = completely different
        (1 - (l.embedding <=> target_embedding))::REAL as similarity_score,
        u.name as user_name,
        u.campus as user_campus
    FROM listings l
    INNER JOIN users u ON l.user_id = u.id::uuid
    WHERE l.id != target_listing_id  -- Exclude the target listing
    AND l.status = 'active'
    AND l.archived = false
    AND l.is_sold = false
    AND l.embedding IS NOT NULL  -- Only listings with embeddings
    ORDER BY 
        -- Primary: similarity score
        l.embedding <=> target_embedding ASC,
        -- Secondary: prefer same category
        CASE WHEN l.category = target_category THEN 0 ELSE 1 END,
        -- Tertiary: more recent
        l.created_at DESC
    LIMIT limit_count;
END;
$$;

-- Simpler version for UI cards
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
        id,
        title,
        price,
        photo,
        category,
        similarity_score
    FROM get_similar_listings(target_listing_id, limit_count);
$$;

-- Same-category only version
CREATE OR REPLACE FUNCTION get_similar_listings_same_category(
    target_listing_id UUID,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    price DECIMAL,
    photo TEXT,
    similarity_score REAL
)
LANGUAGE plpgsql
AS $$
DECLARE
    target_embedding vector(384);
    target_category TEXT;
BEGIN
    -- Get the embedding and category
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
        l.title,
        l.price,
        l.photo,
        (1 - (l.embedding <=> target_embedding))::REAL as similarity_score
    FROM listings l
    WHERE l.id != target_listing_id
    AND l.category = target_category  -- Same category ONLY
    AND l.status = 'active'
    AND l.archived = false
    AND l.is_sold = false
    AND l.embedding IS NOT NULL
    ORDER BY l.embedding <=> target_embedding ASC
    LIMIT limit_count;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION get_similar_listings TO authenticated;
GRANT EXECUTE ON FUNCTION get_similar_listings_simple TO authenticated;
GRANT EXECUTE ON FUNCTION get_similar_listings_same_category TO authenticated;

-- Verify functions were created
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%similar%'
ORDER BY routine_name;

-- SUCCESS MESSAGE & TESTING
DO $$
DECLARE
    sample_listing_id UUID;
BEGIN
    -- Get a sample listing ID for testing
    SELECT id INTO sample_listing_id
    FROM listings
    WHERE status = 'active' 
    AND archived = false
    AND embedding IS NOT NULL
    LIMIT 1;
    
    RAISE NOTICE '✅ Step 8 Complete: Similar items functions created';
    RAISE NOTICE '';
    
    IF sample_listing_id IS NOT NULL THEN
        RAISE NOTICE '🧪 TEST IT:';
        RAISE NOTICE 'SELECT * FROM get_similar_listings_simple(''%''::uuid, 5);', sample_listing_id;
        RAISE NOTICE '';
        RAISE NOTICE 'Sample listing ID for testing: %', sample_listing_id;
    ELSE
        RAISE NOTICE '⚠️  No listings with embeddings found';
        RAISE NOTICE 'Run backfill_embeddings_safe.sql first';
    END IF;
    
    RAISE NOTICE '';
    RAISE NOTICE '✅ MIGRATION COMPLETE!';
    RAISE NOTICE '';
    RAISE NOTICE 'All database functions are ready.';
    RAISE NOTICE 'The Swift code is already integrated.';
    RAISE NOTICE '';
    RAISE NOTICE 'Enable in app:';
    RAISE NOTICE '  AppConfig.enableHybridSearch = true';
END $$;

-- TEST IT:
-- Get a random listing and find similar ones
/*
WITH sample AS (
    SELECT id, title, category
    FROM listings
    WHERE status = 'active' AND embedding IS NOT NULL
    LIMIT 1
)
SELECT 
    s.title as original_listing,
    s.category as original_category,
    sim.title as similar_listing,
    sim.category as similar_category,
    sim.similarity_score,
    ROUND(sim.similarity_score * 100) as similarity_percent
FROM sample s
CROSS JOIN LATERAL get_similar_listings_simple(s.id, 5) sim
ORDER BY sim.similarity_score DESC;
*/

-- ROLLBACK INSTRUCTIONS (if needed):
/*
DROP FUNCTION IF EXISTS get_similar_listings;
DROP FUNCTION IF EXISTS get_similar_listings_simple;
DROP FUNCTION IF EXISTS get_similar_listings_same_category;
*/

