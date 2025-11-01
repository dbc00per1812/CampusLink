-- ============================================
-- CHECK IF TRIGGERS WERE DEPLOYED SUCCESSFULLY
-- ============================================
-- Run this to verify the fix is working

-- ============================================
-- 1. Check if triggers exist
-- ============================================
SELECT 
    '🔍 TRIGGER CHECK' as status,
    trigger_name, 
    event_manipulation, 
    event_object_table
FROM information_schema.triggers
WHERE trigger_name LIKE '%listing_quantity%'
ORDER BY trigger_name;

-- Expected: 2 rows
-- - restore_listing_quantity_on_order_cancel
-- - update_listing_quantity_after_order

-- ============================================
-- 2. Check if functions exist
-- ============================================
SELECT 
    '🔍 FUNCTION CHECK' as status,
    routine_name
FROM information_schema.routines
WHERE routine_name LIKE '%listing_quantity%'
  AND routine_schema = 'public'
ORDER BY routine_name;

-- Expected: 2 rows
-- - restore_listing_quantity_on_cancel
-- - update_listing_quantity_on_order

-- ============================================
-- 3. Check current listing states
-- ============================================
SELECT 
    '📊 LISTING STATE CHECK' as status,
    COUNT(*) FILTER (WHERE quantity_available <= 0 AND archived = false AND is_sold = false) as "Broken: sold_out_but_visible",
    COUNT(*) FILTER (WHERE quantity_available <= 0 AND archived = true AND is_sold = true) as "Correct: sold_out_and_hidden",
    COUNT(*) FILTER (WHERE quantity_available > 0) as "Active: still_available"
FROM listings;

-- Expected: 
-- - "Broken" should be 0
-- - If not 0, triggers didn't fire or retroactive fix didn't run

-- ============================================
-- 4. Show problem listings (if any)
-- ============================================
SELECT 
    id,
    title,
    quantity_available,
    quantity_sold,
    archived,
    is_sold,
    created_at
FROM listings
WHERE quantity_available <= 0 
  AND (archived = false OR is_sold = false)
ORDER BY created_at DESC
LIMIT 10;

-- If this returns rows, those listings are still visible but shouldn't be

-- ============================================
-- 5. Check recent orders to see if trigger is firing
-- ============================================
SELECT 
    o.id as order_id,
    o.created_at as order_time,
    o.payment_status,
    o.order_status,
    l.title,
    l.quantity_available,
    l.archived,
    l.is_sold,
    CASE 
        WHEN l.quantity_available > 0 THEN '✅ OK: Still has stock'
        WHEN l.archived = true AND l.is_sold = true THEN '✅ OK: Properly archived and marked sold'
        ELSE '❌ PROBLEM: Should be archived/sold but is not'
    END as status
FROM orders o
JOIN listings l ON l.id = o.listing_id
WHERE o.payment_status = 'succeeded'
  AND o.created_at > NOW() - INTERVAL '7 days'
ORDER BY o.created_at DESC
LIMIT 10;

-- This shows if NEW orders (after trigger deployment) are working correctly


