-- Create Similar Items Function
-- Finds listings similar to a given listing using vector embeddings
-- Run this in Supabase SQL Editor AFTER embeddings are set up
-- 
-- This enables "You might also like" features on listing detail pages

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
    
    -- If no embedding exists for target listing, return empty result
    IF target_embedding IS NULL THEN
        RAISE NOTICE 'No embedding found for listing %', target_listing_id;
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
    WHERE l.id != target_listing_id  -- Exclude the target listing itself
    AND l.status = 'active'
    AND l.archived = false
    AND l.is_sold = false
    AND l.embedding IS NOT NULL
    -- Optionally prefer items from the same category (but don't require it)
    ORDER BY 
        -- Primary sort: similarity score
        l.embedding <=> target_embedding ASC,
        -- Secondary sort: prefer same category
        CASE WHEN l.category = target_category THEN 0 ELSE 1 END,
        -- Tertiary sort: more recent listings
        l.created_at DESC
    LIMIT limit_count;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_similar_listings TO authenticated;

-- Create a simpler version that returns just essential info for UI cards
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

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_similar_listings_simple TO authenticated;

-- Helper function to get similar items within the same category
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
    -- Get the embedding and category of the target listing
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
    AND l.category = target_category  -- MUST be same category
    AND l.status = 'active'
    AND l.archived = false
    AND l.is_sold = false
    AND l.embedding IS NOT NULL
    ORDER BY l.embedding <=> target_embedding ASC
    LIMIT limit_count;
END;
$$;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION get_similar_listings_same_category TO authenticated;

-- Verify the functions were created
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%similar%'
ORDER BY routine_name;

-- Test the similar items function
-- Uncomment to test with your data:
-- SELECT title, category, similarity_score
-- FROM get_similar_listings(
--     (SELECT id FROM listings WHERE status = 'active' AND embedding IS NOT NULL LIMIT 1)::uuid,
--     10
-- )
-- ORDER BY similarity_score DESC;

-- Example: Find items similar to a specific listing
-- Replace the UUID with an actual listing ID:
-- SELECT 
--     title,
--     category,
--     price,
--     similarity_score,
--     ROUND(similarity_score * 100) as similarity_percent
-- FROM get_similar_listings_simple(
--     'REPLACE-WITH-ACTUAL-UUID'::uuid,
--     5
-- )
-- ORDER BY similarity_score DESC;

