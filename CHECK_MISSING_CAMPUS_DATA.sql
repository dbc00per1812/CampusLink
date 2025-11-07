-- ============================================
-- CHECK IF SELLERS ARE MISSING CAMPUS DATA
-- ============================================
-- This will show if the "disappearing" posts are from users without campus set

-- ============================================
-- STEP 1: Posts from Users with NO Campus Set
-- ============================================

SELECT 
    '❌ POSTS FROM USERS WITHOUT CAMPUS' as issue,
    l.id,
    l.title,
    l.created_at,
    l.archived,
    l.is_sold,
    l.status,
    u.id as user_id,
    u.name as seller_name,
    u.email as seller_email,
    u.campus,
    CASE 
        WHEN u.campus IS NULL THEN '❌ Campus is NULL'
        WHEN u.campus = '' THEN '❌ Campus is empty string'
        ELSE '✅ Has campus'
    END as campus_status
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE l.archived = false 
  AND l.is_sold = false 
  AND l.status = 'active'
  AND (u.campus IS NULL OR u.campus = '')
ORDER BY l.created_at DESC
LIMIT 50;

-- ============================================
-- STEP 2: Count Active Posts by Campus Status
-- ============================================

SELECT 
    '📊 ACTIVE POSTS BY CAMPUS STATUS' as summary,
    CASE 
        WHEN u.campus IS NULL THEN 'Campus is NULL'
        WHEN u.campus = '' THEN 'Campus is empty string'
        WHEN u.campus ILIKE '%purdue%' THEN 'Purdue University'
        WHEN u.campus ILIKE '%indiana%' OR u.campus ILIKE '%bloomington%' THEN 'Indiana University'
        ELSE u.campus
    END as campus_category,
    COUNT(*) as post_count
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE l.archived = false 
  AND l.is_sold = false 
  AND l.status = 'active'
GROUP BY campus_category
ORDER BY post_count DESC;

-- ============================================
-- STEP 3: Purdue Users with Missing Campus
-- ============================================

SELECT 
    '🔍 PURDUE USERS WITHOUT CAMPUS SET' as issue,
    u.id,
    u.name,
    u.email,
    u.campus,
    u.created_at as user_created,
    COUNT(l.id) as active_listings
FROM users u
LEFT JOIN listings l ON l.user_id = u.id 
    AND l.archived = false 
    AND l.is_sold = false 
    AND l.status = 'active'
WHERE u.email ILIKE '%purdue.edu%'
  AND (u.campus IS NULL OR u.campus = '' OR u.campus != 'Purdue University')
GROUP BY u.id, u.name, u.email, u.campus, u.created_at
HAVING COUNT(l.id) > 0
ORDER BY active_listings DESC;

-- ============================================
-- STEP 4: Recent Posts Being Hidden by Filter
-- ============================================
-- Posts that would be visible but are filtered out due to campus mismatch

SELECT 
    '⚠️ POSTS LIKELY BEING FILTERED OUT' as issue,
    l.id,
    l.title,
    l.created_at,
    u.name as seller_name,
    u.email as seller_email,
    u.campus as seller_campus,
    CASE 
        WHEN u.campus IS NULL THEN '❌ Would be filtered: Campus is NULL'
        WHEN u.campus = '' THEN '❌ Would be filtered: Campus is empty'
        WHEN u.campus ILIKE '%purdue%' AND u.campus != 'Purdue University' THEN '⚠️ Would be filtered: Campus variation'
        ELSE '✅ Should be visible'
    END as filter_status
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE l.archived = false 
  AND l.is_sold = false 
  AND l.status = 'active'
  AND l.created_at > NOW() - INTERVAL '30 days'
  AND (
    u.campus IS NULL 
    OR u.campus = '' 
    OR (u.email ILIKE '%purdue.edu%' AND u.campus != 'Purdue University')
  )
ORDER BY l.created_at DESC
LIMIT 50;

-- ============================================
-- STEP 5: Check All Purdue Email Users
-- ============================================

SELECT 
    '👥 ALL PURDUE.EDU USERS' as summary,
    CASE 
        WHEN u.campus IS NULL THEN 'NULL'
        WHEN u.campus = '' THEN 'EMPTY'
        ELSE u.campus
    END as campus_value,
    COUNT(*) as user_count,
    COUNT(l.id) as total_listings,
    COUNT(*) FILTER (WHERE l.archived = false AND l.is_sold = false AND l.status = 'active') as active_listings
FROM users u
LEFT JOIN listings l ON l.user_id = u.id
WHERE u.email ILIKE '%purdue.edu%'
GROUP BY campus_value
ORDER BY user_count DESC;

-- ============================================
-- STEP 6: Sample of Working Purdue Posts
-- ============================================

SELECT 
    '✅ PURDUE POSTS THAT SHOULD BE VISIBLE' as summary,
    l.id,
    l.title,
    l.created_at,
    u.name as seller_name,
    u.campus as seller_campus,
    LENGTH(u.campus) as campus_length
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE l.archived = false 
  AND l.is_sold = false 
  AND l.status = 'active'
  AND u.email ILIKE '%purdue.edu%'
  AND u.campus IS NOT NULL
  AND u.campus != ''
ORDER BY l.created_at DESC
LIMIT 20;


