-- ============================================
-- VERIFY AUTO-ARCHIVE TRIGGERS ARE DEPLOYED
-- ============================================
-- Run this to check if the auto-archive triggers exist and are enabled

-- Check if the triggers exist
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing,
    '✅ EXISTS' as status
FROM information_schema.triggers
WHERE trigger_name IN ('update_listing_quantity_after_order', 'restore_listing_quantity_on_order_cancel')
ORDER BY trigger_name;

-- If the above returns 0 rows, the triggers were NEVER DEPLOYED
-- You need to run: auto_archive_listings.sql

-- Check if the functions exist
SELECT 
    routine_name,
    routine_type,
    CASE 
        WHEN routine_name IS NOT NULL THEN '✅ EXISTS'
        ELSE '❌ MISSING'
    END as status
FROM information_schema.routines
WHERE routine_name IN ('update_listing_quantity_on_order', 'restore_listing_quantity_on_cancel')
  AND routine_schema = 'public'
ORDER BY routine_name;

-- Check a sample of recent orders to see their status
SELECT 
    id,
    listing_id,
    order_status,
    payment_status,
    quantity,
    created_at
FROM orders
ORDER BY created_at DESC
LIMIT 10;

-- Check corresponding listings to see if they were archived
SELECT 
    l.id,
    l.title,
    l.quantity_available,
    l.quantity_sold,
    l.archived,
    (SELECT COUNT(*) FROM orders WHERE listing_id = l.id AND payment_status = 'succeeded') as successful_orders
FROM listings l
WHERE l.id IN (
    SELECT DISTINCT listing_id 
    FROM orders 
    WHERE payment_status = 'succeeded' 
    ORDER BY created_at DESC 
    LIMIT 10
)
ORDER BY l.id;

