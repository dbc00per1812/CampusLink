-- ============================================
-- DEBUG ORDER NOTIFICATIONS
-- Run these queries in Supabase SQL Editor to diagnose the issue
-- ============================================

-- 1. Check if triggers are active
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    tgenabled
FROM information_schema.triggers
WHERE event_object_table = 'orders'
ORDER BY trigger_name;

-- 2. Check recent orders (last 5)
SELECT 
    id,
    buyer_id,
    seller_id,
    listing_id,
    order_status,
    price_cents,
    created_at
FROM orders
ORDER BY created_at DESC
LIMIT 5;

-- 3. Check if ANY notifications were created for recent orders
SELECT 
    n.id,
    n.type,
    n.title,
    n.user_id,
    n.order_id,
    n.created_at,
    o.order_status
FROM notifications n
LEFT JOIN orders o ON o.id = n.order_id
WHERE n.type IN ('order_placed', 'order_confirmed', 'order_completed', 'order_cancelled')
ORDER BY n.created_at DESC
LIMIT 10;

-- 4. Check if notification was created for the MOST RECENT order
-- (Replace [most-recent-order-id] with actual ID from query #2)
SELECT 
    n.*
FROM notifications n
WHERE n.order_id = (
    SELECT id FROM orders ORDER BY created_at DESC LIMIT 1
);

-- 5. Check RLS policies on notifications table
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

-- 6. Test trigger manually (replace UUIDs with real ones)
-- This will show if the trigger function itself works
/*
DO $$
DECLARE
    test_order_id UUID := '[replace-with-real-order-id]';
    test_listing_id UUID := '[replace-with-real-listing-id]';
    test_buyer_id UUID := '[replace-with-real-buyer-id]';
    test_seller_id UUID := '[replace-with-real-seller-id]';
BEGIN
    -- Try to manually insert a notification like the trigger would
    INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        data,
        order_id,
        listing_id,
        related_user_id,
        created_at
    ) VALUES (
        test_seller_id,
        'order_placed',
        'Test Notification',
        'This is a test',
        jsonb_build_object('order_id', test_order_id::text),
        test_order_id,
        test_listing_id,
        test_buyer_id,
        NOW()
    );
    
    RAISE NOTICE 'Manual insert succeeded!';
END $$;
*/

-- 7. Check if AppConfig.enableNotifications is true in your app
-- This is in Swift code, not SQL, but check:
-- CampusLink/Core/Config/AppConfig.swift
-- Make sure: static let enableNotifications = true

