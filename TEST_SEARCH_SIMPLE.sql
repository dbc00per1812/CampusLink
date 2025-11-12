-- Simple Search Test - No Syntax Errors
-- Just tests if the function works

-- Test 1: Search for any listings with 'e' in them
SELECT title, category, price
FROM search_listings(
    'e',      -- query_text
    NULL,     -- category_filter
    NULL,     -- min_price
    NULL,     -- max_price
    NULL,     -- intent_filter
    NULL,     -- service_location_filter
    NULL,     -- trust_min
    NULL,     -- trust_max
    'relevance', -- sort_by
    5,        -- limit
    0         -- offset
);

-- Test 2: Get ALL listings (empty search)
SELECT title, category
FROM search_listings(
    NULL, NULL, NULL, NULL, NULL, NULL, NULL, NULL, 'recent', 10, 0
);

-- If you see your listings above, search is WORKING! ✅

