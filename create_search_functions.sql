-- Create Search Functions for CampusLink
-- Run this in your Supabase SQL editor to enable search functionality

-- 1. Create GIN index on tsv column for fast full-text search
CREATE INDEX IF NOT EXISTS idx_listings_tsv ON listings USING gin(tsv);

-- 2. Create performance indexes
CREATE INDEX IF NOT EXISTS idx_listings_active ON listings(status, archived) WHERE status = 'active' AND archived = false;
CREATE INDEX IF NOT EXISTS idx_listings_category ON listings(category) WHERE category IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_price ON listings(price) WHERE price IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_location ON listings(service_location) WHERE service_location IS NOT NULL;
CREATE INDEX IF NOT EXISTS idx_listings_intent ON listings(intent);
CREATE INDEX IF NOT EXISTS idx_listings_created ON listings(created_at DESC);

-- 3. Drop existing function if it exists (in case of signature changes)
DROP FUNCTION IF EXISTS search_listings;

-- Create search_listings function
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
BEGIN
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
                ELSE ts_rank(l.tsv, plainto_tsquery('simple', query_text))
            END as relevance_score
        FROM listings l
        JOIN users u ON l.user_id = u.id
        WHERE 
            l.status = 'active'
            AND l.archived = false
            AND l.is_sold = false
            AND (query_text IS NULL OR query_text = '' OR l.tsv @@ plainto_tsquery('simple', query_text))
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

-- 4. Drop existing function if it exists
DROP FUNCTION IF EXISTS get_search_suggestions;

-- Create get_search_suggestions function
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
        -- Get matching titles
        SELECT 
            l.title as suggestion,
            l.category,
            COUNT(*) as count
        FROM listings l
        WHERE 
            l.status = 'active' 
            AND l.archived = false
            AND l.is_sold = false
            AND lower(l.title) LIKE lower(query_text || '%')
        GROUP BY l.title, l.category
        
        UNION
        
        -- Get matching categories
        SELECT 
            DISTINCT l.category as suggestion,
            l.category,
            COUNT(*) as count
        FROM listings l
        WHERE 
            l.status = 'active' 
            AND l.archived = false
            AND l.is_sold = false
            AND l.category IS NOT NULL
            AND lower(l.category) LIKE lower(query_text || '%')
        GROUP BY l.category
    )
    SELECT 
        s.suggestion,
        s.category,
        s.count
    FROM suggestions s
    ORDER BY s.count DESC
    LIMIT limit_count;
END;
$$;

-- 5. Grant permissions
GRANT EXECUTE ON FUNCTION search_listings TO authenticated;
GRANT EXECUTE ON FUNCTION get_search_suggestions TO authenticated;

-- 6. Update tsv column for existing listings (if any exist without tsv)
UPDATE listings 
SET tsv = to_tsvector('simple', COALESCE(title, '') || ' ' || COALESCE(description, ''))
WHERE tsv IS NULL;

-- 7. Create trigger to automatically update tsv on insert/update
CREATE OR REPLACE FUNCTION update_listing_tsv()
RETURNS trigger AS $$
BEGIN
    NEW.tsv := to_tsvector('simple', COALESCE(NEW.title, '') || ' ' || COALESCE(NEW.description, ''));
    RETURN NEW;
END;
$$ LANGUAGE plpgsql;

DROP TRIGGER IF EXISTS listings_tsv_trigger ON listings;
CREATE TRIGGER listings_tsv_trigger
BEFORE INSERT OR UPDATE OF title, description ON listings
FOR EACH ROW
EXECUTE FUNCTION update_listing_tsv();
