-- ============================================
-- CHECK CAMPUS STRING VARIATIONS
-- ============================================
-- This will show if there are variations in how campus names are stored

-- ============================================
-- STEP 1: Show All Unique Campus Values
-- ============================================

SELECT 
    '🎓 ALL CAMPUS NAME VARIATIONS' as check_name,
    campus,
    COUNT(*) as user_count,
    COUNT(DISTINCT l.id) as listing_count
FROM users u
LEFT JOIN listings l ON l.user_id = u.id
GROUP BY campus
ORDER BY user_count DESC;

-- ============================================
-- STEP 2: Focus on Purdue Variations
-- ============================================

SELECT 
    '🔍 PURDUE CAMPUS VARIATIONS' as check_name,
    campus,
    LENGTH(campus) as string_length,
    COUNT(*) as user_count,
    COUNT(DISTINCT l.id) as listing_count
FROM users u
LEFT JOIN listings l ON l.user_id = u.id
WHERE campus ILIKE '%purdue%'
GROUP BY campus
ORDER BY user_count DESC;

-- ============================================
-- STEP 3: Check for Extra Whitespace
-- ============================================

SELECT 
    '⚠️ CAMPUS NAMES WITH WHITESPACE ISSUES' as check_name,
    campus,
    CASE 
        WHEN campus != TRIM(campus) THEN '❌ Has leading/trailing spaces'
        WHEN campus LIKE '%  %' THEN '❌ Has double spaces'
        ELSE '✅ Clean'
    END as whitespace_check,
    COUNT(*) as user_count
FROM users
WHERE campus IS NOT NULL
GROUP BY campus
HAVING campus != TRIM(campus) OR campus LIKE '%  %'
ORDER BY user_count DESC;

-- ============================================
-- STEP 4: Show Purdue Posts by Campus String
-- ============================================

SELECT 
    '📊 PURDUE POSTS BY EXACT CAMPUS STRING' as check_name,
    u.campus,
    COUNT(l.id) as total_listings,
    COUNT(*) FILTER (WHERE l.archived = false AND l.is_sold = false AND l.status = 'active') as visible_listings,
    COUNT(*) FILTER (WHERE l.archived = true OR l.is_sold = true OR l.status != 'active') as hidden_listings
FROM users u
LEFT JOIN listings l ON l.user_id = u.id
WHERE u.campus ILIKE '%purdue%'
GROUP BY u.campus
ORDER BY total_listings DESC;

-- ============================================
-- STEP 5: Sample Users and Their Exact Campus Values
-- ============================================

SELECT 
    '👥 SAMPLE PURDUE USERS' as check_name,
    u.id,
    u.name,
    u.email,
    u.campus,
    LENGTH(u.campus) as campus_length,
    COUNT(l.id) as listings_count
FROM users u
LEFT JOIN listings l ON l.user_id = u.id
WHERE u.campus ILIKE '%purdue%'
GROUP BY u.id, u.name, u.email, u.campus
ORDER BY listings_count DESC
LIMIT 20;

-- ============================================
-- STEP 6: Check IU Variations (for comparison)
-- ============================================

SELECT 
    '🔍 IU CAMPUS VARIATIONS' as check_name,
    campus,
    LENGTH(campus) as string_length,
    COUNT(*) as user_count,
    COUNT(DISTINCT l.id) as listing_count
FROM users u
LEFT JOIN listings l ON l.user_id = u.id
WHERE campus ILIKE '%indiana%' OR campus ILIKE '%bloomington%'
GROUP BY campus
ORDER BY user_count DESC;


