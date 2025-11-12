-- Test Diversification Setup
-- Check if you have enough variety for diversification to show

-- Check 1: How many listings per category?
SELECT 
    category,
    listing_type,
    COUNT(*) as count
FROM listings
WHERE status = 'active' AND archived = false AND is_sold = false
GROUP BY category, listing_type
ORDER BY listing_type, COUNT(*) DESC;

-- Check 2: First 20 listings (what the app sees)
SELECT 
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
    unique_categories INTEGER;
    total_listings INTEGER;
    products INTEGER;
    services INTEGER;
BEGIN
    SELECT 
        COUNT(DISTINCT category),
        COUNT(*),
        COUNT(*) FILTER (WHERE listing_type = 'product'),
        COUNT(*) FILTER (WHERE listing_type = 'service')
    INTO unique_categories, total_listings, products, services
    FROM listings
    WHERE status = 'active' AND archived = false AND is_sold = false;
    
    RAISE NOTICE '====================================';
    RAISE NOTICE 'DIVERSIFICATION ANALYSIS';
    RAISE NOTICE '====================================';
    RAISE NOTICE 'Total active listings: %', total_listings;
    RAISE NOTICE 'Products: %', products;
    RAISE NOTICE 'Services: %', services;
    RAISE NOTICE 'Unique categories: %', unique_categories;
    RAISE NOTICE '';
    
    IF unique_categories < 3 THEN
        RAISE NOTICE '⚠️  WARNING: Only % unique categories', unique_categories;
        RAISE NOTICE 'Diversification works best with 3+ categories';
        RAISE NOTICE 'Current data may not show obvious diversification';
    ELSIF services = 0 THEN
        RAISE NOTICE '⚠️  WARNING: No services found';
        RAISE NOTICE 'Will show 4 products instead of 3+1 mix';
    ELSE
        RAISE NOTICE '✅ Good variety - diversification should be visible';
    END IF;
    
    RAISE NOTICE '====================================';
END $$;

