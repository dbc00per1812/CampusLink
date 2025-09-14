-- DEBUG SEARCH ISSUE - Step by step testing
-- Run this to see what's happening

-- 1. Test basic function call without any filters
SELECT COUNT(*) as total_without_filters
FROM search_listings(NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 10, 0);

-- 2. Test with empty string (should return all)
SELECT COUNT(*) as total_with_empty_string  
FROM search_listings('', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 10, 0);

-- 3. Test direct database query (what we expect to see)
SELECT COUNT(*) as direct_db_count
FROM public.listings l
JOIN public.users u ON l.user_id = u.id
WHERE l.status = 'active' AND l.archived = false;

-- 4. Test guitar search step by step
SELECT 
    l.title,
    l.description,
    l.status,
    l.archived,
    CASE WHEN l.tsv @@ plainto_tsquery('english', 'guitar') THEN 'TSV_MATCH' ELSE 'NO_TSV_MATCH' END as tsv_test,
    CASE WHEN l.title ILIKE '%guitar%' THEN 'TITLE_MATCH' ELSE 'NO_TITLE_MATCH' END as title_test
FROM public.listings l
WHERE l.title ILIKE '%guitar%' OR l.description ILIKE '%guitar%';

-- 5. Check if the function exists and what it returns for guitar
SELECT * FROM search_listings('guitar', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);

-- 6. Test the WHERE condition from our function manually
SELECT 
    l.title,
    l.status,
    l.archived,
    (l.status = 'active') as status_check,
    (l.archived = false) as archived_check,
    (l.tsv @@ plainto_tsquery('english', 'guitar') OR l.title ILIKE '%guitar%' OR l.description ILIKE '%guitar%') as search_condition
FROM public.listings l
WHERE l.title ILIKE '%guitar%';
