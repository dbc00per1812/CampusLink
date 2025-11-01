-- ============================================
-- DIAGNOSTIC: Check Why Posts Aren't Disappearing After Sale
-- ============================================
-- Run these queries in Supabase SQL Editor to diagnose the issue
-- This will tell you exactly what's wrong

-- ============================================
-- QUERY 1: Check if Auto-Archive Triggers Exist
-- ============================================
SELECT 
    '🔍 STEP 1: Checking if triggers exist...' as check_name;

SELECT 
    CASE 
        WHEN COUNT(*) = 2 THEN '✅ TRIGGERS EXIST - triggers are deployed'
        WHEN COUNT(*) = 0 THEN '❌ TRIGGERS MISSING - this is the problem!'
        ELSE '⚠️  PARTIAL - only ' || COUNT(*) || ' of 2 triggers found'
    END as trigger_status,
    STRING_AGG(trigger_name, ', ') as found_triggers
FROM information_schema.triggers
WHERE trigger_name IN ('update_listing_quantity_after_order', 'restore_listing_quantity_on_order_cancel');

-- ============================================
-- QUERY 2: Check Sold Listings That Should Be Archived
-- ============================================
SELECT 
    '🔍 STEP 2: Finding listings that sold but are still visible...' as check_name;

-- Find listings with orders but not archived
SELECT 
    l.id,
    l.title,
    l.quantity_available,
    l.quantity_sold,
    l.archived,
    l.is_sold,
    COUNT(o.id) as num_orders,
    SUM(o.quantity) as total_quantity_ordered
FROM listings l
LEFT JOIN orders o ON o.listing_id = l.id 
    AND o.payment_status = 'succeeded' 
    AND o.order_status IN ('placed', 'confirmed', 'completed')
WHERE l.archived = false 
GROUP BY l.id, l.title, l.quantity_available, l.quantity_sold, l.archived, l.is_sold
HAVING COUNT(o.id) > 0 AND COALESCE(l.quantity_available, 1) - COALESCE(SUM(o.quantity), 0) <= 0
ORDER BY l.created_at DESC
LIMIT 20;

-- ============================================
-- QUERY 3: Check Listings With quantity_available = 0
-- ============================================
SELECT 
    '🔍 STEP 3: Listings with 0 quantity that should be archived...' as check_name;

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
  AND archived = false
ORDER BY created_at DESC
LIMIT 20;

-- ============================================
-- QUERY 4: Sample Recent Orders
-- ============================================
SELECT 
    '🔍 STEP 4: Checking recent successful orders...' as check_name;

SELECT 
    o.id as order_id,
    o.created_at as order_date,
    o.payment_status,
    o.order_status,
    o.quantity as ordered_quantity,
    l.id as listing_id,
    l.title as listing_title,
    l.quantity_available,
    l.quantity_sold,
    l.archived,
    CASE 
        WHEN l.archived = true THEN '✅ Correctly archived'
        WHEN l.quantity_available > 0 THEN '✅ Still has stock (OK)'
        WHEN l.quantity_available <= 0 AND l.archived = false THEN '❌ SHOULD BE ARCHIVED'
        ELSE '⚠️  Unknown state'
    END as status_check
FROM orders o
JOIN listings l ON l.id = o.listing_id
WHERE o.payment_status = 'succeeded'
  AND o.order_status IN ('placed', 'confirmed', 'completed')
ORDER BY o.created_at DESC
LIMIT 10;

-- ============================================
-- QUERY 5: Summary Statistics
-- ============================================
SELECT 
    '📊 SUMMARY STATISTICS' as section;

SELECT 
    'Total listings' as metric,
    COUNT(*) as count
FROM listings
UNION ALL
SELECT 
    'Listings with quantity = 0' as metric,
    COUNT(*) as count
FROM listings
WHERE quantity_available <= 0
UNION ALL
SELECT 
    'Listings archived' as metric,
    COUNT(*) as count
FROM listings
WHERE archived = true
UNION ALL
SELECT 
    'Listings with quantity = 0 but NOT archived (THE PROBLEM)' as metric,
    COUNT(*) as count
FROM listings
WHERE quantity_available <= 0 AND archived = false
UNION ALL
SELECT 
    'Total successful orders' as metric,
    COUNT(*) as count
FROM orders
WHERE payment_status = 'succeeded' AND order_status IN ('placed', 'confirmed', 'completed');

-- ============================================
-- INTERPRETATION GUIDE
-- ============================================
/*
EXPECTED RESULTS:

QUERY 1 - Trigger Status:
- If "TRIGGERS MISSING" → The triggers were never deployed (most likely)
- If "TRIGGERS EXIST" → The triggers exist but may not be working

QUERY 2 - Sold Listings Not Archived:
- If this returns rows → These listings SHOULD be archived but aren't
- Shows the exact listings causing the problem

QUERY 3 - Zero Quantity Not Archived:
- Any row here = a listing that should be hidden but isn't
- These need to be manually fixed with UPDATE query

QUERY 4 - Recent Orders:
- Look for "SHOULD BE ARCHIVED" in status_check column
- This proves orders aren't triggering archiving

QUERY 5 - Summary:
- If "quantity = 0 but NOT archived" > 0 → You have the problem
- This number shows how many listings are broken

NEXT STEPS:
1. If QUERY 1 shows "TRIGGERS MISSING" → Run DEPLOY_AUTO_ARCHIVE_FIX.sql
2. If QUERY 2/3 return rows → Run the retroactive fix (see below)
3. Test with a new purchase to verify triggers work going forward
*/

-- ============================================
-- QUICK FIX QUERIES (Run after deploying triggers)
-- ============================================

-- PREVIEW: See what will be fixed
SELECT 
    '🔧 PREVIEW: These listings will be archived by the fix' as preview;

SELECT 
    id, title, quantity_available, quantity_sold, archived
FROM listings
WHERE quantity_available <= 0 AND archived = false;

-- EXECUTE: Archive all sold-out listings (uncomment to run)
/*
UPDATE listings
SET archived = true
WHERE quantity_available <= 0
  AND archived = false;
*/

-- VERIFY: Check the fix worked (run after UPDATE)
/*
SELECT 
    '✅ VERIFICATION: Listings after fix' as verification;

SELECT 
    id, title, quantity_available, archived
FROM listings
WHERE quantity_available <= 0;
-- All should show archived = true
*/

