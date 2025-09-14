-- DEBUG SEARCH FUNCTIONS
-- Run this to check what functions exist and test them

-- 1. Check what search-related functions exist
SELECT 
    routine_name,
    routine_type,
    data_type as return_type
FROM information_schema.routines 
WHERE routine_schema = 'public' 
AND routine_name LIKE '%search%'
ORDER BY routine_name;

-- 2. Check parameters for search_listings function
SELECT 
    routine_name,
    parameter_name,
    data_type,
    parameter_mode,
    ordinal_position
FROM information_schema.parameters 
WHERE specific_schema = 'public' 
AND routine_name = 'search_listings'
ORDER BY ordinal_position;

-- 3. Check parameters for get_search_suggestions function (if it exists)
SELECT 
    routine_name,
    parameter_name,
    data_type,
    parameter_mode,
    ordinal_position
FROM information_schema.parameters 
WHERE specific_schema = 'public' 
AND routine_name = 'get_search_suggestions'
ORDER BY ordinal_position;

-- 4. Test search_listings function with simple parameters
SELECT COUNT(*) as search_test
FROM search_listings('guitar', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);

-- 5. Check what's in the tsv field for the guitar listing
SELECT 
    title, 
    description,
    tsv,
    to_tsvector('english', title || ' ' || COALESCE(description, '')) as generated_tsv
FROM public.listings 
WHERE title ILIKE '%guitar%' 
   OR description ILIKE '%guitar%'
   OR tsv @@ plainto_tsquery('english', 'guitar');

-- 6. Test different search terms
SELECT title, description
FROM search_listings('book', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);

SELECT title, description  
FROM search_listings('help', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);
