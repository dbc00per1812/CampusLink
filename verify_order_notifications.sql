-- ============================================
-- VERIFY ORDER NOTIFICATION SETUP
-- Run this in Supabase SQL Editor to check current state
-- ============================================

-- 1. Check if notification triggers exist
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'orders'
ORDER BY trigger_name;

-- 2. Check if notification functions exist
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_name IN ('notify_new_order', 'notify_order_delivered', 'notify_order_completed')
ORDER BY routine_name;

-- 3. Test query: Check recent order status changes
SELECT 
    id,
    buyer_id,
    seller_id,
    order_status,
    created_at,
    seller_confirmed_at,
    completed_at
FROM orders
ORDER BY created_at DESC
LIMIT 5;

-- 4. Test query: Check corresponding notifications for recent orders
SELECT 
    n.id,
    n.type,
    n.title,
    n.body,
    n.order_id,
    n.user_id,
    n.created_at,
    o.order_status
FROM notifications n
LEFT JOIN orders o ON n.order_id = o.id
WHERE n.type IN ('order_placed', 'order_confirmed', 'order_completed')
ORDER BY n.created_at DESC
LIMIT 10;

-- 5. Count notifications by type
SELECT 
    type,
    COUNT(*) as count
FROM notifications
WHERE type IN ('order_placed', 'order_confirmed', 'order_completed')
GROUP BY type
ORDER BY type;

