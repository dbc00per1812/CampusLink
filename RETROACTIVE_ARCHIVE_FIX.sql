-- ============================================
-- RETROACTIVE FIX: Archive Listings from Past Orders
-- ============================================
-- This script finds listings that SHOULD be archived based on past orders
-- and updates them retroactively.
--
-- Run this AFTER deploying the auto-archive triggers.

-- ============================================
-- STEP 1: Preview What Will Be Fixed
-- ============================================

-- Find listings that should be archived but aren't
SELECT 
    l.id,
    l.title,
    l.quantity_available,
    l.quantity_sold,
    l.archived,
    COUNT(o.id) as successful_orders,
    SUM(o.quantity) as total_quantity_sold,
    CASE 
        WHEN l.quantity_available <= 0 AND l.archived = false THEN '❌ SHOULD BE ARCHIVED'
        WHEN l.quantity_available <= 0 AND l.archived = true THEN '✅ ALREADY ARCHIVED'
        ELSE '⏳ STILL AVAILABLE'
    END as status
FROM listings l
LEFT JOIN orders o ON o.listing_id = l.id AND o.payment_status = 'succeeded'
GROUP BY l.id, l.title, l.quantity_available, l.quantity_sold, l.archived
HAVING l.quantity_available <= 0 AND l.archived = false
ORDER BY l.created_at DESC;

-- ============================================
-- STEP 2: Recalculate Quantities for ALL Listings
-- ============================================

-- This will update ALL listings based on their actual order history
-- Uncomment the UPDATE statement below to execute

/*
UPDATE listings l
SET 
    quantity_sold = COALESCE(order_totals.total_sold, 0),
    quantity_available = GREATEST(0, COALESCE(l.quantity_available, 1) - COALESCE(order_totals.total_sold, 0) + COALESCE(l.quantity_sold, 0)),
    archived = CASE 
        WHEN (COALESCE(l.quantity_available, 1) - COALESCE(order_totals.total_sold, 0) + COALESCE(l.quantity_sold, 0)) <= 0 THEN true
        ELSE l.archived
    END
FROM (
    SELECT 
        listing_id,
        SUM(quantity) as total_sold
    FROM orders
    WHERE payment_status = 'succeeded'
      AND order_status IN ('placed', 'confirmed', 'in_progress', 'completed')
    GROUP BY listing_id
) order_totals
WHERE l.id = order_totals.listing_id
  AND (
    l.quantity_sold != COALESCE(order_totals.total_sold, 0)
    OR (l.quantity_available - l.quantity_sold + COALESCE(order_totals.total_sold, 0) <= 0 AND l.archived = false)
  );
*/

-- ============================================
-- STEP 3: Archive Sold-Out Listings (Simple Approach)
-- ============================================

-- Simpler approach: Just archive listings where quantity_available = 0
-- Uncomment to execute:

/*
UPDATE listings
SET archived = true
WHERE quantity_available <= 0
  AND archived = false;
*/

-- ============================================
-- STEP 4: Verify the Fix
-- ============================================

-- After running the update, check the results:
SELECT 
    l.id,
    l.title,
    l.quantity_available,
    l.quantity_sold,
    l.archived,
    COUNT(o.id) as successful_orders,
    CASE 
        WHEN l.quantity_available <= 0 AND l.archived = true THEN '✅ CORRECTLY ARCHIVED'
        WHEN l.quantity_available <= 0 AND l.archived = false THEN '❌ STILL NOT ARCHIVED'
        ELSE '⏳ AVAILABLE'
    END as status
FROM listings l
LEFT JOIN orders o ON o.listing_id = l.id AND o.payment_status = 'succeeded'
WHERE l.quantity_available <= 0
GROUP BY l.id, l.title, l.quantity_available, l.quantity_sold, l.archived
ORDER BY l.created_at DESC;

-- ============================================
-- RECOMMENDED APPROACH
-- ============================================

-- 1. First run the SELECT queries above to see what will be affected
-- 2. Uncomment and run STEP 3 (simple approach) first
-- 3. Check the results with the verification query in STEP 4
-- 4. If you need more complex recalculation, use STEP 2

-- ============================================
-- NOTES
-- ============================================

-- This retroactive fix is only needed ONCE, immediately after deploying
-- the auto-archive triggers. Future orders will be handled automatically.

-- The triggers will handle all new orders going forward, so you won't
-- need to run this script again unless you have data inconsistencies.

