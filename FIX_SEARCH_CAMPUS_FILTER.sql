-- Fix Search to Respect Campus Filtering
-- This ensures search only shows listings from user's campus
-- Run this to replace the search function with campus-aware version

DROP FUNCTION IF EXISTS search_listings CASCADE;

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
    offset_count INTEGER DEFAULT 0,
    campus_filter TEXT DEFAULT NULL  -- NEW: Campus filtering parameter
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
    -- Prepare search pattern for partial matching
    IF query_text IS NOT NULL AND query_text != '' THEN
        query_text := LOWER(TRIM(query_text));
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
        -- Smart relevance scoring
        CASE 
            WHEN query_text IS NOT NULL AND query_text != '' THEN
                (
                    -- Exact title match: highest score (10 points)
                    CASE WHEN LOWER(l.title) = query_text THEN 10.0
                    -- Title starts with query: high score (8 points)
                    WHEN LOWER(l.title) LIKE (query_text || '%') THEN 8.0
                    -- Title contains query: good score (5 points)
                    WHEN LOWER(l.title) LIKE search_pattern THEN 5.0
                    -- Category exact match: medium score (4 points)
                    WHEN LOWER(l.category) = query_text THEN 4.0
                    -- Category contains query: (3 points)
                    WHEN LOWER(l.category) LIKE search_pattern THEN 3.0
                    -- Description contains: lower score (2 points)
                    WHEN LOWER(COALESCE(l.description, '')) LIKE search_pattern THEN 2.0
                    -- Full-text search match: base score (1 point)
                    WHEN l.tsv @@ plainto_tsquery('english', query_text) THEN 1.0
                    ELSE 0.5
                    END +
                    -- Bonus for availability (1 point)
                    CASE WHEN COALESCE(l.quantity_available, 1) > 0 THEN 1.0 ELSE 0.0 END
                )::REAL
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
        -- CAMPUS FILTER (CRITICAL!)
        AND (campus_filter IS NULL OR u.campus = campus_filter)
        -- Multi-method text search (finds partial matches)
        AND (
            query_text IS NULL 
            OR query_text = '' 
            -- Exact or partial title match
            OR LOWER(l.title) LIKE search_pattern
            -- Exact or partial category match
            OR LOWER(l.category) LIKE search_pattern
            -- Partial description match
            OR LOWER(COALESCE(l.description, '')) LIKE search_pattern
            -- Full-text search (word stems)
            OR l.tsv @@ plainto_tsquery('english', query_text)
        )
        -- Other filters
        AND (category_filter IS NULL OR l.category = category_filter)
        AND (min_price IS NULL OR l.price >= min_price)
        AND (max_price IS NULL OR l.price <= max_price)
        AND (intent_filter IS NULL OR l.intent = intent_filter)
        AND (service_location_filter IS NULL OR l.service_location = service_location_filter)
        AND (trust_min IS NULL OR u.trust_score >= trust_min)
        AND (trust_max IS NULL OR u.trust_score <= trust_max)
    ORDER BY
        -- Sort by relevance when searching
        CASE 
            WHEN sort_by = 'relevance' AND query_text IS NOT NULL AND query_text != '' THEN
                relevance_score
        END DESC NULLS LAST,
        -- Other sort options
        CASE WHEN sort_by = 'price_asc' THEN l.price END ASC NULLS LAST,
        CASE WHEN sort_by = 'price_desc' THEN l.price END DESC NULLS LAST,
        CASE WHEN sort_by = 'recent' OR sort_by IS NULL THEN l.created_at END DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$;

GRANT EXECUTE ON FUNCTION search_listings TO authenticated;

-- Verify
SELECT 'search_listings function updated with campus filter' as status;

