-- Enable Partial/Prefix Search for CampusLink
-- This update allows character-by-character matching so partial words show results
-- Example: typing "lap" will now find "laptop", "lapis", etc.

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

-- Create the updated search_listings function with partial matching
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
DECLARE
    search_pattern TEXT;
BEGIN
    -- Prepare search pattern for ILIKE (case-insensitive partial matching)
    IF query_text IS NOT NULL AND query_text != '' THEN
        search_pattern := '%' || query_text || '%';
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
        -- Calculate relevance score with partial matching priority
        CASE 
            WHEN query_text IS NOT NULL AND query_text != '' THEN
                -- Exact match gets highest score
                CASE WHEN LOWER(l.title) = LOWER(query_text) THEN 10.0
                     WHEN LOWER(l.description) = LOWER(query_text) THEN 9.0
                     WHEN LOWER(l.category) = LOWER(query_text) THEN 8.0
                -- Title starts with query gets high score
                     WHEN LOWER(l.title) LIKE LOWER(query_text) || '%' THEN 7.0
                -- Word boundary match in title (after space)
                     WHEN LOWER(l.title) LIKE '% ' || LOWER(query_text) || '%' THEN 6.0
                -- Contains in title gets good score
                     WHEN LOWER(l.title) LIKE '%' || LOWER(query_text) || '%' THEN 5.0
                -- Category starts with query
                     WHEN LOWER(l.category) LIKE LOWER(query_text) || '%' THEN 4.0
                -- Category contains query
                     WHEN LOWER(l.category) LIKE '%' || LOWER(query_text) || '%' THEN 3.0
                -- Description starts with query
                     WHEN LOWER(l.description) LIKE LOWER(query_text) || '%' THEN 2.0
                -- Contains in description gets lower score
                     WHEN LOWER(l.description) LIKE '%' || LOWER(query_text) || '%' THEN 1.0
                     ELSE 0.5
                END
            ELSE 
                1.0
        END::REAL as relevance_score,
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
        -- Partial text search filter using ILIKE (case-insensitive)
        AND (
            query_text IS NULL 
            OR query_text = '' 
            OR LOWER(l.title) LIKE search_pattern
            OR LOWER(l.description) LIKE search_pattern
            OR LOWER(l.category) LIKE search_pattern
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
        -- Primary sort by relevance when searching with text
        CASE 
            WHEN sort_by = 'relevance' AND query_text IS NOT NULL AND query_text != '' THEN
                -- Use the calculated relevance score
                CASE WHEN LOWER(l.title) = LOWER(query_text) THEN 10.0
                     WHEN LOWER(l.description) = LOWER(query_text) THEN 9.0
                     WHEN LOWER(l.category) = LOWER(query_text) THEN 8.0
                     WHEN LOWER(l.title) LIKE LOWER(query_text) || '%' THEN 7.0
                     WHEN LOWER(l.title) LIKE '% ' || LOWER(query_text) || '%' THEN 6.0
                     WHEN LOWER(l.title) LIKE '%' || LOWER(query_text) || '%' THEN 5.0
                     WHEN LOWER(l.category) LIKE LOWER(query_text) || '%' THEN 4.0
                     WHEN LOWER(l.category) LIKE '%' || LOWER(query_text) || '%' THEN 3.0
                     WHEN LOWER(l.description) LIKE LOWER(query_text) || '%' THEN 2.0
                     WHEN LOWER(l.description) LIKE '%' || LOWER(query_text) || '%' THEN 1.0
                     ELSE 0.5
                END
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

-- Test the function with partial matching
-- This should now find results even with partial words
SELECT 
    id, 
    title,
    relevance_score,
    photo,
    array_length(photos, 1) as photo_count
FROM search_listings(
    query_text := 'lap',  -- Should now find "laptop", "lapis", etc.
    limit_count := 5
)
ORDER BY relevance_score DESC;

-- Additional test examples:
-- search_listings('tex') should find "textbook", "texas", etc.
-- search_listings('tut') should find "tutoring", "tutorial", etc.
-- search_listings('fur') should find "furniture", "furry", etc.

