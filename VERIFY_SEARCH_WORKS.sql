-- Verify the Improved Search Function Works
-- This WILL return rows so you can see it's working

-- Check 1: Does the function exist?
SELECT 
    routine_name,
    '✅ Function exists' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name = 'search_listings';

-- Check 2: Test the search with a simple query
-- This should return actual listings
SELECT 
    title,
    category,
    price,
    relevance_score
FROM search_listings('e', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0)
ORDER BY relevance_score DESC;

-- Check 3: Test partial word matching  
-- This tests if partial matching works
SELECT 
    title,
    category,
    price
FROM search_listings('book', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0)
ORDER BY relevance_score DESC;

-- If these return rows with your actual listings, IT'S WORKING! ✅

