-- COMPREHENSIVE SEARCH FIX
-- This addresses both the missing suggestions function and keyword search issues

-- 1. First, add the missing get_search_suggestions function
CREATE OR REPLACE FUNCTION public.get_search_suggestions(
    query_text text,
    limit_count integer DEFAULT 5
)
RETURNS TABLE(
    suggestion text,
    type text,
    count bigint
)
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
BEGIN
    RETURN QUERY
    WITH title_matches AS (
        SELECT DISTINCT
            title as suggestion,
            'title' as type,
            COUNT(*) as count
        FROM public.listings
        WHERE status = 'active'
        AND archived = false
        AND title ILIKE '%' || query_text || '%'
        GROUP BY title
        ORDER BY count DESC
        LIMIT limit_count
    ),
    category_matches AS (
        SELECT DISTINCT
            category as suggestion,
            'category' as type,
            COUNT(*) as count
        FROM public.listings
        WHERE status = 'active'
        AND archived = false
        AND category ILIKE '%' || query_text || '%'
        GROUP BY category
        ORDER BY count DESC
        LIMIT limit_count
    )
    SELECT * FROM (
        SELECT * FROM title_matches
        UNION ALL
        SELECT * FROM category_matches
    ) combined
    ORDER BY count DESC
    LIMIT limit_count;
END;
$$;

-- 2. Update search_listings function with better keyword matching
CREATE OR REPLACE FUNCTION public.search_listings(
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
    condition text,
    images jsonb,
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
        NULL::text as condition,
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
                -- Use both tsv search AND fallback text search for better coverage
                GREATEST(
                    ts_rank(l.tsv, plainto_tsquery('english', query_text)),
                    CASE 
                        WHEN (l.title ILIKE '%' || query_text || '%' OR l.description ILIKE '%' || query_text || '%') 
                        THEN 0.5 
                        ELSE 0.0 
                    END
                )
            ELSE 1.0
        END as relevance_score
    FROM public.listings l
    JOIN public.users u ON l.user_id = u.id
    WHERE l.status = 'active'
    AND l.archived = false
    AND (
        query_text IS NULL 
        OR LENGTH(query_text) = 0 
        OR l.tsv @@ plainto_tsquery('english', query_text)
        OR l.title ILIKE '%' || query_text || '%'
        OR l.description ILIKE '%' || query_text || '%'
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
            WHEN sort_by = 'relevance' AND query_text IS NOT NULL THEN 
                GREATEST(
                    ts_rank(l.tsv, plainto_tsquery('english', query_text)),
                    CASE 
                        WHEN (l.title ILIKE '%' || query_text || '%' OR l.description ILIKE '%' || query_text || '%') 
                        THEN 0.5 
                        ELSE 0.0 
                    END
                )
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

-- 3. Grant permissions to both functions
GRANT EXECUTE ON FUNCTION public.search_listings TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_listings TO anon;
GRANT EXECUTE ON FUNCTION public.get_search_suggestions TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_search_suggestions TO anon;

-- 4. Test both functions
SELECT 'Both search functions updated with improved keyword matching!' as message;

-- Test search_listings with guitar
SELECT COUNT(*) as guitar_results FROM search_listings('guitar', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 10, 0);

-- Test search_suggestions
SELECT * FROM get_search_suggestions('guitar', 5);

-- Test with other potential keywords
SELECT title, description FROM search_listings('book', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);
SELECT title, description FROM search_listings('help', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);
