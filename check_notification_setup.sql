-- Diagnostic Script: Check Notification Setup
-- Run this in Supabase SQL Editor to diagnose notification issues

-- 1. Check if notifications table exists and has data
SELECT 'Notifications table' as check_name, 
       COUNT(*) as total_count,
       COUNT(CASE WHEN is_read = false THEN 1 END) as unread_count
FROM notifications;

-- 2. Check recent notifications (last 10)
SELECT 
    created_at,
    type,
    title,
    user_id,
    is_read
FROM notifications
ORDER BY created_at DESC
LIMIT 10;

-- 3. Check if user_notification_preferences exist for your test users
SELECT 
    u.email,
    unp.push_enabled,
    unp.order_notifications,
    unp.message_notifications,
    unp.marketplace_notifications
FROM users u
LEFT JOIN user_notification_preferences unp ON u.id = unp.user_id
ORDER BY u.created_at DESC
LIMIT 10;

-- 4. Check RLS policies on notifications table
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'notifications';

-- 5. Check recent orders to see if notifications should have been created
SELECT 
    o.id as order_id,
    o.created_at,
    o.order_status,
    l.title as listing_title,
    buyer.email as buyer_email,
    seller.email as seller_email,
    (SELECT COUNT(*) FROM notifications WHERE order_id = o.id) as notification_count
FROM orders o
LEFT JOIN listings l ON o.listing_id = l.id
LEFT JOIN users buyer ON o.buyer_id = buyer.id
LEFT JOIN users seller ON o.seller_id = seller.id
ORDER BY o.created_at DESC
LIMIT 5;

-- 6. Check if there are any constraint errors
SELECT constraint_name, table_name
FROM information_schema.table_constraints
WHERE table_name = 'notifications' 
AND constraint_type = 'FOREIGN KEY';

-- 7. Test notification insert (won't actually insert, just checks permissions)
-- Replace 'YOUR_USER_ID' with actual user ID
-- UNCOMMENT LINES BELOW TO TEST:
-- BEGIN;
-- INSERT INTO notifications (user_id, type, title, body, data, order_id, listing_id)
-- VALUES (
--     'YOUR_USER_ID',
--     'order_placed',
--     'Test Notification',
--     'This is a test',
--     '{}',
--     NULL,
--     NULL
-- );
-- ROLLBACK;  -- This prevents actual insert

-- RESULTS INTERPRETATION:
-- If notification_count = 0 for recent orders → notifications aren't being created
-- If RLS policies are too restrictive → might block inserts
-- If user_notification_preferences is NULL → might need to create preferences first


