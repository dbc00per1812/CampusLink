-- Quick test to see if search is working
-- Run this AFTER running create_search_functions.sql

-- Test 1: Check if the function exists
SELECT routine_name 
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name = 'search_listings';

-- Test 2: Try a simple search (should return results or empty set, not an error)
SELECT * FROM search_listings('test', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);

-- Test 3: Check if tsv column has index
SELECT indexname 
FROM pg_indexes 
WHERE tablename = 'listings' 
AND indexname LIKE '%tsv%';

-- If all three queries run without errors, search is properly set up!

