-- Fix search_listings function to include photo and photos fields
-- This ensures search results display images properly

-- Drop the existing function if it exists
DROP FUNCTION IF EXISTS search_listings(
    query_text TEXT,
    category_filter TEXT,
    min_price DECIMAL,
    max_price DECIMAL,
    intent_filter TEXT,
    service_location_filter TEXT,
    trust_min INTEGER,
    trust_max INTEGER,
    sort_by TEXT,
    limit_count INTEGER,
    offset_count INTEGER
);

-- Create the updated search_listings function with photo fields
CREATE OR REPLACE FUNCTION search_listings(
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
BEGIN
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
        -- Calculate relevance score based on text search if query provided
        CASE 
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
        -- Only active, non-archived, non-sold listings
        l.status = 'active'
        AND l.archived = false
        AND l.is_sold = false
        -- Text search filter (if provided)
        AND (
            query_text IS NULL 
            OR query_text = '' 
            OR l.tsv @@ plainto_tsquery('english', query_text)
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
                ts_rank(l.tsv, plainto_tsquery('english', query_text))
            ELSE 0
        END DESC,
        CASE WHEN sort_by = 'newest' THEN l.created_at END DESC,
        CASE WHEN sort_by = 'price_low' THEN l.price END ASC,
        CASE WHEN sort_by = 'price_high' THEN l.price END DESC,
        CASE WHEN sort_by = 'trust_score' THEN u.trust_score END DESC,
        l.created_at DESC -- Default fallback sort
    LIMIT limit_count
    OFFSET offset_count;
END;
$$;

-- Grant execute permission to authenticated users
GRANT EXECUTE ON FUNCTION search_listings TO authenticated;

-- Test the function
SELECT 
    id, 
    title, 
    photo,
    array_length(photos, 1) as photo_count
FROM search_listings(
    query_text := 'Test',
    limit_count := 5
);

