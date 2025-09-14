-- Test Search Debug Script
-- Use this to debug search issues with specific terms

-- 1. Check what listings exist with "levitator" or similar terms
SELECT id, title, description, category, tsv
FROM listings
WHERE status = 'active' 
  AND archived = false
  AND (
    title ILIKE '%levitat%'
    OR description ILIKE '%levitat%'
    OR title ILIKE '%guitar%'
    OR description ILIKE '%guitar%'
  );

-- 2. Test the current search function with "levitator"
SELECT * FROM search_listings('levitator', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 20, 0);

-- 3. Test with partial match "lev"
SELECT * FROM search_listings('lev', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 20, 0);

-- 4. Test with "guitar" 
SELECT * FROM search_listings('guitar', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 20, 0);

-- 5. Test with partial "guit"
SELECT * FROM search_listings('guit', NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'relevance', 20, 0);

-- 6. Check the TSV content for specific listings
SELECT 
    title,
    description,
    tsv,
    to_tsvector('simple', title) as title_tsv,
    to_tsvector('simple', COALESCE(description, '')) as desc_tsv
FROM listings
WHERE title ILIKE '%guitar%' OR title ILIKE '%levitat%'
LIMIT 5;

-- 7. Test plainto_tsquery vs prefix matching
SELECT 
    'levitator' as search_term,
    plainto_tsquery('simple', 'levitator') as plain_query,
    to_tsquery('simple', 'levitator:*') as prefix_query,
    plainto_tsquery('simple', 'lev') as plain_partial,
    to_tsquery('simple', 'lev:*') as prefix_partial;
