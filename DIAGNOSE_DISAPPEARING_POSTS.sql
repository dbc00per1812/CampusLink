-- ============================================
-- DIAGNOSE: Posts Disappearing From Purdue Page
-- ============================================
-- Check if posts are being incorrectly archived or filtered

-- ============================================
-- STEP 1: Check Current State of Purdue Posts
-- ============================================

SELECT 
    '📊 PURDUE POSTS OVERVIEW' as check_name,
    COUNT(*) as total_posts,
    COUNT(*) FILTER (WHERE archived = false) as visible_posts,
    COUNT(*) FILTER (WHERE archived = true) as archived_posts,
    COUNT(*) FILTER (WHERE is_sold = true) as sold_posts,
    COUNT(*) FILTER (WHERE status != 'active') as inactive_posts,
    COUNT(*) FILTER (WHERE quantity_available <= 0) as zero_quantity_posts
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE u.campus = 'Purdue University';

-- ============================================
-- STEP 2: Find Recently Disappeared Posts
-- ============================================
-- Posts that were created recently but are now archived/hidden

SELECT 
    '🔍 RECENTLY DISAPPEARED POSTS (Last 30 Days)' as check_name,
    l.id,
    l.title,
    l.created_at,
    l.archived,
    l.is_sold,
    l.status,
    l.quantity_available,
    l.quantity_sold,
    u.name as seller_name,
    u.campus,
    (SELECT COUNT(*) FROM orders o WHERE o.listing_id = l.id AND o.payment_status = 'succeeded') as successful_orders
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE u.campus = 'Purdue University'
  AND l.created_at > NOW() - INTERVAL '30 days'
  AND l.archived = true
ORDER BY l.created_at DESC;

-- ============================================
-- STEP 3: Check for Wrong Archive Status
-- ============================================
-- Posts that should be visible but aren't, or vice versa

SELECT 
    '❌ INCORRECTLY ARCHIVED POSTS' as check_name,
    l.id,
    l.title,
    l.created_at,
    l.archived,
    l.quantity_available,
    l.quantity_sold,
    u.name as seller_name,
    CASE 
        WHEN l.quantity_available > 0 AND l.archived = true THEN '❌ HAS STOCK BUT ARCHIVED'
        WHEN l.quantity_available <= 0 AND l.archived = false THEN '❌ NO STOCK BUT NOT ARCHIVED'
        ELSE '✅ OK'
    END as problem
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE u.campus = 'Purdue University'
  AND (
    (l.quantity_available > 0 AND l.archived = true) OR
    (l.quantity_available <= 0 AND l.archived = false)
  )
ORDER BY l.created_at DESC;

-- ============================================
-- STEP 4: Check Recent Orders for Purdue Posts
-- ============================================
-- See if orders are triggering incorrect archiving

SELECT 
    '📦 RECENT ORDERS ON PURDUE POSTS' as check_name,
    o.id as order_id,
    o.created_at as order_date,
    o.quantity as order_quantity,
    o.payment_status,
    o.order_status,
    l.title as listing_title,
    l.quantity_available as listing_qty_now,
    l.archived as listing_archived,
    u.name as seller_name
FROM orders o
JOIN listings l ON l.id = o.listing_id
JOIN users u ON u.id = l.user_id
WHERE u.campus = 'Purdue University'
  AND o.created_at > NOW() - INTERVAL '7 days'
ORDER BY o.created_at DESC
LIMIT 20;

-- ============================================
-- STEP 5: Check for Time-Based Issues
-- ============================================
-- See if there's a pattern with post age

SELECT 
    '📅 POST AGE DISTRIBUTION' as check_name,
    CASE 
        WHEN l.created_at > NOW() - INTERVAL '1 day' THEN '< 1 day'
        WHEN l.created_at > NOW() - INTERVAL '3 days' THEN '1-3 days'
        WHEN l.created_at > NOW() - INTERVAL '7 days' THEN '3-7 days'
        WHEN l.created_at > NOW() - INTERVAL '14 days' THEN '7-14 days'
        WHEN l.created_at > NOW() - INTERVAL '30 days' THEN '14-30 days'
        ELSE '> 30 days'
    END as age_range,
    COUNT(*) as total_posts,
    COUNT(*) FILTER (WHERE archived = false) as visible,
    COUNT(*) FILTER (WHERE archived = true) as archived,
    ROUND(100.0 * COUNT(*) FILTER (WHERE archived = true) / COUNT(*), 1) as percent_archived
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE u.campus = 'Purdue University'
GROUP BY age_range
ORDER BY 
    CASE age_range
        WHEN '< 1 day' THEN 1
        WHEN '1-3 days' THEN 2
        WHEN '3-7 days' THEN 3
        WHEN '7-14 days' THEN 4
        WHEN '14-30 days' THEN 5
        ELSE 6
    END;

-- ============================================
-- STEP 6: Check Auto-Archive Triggers
-- ============================================
-- Verify triggers exist and are active

SELECT 
    '🔧 AUTO-ARCHIVE SYSTEM STATUS' as check_name,
    trigger_name,
    event_object_table as table_name,
    event_manipulation as event,
    action_timing as timing,
    CASE 
        WHEN trigger_name IS NOT NULL THEN '✅ ACTIVE'
        ELSE '❌ MISSING'
    END as status
FROM information_schema.triggers
WHERE trigger_name IN ('update_listing_quantity_after_order', 'restore_listing_quantity_on_order_cancel')
ORDER BY trigger_name;

-- ============================================
-- STEP 7: Sample of Active Purdue Posts
-- ============================================
-- Show what IS currently visible to confirm filtering works

SELECT 
    '✅ CURRENTLY VISIBLE PURDUE POSTS' as check_name,
    l.id,
    l.title,
    l.created_at,
    l.quantity_available,
    l.archived,
    l.is_sold,
    l.status,
    u.name as seller_name,
    EXTRACT(DAY FROM NOW() - l.created_at)::INTEGER as days_old
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE u.campus = 'Purdue University'
  AND l.archived = false
  AND l.is_sold = false
  AND l.status = 'active'
ORDER BY l.created_at DESC
LIMIT 20;

-- ============================================
-- STEP 8: Check Campus Field Consistency
-- ============================================
-- Make sure campus field is consistent

SELECT 
    '🎓 CAMPUS FIELD CHECK' as check_name,
    u.campus,
    COUNT(*) as user_count,
    COUNT(DISTINCT l.id) as listing_count
FROM users u
LEFT JOIN listings l ON l.user_id = u.id
WHERE u.campus LIKE '%Purdue%' OR u.campus LIKE '%purdue%'
GROUP BY u.campus
ORDER BY user_count DESC;


