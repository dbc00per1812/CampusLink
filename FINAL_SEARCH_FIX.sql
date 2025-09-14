-- FINAL SEARCH FIX - Handles type mismatches
-- Run this in Supabase SQL Editor

-- Drop existing functions
DROP FUNCTION IF EXISTS search_listings;
DROP FUNCTION IF EXISTS get_search_suggestions;

-- Create search function with correct types
CREATE OR REPLACE FUNCTION search_listings(
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
    title text,
    description text,
    price numeric,
    category text,
    photo text,
    is_sold boolean,
    created_at timestamptz,
    listing_type varchar,
    service_type text,
    service_duration text,
    service_location text,  -- Changed from varchar to text
    service_availability text,
    status text,
    intent text,
    budget_min numeric,
    budget_max numeric,
    expires_at timestamptz,
    archived boolean,
    slots_available integer,
    max_bookings_per_slot integer,
    user_name text,
    user_email text,
    user_bio text,
    user_profile_pic text,
    user_trust_score integer,
    user_created_at timestamptz,
    relevance_score real
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    SELECT 
        l.id,
        l.user_id,
        l.title::text,
        l.description::text,
        l.price,
        l.category::text,
        l.photo::text,
        l.is_sold,
        l.created_at,
        l.listing_type,
        l.service_type::text,
        l.service_duration::text,
        l.service_location::text,  -- Explicit cast to text
        l.service_availability::text,
        l.status::text,
        l.intent::text,
        l.budget_min,
        l.budget_max,
        l.expires_at,
        l.archived,
        l.slots_available,
        l.max_bookings_per_slot,
        u.name::text as user_name,
        u.email::text as user_email,
        u.bio::text as user_bio,
        u.profile_pic::text as user_profile_pic,
        u.trust_score as user_trust_score,
        u.created_at as user_created_at,
        CASE 
            WHEN query_text IS NULL OR query_text = '' THEN 1.0
            WHEN lower(l.title) = lower(query_text) THEN 3.0
            WHEN lower(l.title) LIKE lower(query_text) || '%' THEN 2.0
            WHEN lower(l.title) LIKE '%' || lower(query_text) || '%' THEN 1.5
            WHEN lower(COALESCE(l.description, '')) LIKE '%' || lower(query_text) || '%' THEN 0.5
            ELSE 0.1
        END::real as relevance_score
    FROM listings l
    JOIN users u ON l.user_id = u.id
    WHERE 
        l.status = 'active'
        AND l.archived = false
        AND l.is_sold = false
        AND (
            query_text IS NULL 
            OR query_text = '' 
            OR l.title ILIKE '%' || query_text || '%'
            OR l.description ILIKE '%' || query_text || '%'
            OR l.category ILIKE '%' || query_text || '%'
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
            WHEN sort_by = 'relevance' THEN 
                CASE 
                    WHEN query_text IS NULL OR query_text = '' THEN 1.0
                    WHEN lower(l.title) = lower(query_text) THEN 3.0
                    WHEN lower(l.title) LIKE lower(query_text) || '%' THEN 2.0
                    WHEN lower(l.title) LIKE '%' || lower(query_text) || '%' THEN 1.5
                    WHEN lower(COALESCE(l.description, '')) LIKE '%' || lower(query_text) || '%' THEN 0.5
                    ELSE 0.1
                END
            WHEN sort_by = 'trust_score' THEN u.trust_score::real
            ELSE NULL
        END DESC NULLS LAST,
        CASE 
            WHEN sort_by = 'price_low' THEN l.price
            ELSE NULL
        END ASC NULLS LAST,
        CASE 
            WHEN sort_by = 'price_high' THEN l.price
            ELSE NULL
        END DESC NULLS LAST,
        CASE 
            WHEN sort_by = 'newest' THEN l.created_at
            ELSE NULL
        END DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$;

-- Create suggestions function
CREATE OR REPLACE FUNCTION get_search_suggestions(
    query_text text,
    limit_count integer DEFAULT 10
)
RETURNS TABLE(
    suggestion text,
    category text,
    count bigint
)
LANGUAGE plpgsql
AS $$
BEGIN
    RETURN QUERY
    WITH suggestions AS (
        SELECT 
            l.title::text as suggestion,
            l.category::text,
            COUNT(*) as count
        FROM listings l
        WHERE 
            l.status = 'active' 
            AND l.archived = false
            AND l.is_sold = false
            AND l.title ILIKE '%' || query_text || '%'
        GROUP BY l.title, l.category
        
        UNION
        
        SELECT 
            DISTINCT l.category::text as suggestion,
            l.category::text,
            COUNT(*) as count
        FROM listings l
        WHERE 
            l.status = 'active' 
            AND l.archived = false
            AND l.is_sold = false
            AND l.category IS NOT NULL
            AND l.category ILIKE '%' || query_text || '%'
        GROUP BY l.category
    )
    SELECT 
        s.suggestion,
        s.category,
        s.count
    FROM suggestions s
    ORDER BY 
        CASE 
            WHEN lower(s.suggestion) = lower(query_text) THEN 1
            WHEN lower(s.suggestion) LIKE lower(query_text) || '%' THEN 2
            ELSE 3
        END,
        s.count DESC
    LIMIT limit_count;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION search_listings TO authenticated;
GRANT EXECUTE ON FUNCTION get_search_suggestions TO authenticated;

-- Test it
SELECT 'Search functions created!' as status;
