-- ADD MISSING get_search_suggestions FUNCTION
-- Run this to add the missing suggestions function that causes the refresh error

-- Create the get_search_suggestions function to match Swift expectations
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

-- Grant permissions
GRANT EXECUTE ON FUNCTION public.get_search_suggestions TO authenticated;
GRANT EXECUTE ON FUNCTION public.get_search_suggestions TO anon;

-- Test the suggestions function
SELECT 'get_search_suggestions function created!' as message;

-- Test with guitar
SELECT * FROM get_search_suggestions('guitar', 5);

-- Test with empty string (should return top suggestions)
SELECT * FROM get_search_suggestions('', 5);
