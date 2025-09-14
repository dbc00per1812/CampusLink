-- Test if your database has searchable content
-- Run this in Supabase SQL Editor to see what you can search for

-- 1. Check how many active listings you have
SELECT COUNT(*) as total_active_listings 
FROM public.listings 
WHERE status = 'active' AND archived = false;

-- 2. See what listings exist and their search content
SELECT 
    title,
    description,
    category,
    intent,
    tsv
FROM public.listings 
WHERE status = 'active' AND archived = false
LIMIT 10;

-- 3. Test if the search function works with a simple query
SELECT COUNT(*) as matching_listings
FROM search_listings('book', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 10, 0);

-- 4. Try searching for any word from your actual listing titles
SELECT COUNT(*) as matching_listings
FROM search_listings('', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 10, 0);

-- 5. Check if tsv field is populated (should not be empty)
SELECT 
    title,
    CASE 
        WHEN tsv IS NULL THEN 'NULL'
        WHEN tsv = ''::tsvector THEN 'EMPTY' 
        ELSE 'HAS_CONTENT'
    END as tsv_status
FROM public.listings 
WHERE status = 'active' AND archived = false
LIMIT 5;
