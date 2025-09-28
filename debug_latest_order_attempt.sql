-- Debug the latest order attempt - check if push queue got populated

-- 1. Check recent orders (last 10 minutes)
SELECT 'Recent orders (last 10 min):' as info;
SELECT id, buyer_id, seller_id, price_cents, created_at
FROM orders 
WHERE created_at >= NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC
LIMIT 3;

-- 2. Check recent database notifications  
SELECT 'Recent database notifications:' as info;
SELECT type, title, user_id, created_at
FROM notifications 
WHERE created_at >= NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC
LIMIT 5;

-- 3. Check recent push queue entries
SELECT 'Recent push queue entries:' as info;
SELECT notification_type, title, user_id, processed, created_at
FROM push_notification_queue 
WHERE created_at >= NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC
LIMIT 5;

-- 4. Check current trigger
SELECT 'Current order trigger:' as info;
SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'orders';

-- 5. Check if your push preferences are correct
SELECT 'Your push preferences:' as info;
SELECT push_enabled, order_notifications, push_token IS NOT NULL as has_token
FROM user_notification_preferences 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539';
