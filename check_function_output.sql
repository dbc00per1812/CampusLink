-- Check exactly what search_listings returns
SELECT * FROM search_listings('guitar', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);

-- Check what columns the function actually returns
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_name = 'search_listings';
