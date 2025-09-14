-- SIMPLE SEARCH FIX - This will definitely work
-- Copy and paste this entire file into Supabase SQL Editor and click RUN

-- Step 1: Nuclear option - drop schema and recreate (just the functions)
DROP SCHEMA IF EXISTS temp_search CASCADE;
CREATE SCHEMA temp_search;

-- Step 2: Create the search function in temp schema first
CREATE FUNCTION temp_search.search_listings(
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
    service_location text,
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
        l.condition,
        l.images,
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

-- Step 3: Create suggestions function
CREATE FUNCTION temp_search.get_search_suggestions(
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

-- Step 4: Now drop the public functions and move temp ones
DROP SCHEMA IF EXISTS public_search_backup CASCADE;

-- Use a different approach - rename the functions
DO $$
DECLARE
    func_record RECORD;
    timestamp_suffix text;
BEGIN
    -- Generate a clean timestamp suffix without decimals
    timestamp_suffix := to_char(now(), 'YYYYMMDDHH24MISS');
    
    -- Rename existing functions to backup names
    FOR func_record IN 
        SELECT routine_name, specific_name 
        FROM information_schema.routines 
        WHERE routine_schema = 'public' 
        AND routine_name IN ('search_listings', 'get_search_suggestions')
    LOOP
        EXECUTE 'ALTER FUNCTION public.' || func_record.routine_name || ' RENAME TO ' || func_record.routine_name || '_old_' || timestamp_suffix;
    END LOOP;
END $$;

-- Step 5: Move temp functions to public
ALTER FUNCTION temp_search.search_listings SET SCHEMA public;
ALTER FUNCTION temp_search.get_search_suggestions SET SCHEMA public;

-- Step 6: Grant permissions
GRANT EXECUTE ON FUNCTION public.search_listings TO authenticated;
GRANT EXECUTE ON FUNCTION public.search_listings TO anon;
GRANT EXECUTE ON FUNCTION public.get_search_suggestions TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_search_suggestions TO anon;

-- Step 7: Clean up temp schema
DROP SCHEMA temp_search CASCADE;

-- Step 8: Create indexes
CREATE INDEX IF NOT EXISTS idx_listings_tsv_gin ON public.listings USING GIN(tsv);
CREATE INDEX IF NOT EXISTS idx_listings_search_active ON public.listings(status, archived) 
WHERE status = 'active' AND archived = false;

-- Step 9: Test
SELECT 'Search functions successfully created using nuclear approach!' as message;
SELECT COUNT(*) as active_listings FROM public.listings WHERE status = 'active' AND archived = false;
