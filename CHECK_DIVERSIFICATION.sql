-- Quick Check: Do You Have Variety in Your Data?
-- This tells you if diversification will be noticeable

-- Check 1: Categories breakdown
SELECT 
    category,
    listing_type,
    COUNT(*) as count
FROM listings
WHERE status = 'active' AND archived = false AND is_sold = false
GROUP BY category, listing_type
ORDER BY COUNT(*) DESC;

-- Check 2: First 20 listings (what app loads on page 1)
SELECT 
    ROW_NUMBER() OVER (ORDER BY created_at DESC) as position,
    title,
    category,
    listing_type,
    created_at
FROM listings
WHERE status = 'active' AND archived = false AND is_sold = false
ORDER BY created_at DESC
LIMIT 20;

-- Analysis
DO $$
DECLARE
    unique_cats INTEGER;
    total_count INTEGER;
    first_4_categories TEXT[];
BEGIN
    -- Count unique categories
    SELECT COUNT(DISTINCT category) INTO unique_cats
    FROM listings
    WHERE status = 'active' AND archived = false AND is_sold = false;
    
    SELECT COUNT(*) INTO total_count
    FROM listings
    WHERE status = 'active' AND archived = false AND is_sold = false;
    
    -- Get first 4 categories
    SELECT ARRAY_AGG(category) INTO first_4_categories
    FROM (
        SELECT DISTINCT category
        FROM listings
        WHERE status = 'active' AND archived = false AND is_sold = false
        ORDER BY created_at DESC
        LIMIT 4
    ) sub;
    
    RAISE NOTICE '====================================';
    RAISE NOTICE 'DIVERSIFICATION DATA CHECK';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Total active listings: %', total_count;
    RAISE NOTICE 'Unique categories: %', unique_cats;
    RAISE NOTICE '';
    
    IF total_count < 5 THEN
        RAISE NOTICE '❌ NOT ENOUGH LISTINGS: Need 5+, you have %', total_count;
        RAISE NOTICE 'Diversification needs at least 5 listings to work';
    ELSIF unique_cats < 3 THEN
        RAISE NOTICE '⚠️  LIMITED VARIETY: Only % unique categories', unique_cats;
        RAISE NOTICE 'Diversification will work but may not be very noticeable';
        RAISE NOTICE 'Create listings in different categories to see it better';
    ELSE
        RAISE NOTICE '✅ GOOD DATA: % listings, % categories', total_count, unique_cats;
        RAISE NOTICE 'Diversification should be working!';
    END IF;
    
    RAISE NOTICE '====================================';
END $$;

