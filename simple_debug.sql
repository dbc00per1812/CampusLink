-- SIMPLE DEBUG - Check what functions exist
-- Run this first to see what's in the database

-- 1. Check what search-related functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%search%'
ORDER BY routine_name;

-- 2. Test search_listings function with guitar
SELECT COUNT(*) as guitar_search_test
FROM search_listings('guitar', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);

-- 3. Check what's actually in your listings
SELECT 
    title, 
    description,
    category
FROM public.listings 
WHERE status = 'active' AND archived = false
LIMIT 5;
