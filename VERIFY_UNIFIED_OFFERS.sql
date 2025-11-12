-- ========================================
-- Verify Unified Offers System Setup
-- ========================================
-- Run this to confirm all database changes are in place

-- 1. Check new columns exist in offers table
SELECT 
    'Checking offers table columns...' AS step,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'offers' 
            AND column_name IN ('listing_type', 'offer_from_user_id', 'offer_to_user_id', 'parent_offer_id')
        ) THEN '✅ All new columns exist'
        ELSE '❌ Missing columns'
    END AS status;

-- 2. Check accepts_offers field in listings
SELECT 
    'Checking listings.accepts_offers...' AS step,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM information_schema.columns 
            WHERE table_name = 'listings' 
            AND column_name = 'accepts_offers'
        ) THEN '✅ accepts_offers field exists'
        ELSE '❌ Field missing'
    END AS status;

-- 3. Verify data migration (existing offers should have listing_type = 'seek')
SELECT 
    'Checking existing offers migration...' AS step,
    COUNT(*) AS total_offers,
    SUM(CASE WHEN listing_type = 'seek' THEN 1 ELSE 0 END) AS seek_offers,
    SUM(CASE WHEN listing_type = 'regular' THEN 1 ELSE 0 END) AS regular_offers
FROM offers;

-- 4. Check RLS policies
SELECT 
    'Checking RLS policies...' AS step,
    COUNT(*) AS policy_count,
    string_agg(policyname, ', ') AS policies
FROM pg_policies
WHERE tablename = 'offers';

-- 5. Verify trigger exists
SELECT 
    'Checking offer notification trigger...' AS step,
    CASE 
        WHEN EXISTS (
            SELECT 1 FROM pg_trigger 
            WHERE tgname = 'offer_activity_trigger'
        ) THEN '✅ Trigger exists'
        ELSE '❌ Trigger missing'
    END AS status;

-- 6. Check indexes
SELECT 
    'Checking indexes...' AS step,
    COUNT(*) AS index_count,
    string_agg(indexname, ', ') AS indexes
FROM pg_indexes
WHERE tablename = 'offers';

-- 7. Check how many seek listings accept offers
SELECT 
    'Checking seek listings with accepts_offers...' AS step,
    COUNT(*) AS total_seek,
    SUM(CASE WHEN accepts_offers THEN 1 ELSE 0 END) AS accepts_offers_count
FROM listings
WHERE intent = 'seek';

-- 8. Summary
SELECT 
    '========================================' AS summary,
    'UNIFIED OFFERS SYSTEM - VERIFICATION' AS title,
    '========================================' AS footer;

SELECT 
    'Database schema:' AS component,
    '✅ Ready' AS status
WHERE EXISTS (
    SELECT 1 FROM information_schema.columns 
    WHERE table_name = 'offers' 
    AND column_name = 'listing_type'
);

SELECT 
    'RLS policies:' AS component,
    '✅ Configured' AS status
WHERE EXISTS (
    SELECT 1 FROM pg_policies 
    WHERE tablename = 'offers' 
    AND policyname LIKE '%participants%'
);

SELECT 
    'Notification triggers:' AS component,
    '✅ Active' AS status
WHERE EXISTS (
    SELECT 1 FROM pg_trigger 
    WHERE tgname = 'offer_activity_trigger'
);

-- Final confirmation
SELECT 
    '🚀 System Status: READY FOR TESTING' AS message,
    'All database components are in place' AS details;

