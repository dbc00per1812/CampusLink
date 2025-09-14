-- Improved Search Functions for Better Matching
-- This script enhances search to support partial matches and better relevance

-- 1. Drop existing functions to replace with improved versions
DROP FUNCTION IF EXISTS search_listings;
DROP FUNCTION IF EXISTS get_search_suggestions;

-- 2. Create improved search_listings function with partial matching
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
    -- Listing fields
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
    service_location varchar,
    service_availability text,
    status text,
    intent text,
    budget_min numeric,
    budget_max numeric,
    expires_at timestamptz,
    archived boolean,
    slots_available integer,
    max_bookings_per_slot integer,
    -- User fields
    user_name text,
    user_email text,
    user_bio text,
    user_profile_pic text,
    user_trust_score integer,
    user_created_at timestamptz,
    -- Search fields
    relevance_score real
)
LANGUAGE plpgsql
AS $$
DECLARE
    search_pattern text;
BEGIN
    -- Prepare search pattern for partial matching
    IF query_text IS NOT NULL AND query_text != '' THEN
        -- Create pattern for prefix:* matching (e.g., "lev" becomes "lev:*")
        search_pattern := regexp_replace(query_text, '\s+', ':* & ', 'g') || ':*';
    END IF;

    RETURN QUERY
    WITH search_query AS (
        SELECT 
            l.*,
            u.name as user_name,
            u.email as user_email,
            u.bio as user_bio,
            u.profile_pic as user_profile_pic,
            u.trust_score as user_trust_score,
            u.created_at as user_created_at,
            CASE 
                WHEN query_text IS NULL OR query_text = '' THEN 1.0
                -- Use multiple scoring methods for better relevance
                ELSE GREATEST(
                    -- Full text search with prefix matching
                    COALESCE(ts_rank(l.tsv, to_tsquery('simple', search_pattern)), 0),
                    -- Exact word match gets higher score
                    CASE WHEN l.tsv @@ plainto_tsquery('simple', query_text) THEN 2.0 ELSE 0 END,
                    -- Title contains search term (case insensitive)
                    CASE WHEN lower(l.title) LIKE '%' || lower(query_text) || '%' THEN 1.5 ELSE 0 END,
                    -- Title starts with search term (higher score for prefix match)
                    CASE WHEN lower(l.title) LIKE lower(query_text) || '%' THEN 1.8 ELSE 0 END,
                    -- Description contains search term
                    CASE WHEN lower(l.description) LIKE '%' || lower(query_text) || '%' THEN 0.5 ELSE 0 END
                )
            END as relevance_score
        FROM listings l
        JOIN users u ON l.user_id = u.id
        WHERE 
            l.status = 'active'
            AND l.archived = false
            AND l.is_sold = false
            AND (
                query_text IS NULL 
                OR query_text = '' 
                -- Multiple search conditions with OR for better matching
                OR l.tsv @@ to_tsquery('simple', search_pattern)  -- Prefix search
                OR l.tsv @@ plainto_tsquery('simple', query_text) -- Exact word search
                OR lower(l.title) LIKE '%' || lower(query_text) || '%' -- Title contains
                OR lower(l.description) LIKE '%' || lower(query_text) || '%' -- Description contains
            )
            AND (category_filter IS NULL OR l.category = category_filter)
            AND (min_price IS NULL OR l.price >= min_price)
            AND (max_price IS NULL OR l.price <= max_price)
            AND (intent_filter IS NULL OR l.intent = intent_filter)
            AND (service_location_filter IS NULL OR l.service_location = service_location_filter)
            AND (trust_min IS NULL OR u.trust_score >= trust_min)
            AND (trust_max IS NULL OR u.trust_score <= trust_max)
    )
    SELECT 
        sq.id,
        sq.user_id,
        sq.title,
        sq.description,
        sq.price,
        sq.category,
        sq.photo,
        sq.is_sold,
        sq.created_at,
        sq.listing_type,
        sq.service_type,
        sq.service_duration,
        sq.service_location,
        sq.service_availability,
        sq.status,
        sq.intent,
        sq.budget_min,
        sq.budget_max,
        sq.expires_at,
        sq.archived,
        sq.slots_available,
        sq.max_bookings_per_slot,
        sq.user_name,
        sq.user_email,
        sq.user_bio,
        sq.user_profile_pic,
        sq.user_trust_score,
        sq.user_created_at,
        sq.relevance_score
    FROM search_query sq
    WHERE sq.relevance_score > 0  -- Only return results with some relevance
    ORDER BY
        CASE 
            WHEN sort_by = 'relevance' THEN sq.relevance_score
            WHEN sort_by = 'trust_score' THEN sq.user_trust_score::real
            ELSE NULL
        END DESC NULLS LAST,
        CASE 
            WHEN sort_by = 'price_low' THEN sq.price
            ELSE NULL
        END ASC NULLS LAST,
        CASE 
            WHEN sort_by = 'price_high' THEN sq.price
            ELSE NULL
        END DESC NULLS LAST,
        CASE 
            WHEN sort_by = 'newest' THEN sq.created_at
            ELSE NULL
        END DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$;

-- 3. Create improved get_search_suggestions function
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
        -- Get matching titles (both prefix and contains)
        SELECT 
            l.title as suggestion,
            l.category,
            COUNT(*) as count,
            -- Prioritize prefix matches
            CASE WHEN lower(l.title) LIKE lower(query_text) || '%' THEN 1 ELSE 2 END as priority
        FROM listings l
        WHERE 
            l.status = 'active' 
            AND l.archived = false
            AND l.is_sold = false
            AND (
                lower(l.title) LIKE lower(query_text) || '%'  -- Prefix match
                OR lower(l.title) LIKE '%' || lower(query_text) || '%'  -- Contains match
            )
        GROUP BY l.title, l.category, priority
        
        UNION
        
        -- Get matching categories
        SELECT 
            DISTINCT l.category as suggestion,
            l.category,
            COUNT(*) as count,
            3 as priority  -- Categories have lower priority than titles
        FROM listings l
        WHERE 
            l.status = 'active' 
            AND l.archived = false
            AND l.is_sold = false
            AND l.category IS NOT NULL
            AND lower(l.category) LIKE '%' || lower(query_text) || '%'
        GROUP BY l.category
    )
    SELECT 
        s.suggestion,
        s.category,
        s.count
    FROM suggestions s
    ORDER BY s.priority, s.count DESC
    LIMIT limit_count;
END;
$$;

-- 4. Grant permissions
GRANT EXECUTE ON FUNCTION search_listings TO authenticated;
GRANT EXECUTE ON FUNCTION get_search_suggestions TO authenticated;

-- 5. Create additional indexes for LIKE queries (if not exists)
CREATE INDEX IF NOT EXISTS idx_listings_title_lower ON listings(lower(title));
CREATE INDEX IF NOT EXISTS idx_listings_description_lower ON listings(lower(description));

-- 6. Create trigram index for fuzzy search (requires pg_trgm extension)
-- This enables similarity searches and better partial matching
CREATE EXTENSION IF NOT EXISTS pg_trgm;
CREATE INDEX IF NOT EXISTS idx_listings_title_trgm ON listings USING gin (title gin_trgm_ops);
CREATE INDEX IF NOT EXISTS idx_listings_description_trgm ON listings USING gin (description gin_trgm_ops);
