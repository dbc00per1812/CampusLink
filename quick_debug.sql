-- Quick check: what does the function actually return for guitar?
SELECT * FROM search_listings('guitar', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 5, 0);

-- And check total count
SELECT COUNT(*) as guitar_results
FROM search_listings('guitar', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 10, 0);
