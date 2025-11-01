-- ============================================
-- TEST ALL NOTIFICATION TRIGGERS
-- ============================================
-- Run these queries to verify notifications are working
-- ============================================

-- ============================================
-- STEP 1: Verify triggers are installed
-- ============================================

SELECT 
    trigger_name,
    event_object_table as table_name,
    action_timing,
    event_manipulation as event,
    action_statement
FROM information_schema.triggers
WHERE event_object_table IN ('messages', 'orders', 'offers')
AND trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Expected: 7 triggers total
-- messages: 1 trigger
-- orders: 4 triggers  
-- offers: 2 triggers

-- ============================================
-- STEP 2: Check recent notifications
-- ============================================

SELECT 
    n.id,
    n.type,
    n.title,
    n.body,
    n.created_at,
    n.is_read,
    u.name as recipient_name,
    ru.name as related_user_name
FROM notifications n
LEFT JOIN users u ON n.user_id = u.id
LEFT JOIN users ru ON n.related_user_id = ru.id
ORDER BY n.created_at DESC
LIMIT 20;

-- ============================================
-- STEP 3: Check notification counts by type
-- ============================================

SELECT 
    type,
    COUNT(*) as count,
    COUNT(CASE WHEN is_read = false THEN 1 END) as unread_count,
    MAX(created_at) as most_recent
FROM notifications
GROUP BY type
ORDER BY most_recent DESC;

-- Expected types:
-- new_message
-- order_placed
-- order_confirmed
-- order_completed
-- order_cancelled (if any)
-- listing_interest
-- marketplace_activity

-- ============================================
-- STEP 4: Test message notification manually
-- ============================================

-- Create a test message and verify notification is created
-- Replace these UUIDs with actual test user IDs from your database

-- First, find a test conversation:
-- SELECT id, buyer_id, seller_id FROM conversations LIMIT 1;

-- Then insert a test message:
-- INSERT INTO messages (conversation_id, sender_id, content)
-- VALUES (
--     'YOUR_CONVERSATION_ID',
--     'YOUR_SENDER_ID',
--     'Test message to verify notification trigger'
-- );

-- Check if notification was created:
-- SELECT * FROM notifications 
-- WHERE type = 'new_message' 
-- ORDER BY created_at DESC LIMIT 1;

-- ============================================
-- STEP 5: Test order notification manually
-- ============================================

-- Find a test order in 'placed' status:
-- SELECT id, buyer_id, seller_id, order_status FROM orders 
-- WHERE order_status = 'placed' LIMIT 1;

-- Update it to seller_confirmed:
-- UPDATE orders 
-- SET order_status = 'seller_confirmed', 
--     seller_confirmed_at = NOW()
-- WHERE id = 'YOUR_ORDER_ID';

-- Check if notification was created:
-- SELECT * FROM notifications 
-- WHERE type = 'order_confirmed' 
-- ORDER BY created_at DESC LIMIT 1;

-- Update it to completed:
-- UPDATE orders 
-- SET order_status = 'completed', 
--     completed_at = NOW()
-- WHERE id = 'YOUR_ORDER_ID';

-- Check if notification was created:
-- SELECT * FROM notifications 
-- WHERE type = 'order_completed' 
-- ORDER BY created_at DESC LIMIT 1;

-- ============================================
-- STEP 6: Test offer notification manually
-- ============================================

-- Find a test offer in 'pending' status:
-- SELECT id, seeker_id, seller_id, status FROM offers 
-- WHERE status = 'pending' LIMIT 1;

-- Update it to accepted:
-- UPDATE offers 
-- SET status = 'accepted'
-- WHERE id = 'YOUR_OFFER_ID';

-- Check if notification was created:
-- SELECT * FROM notifications 
-- WHERE type = 'marketplace_activity' 
-- AND body LIKE '%accepted%'
-- ORDER BY created_at DESC LIMIT 1;

-- ============================================
-- STEP 7: Check for errors in triggers
-- ============================================

-- If triggers fail, check Postgres logs
-- In Supabase Dashboard: Logs > Postgres Logs

-- Common issues:
-- 1. User doesn't exist in users table
-- 2. Foreign key constraint violations
-- 3. RLS policies blocking inserts
-- 4. Missing columns

-- ============================================
-- STEP 8: Verify RLS policies allow inserts
-- ============================================

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

-- Make sure there's an INSERT policy that allows the trigger to create notifications

-- ============================================
-- STEP 9: Recent orders with notification counts
-- ============================================

SELECT 
    o.id,
    o.order_status,
    o.created_at as order_created,
    l.title as item,
    buyer.name as buyer_name,
    seller.name as seller_name,
    (SELECT COUNT(*) FROM notifications WHERE order_id = o.id) as notification_count
FROM orders o
LEFT JOIN listings l ON o.listing_id = l.id
LEFT JOIN users buyer ON o.buyer_id = buyer.id
LEFT JOIN users seller ON o.seller_id = seller.id
ORDER BY o.created_at DESC
LIMIT 10;

-- Each order should have at least 1 notification (order_placed)
-- If seller confirmed: should have 2 notifications
-- If completed: should have 3 notifications

-- ============================================
-- STEP 10: Recent offers with notification counts
-- ============================================

SELECT 
    off.id,
    off.status,
    off.created_at as offer_created,
    l.title as seek_post,
    seeker.name as seeker_name,
    seller.name as offer_maker_name,
    (SELECT COUNT(*) FROM notifications WHERE data->>'offer_id' = off.id::text) as notification_count
FROM offers off
LEFT JOIN listings l ON off.seek_listing_id = l.id
LEFT JOIN users seeker ON off.seeker_id = seeker.id
LEFT JOIN users seller ON off.seller_id = seller.id
ORDER BY off.created_at DESC
LIMIT 10;

-- Each offer should have at least 1 notification (new offer)
-- If accepted/declined: should have 2 notifications

-- ============================================
-- SUCCESS CRITERIA
-- ============================================
-- ✅ All 7 triggers are listed in STEP 1
-- ✅ Recent notifications show in STEP 2
-- ✅ All expected notification types show in STEP 3
-- ✅ Manual tests in STEPS 4-6 create notifications
-- ✅ Orders have expected notification counts in STEP 9
-- ✅ Offers have expected notification counts in STEP 10
-- ============================================



