-- FIX SEARCH FUNCTION TO MATCH ACTUAL DATABASE SCHEMA
-- Run this to update the search function with correct column names

DROP FUNCTION IF EXISTS public.search_listings CASCADE;

CREATE FUNCTION public.search_listings(
    query_text text DEFAULT NULL,
    category_filter text DEFAULT NULL,
    min_price numeric DEFAULT NULL,
    max_price numeric DEFAULT NULL,
    intent_filter text DEFAULT NULL,
    service_location_filter text DEFAULT NULL,
    trust_min integer DEFAULT NULL,
    trust_max integer DEFAULT NULL,
    sort_by text DEFAULT 'relevance',
    limit_count integer DEFAULT 20,
    offset_count integer DEFAULT 0
)
RETURNS TABLE(
    id uuid,
    user_id uuid,
    user_name text,
    user_email text,
    user_avatar_url text,
    user_trust_score integer,
    title text,
    description text,
    price numeric,
    category text,
    condition text,  -- Keep this for Swift compatibility, but return NULL
    images jsonb,    -- Convert photo to JSON array for Swift compatibility
    intent text,
    status text,
    archived boolean,
    service_location character varying,
    created_at timestamptz,
    relevance_score real
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id,
        l.user_id,
        u.name as user_name,
        u.email as user_email,
        u.profile_pic as user_avatar_url,
        u.trust_score as user_trust_score,
        l.title,
        l.description,
        l.price,
        l.category,
        NULL::text as condition,  -- Not in your schema
        CASE 
            WHEN l.photo IS NOT NULL THEN jsonb_build_array(l.photo)
            ELSE NULL::jsonb
        END as images,
        l.intent,
        l.status,
        l.archived,
        l.service_location,
        l.created_at,
        CASE 
            WHEN query_text IS NOT NULL AND LENGTH(query_text) > 0 THEN
                ts_rank(l.tsv, plainto_tsquery('english', query_text))
            ELSE 1.0
        END as relevance_score
    FROM public.listings l
    JOIN public.users u ON l.user_id = u.id
    WHERE l.status = 'active'
    AND l.archived = false
    AND (query_text IS NULL OR LENGTH(query_text) = 0 OR l.tsv @@ plainto_tsquery('english', query_text))
    AND (category_filter IS NULL OR l.category = category_filter)
    AND (min_price IS NULL OR l.price >= min_price)
    AND (max_price IS NULL OR l.price <= max_price)
    AND (intent_filter IS NULL OR l.intent = intent_filter)
    AND (service_location_filter IS NULL OR l.service_location = service_location_filter)
    AND (trust_min IS NULL OR u.trust_score >= trust_min)
    AND (trust_max IS NULL OR u.trust_score <= trust_max)
    ORDER BY
        CASE 
            WHEN sort_by = 'relevance' AND query_text IS NOT NULL THEN 
                ts_rank(l.tsv, plainto_tsquery('english', query_text))
            ELSE NULL
        END DESC NULLS LAST,
        CASE WHEN sort_by = 'date_desc' THEN l.created_at END DESC,
        CASE WHEN sort_by = 'date_asc' THEN l.created_at END ASC,
        CASE WHEN sort_by = 'price_asc' THEN l.price END ASC,
        CASE WHEN sort_by = 'price_desc' THEN l.price END DESC,
        CASE WHEN sort_by = 'trust_desc' THEN u.trust_score END DESC,
        l.created_at DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.search_listings TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_listings TO anon;

-- Test the fixed function
SELECT 'Search function updated to match actual database schema!' as message;

-- Test with simple search
SELECT title, description, category 
FROM search_listings('', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);

-- Count total searchable listings
SELECT COUNT(*) as total_listings_found
FROM search_listings('', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 100, 0);
