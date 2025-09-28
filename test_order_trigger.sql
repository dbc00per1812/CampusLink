-- Test if order notification trigger is working

-- 1. Check if the trigger exists
SELECT 'Order trigger status:' as info;
SELECT trigger_name, event_object_table
FROM information_schema.triggers 
WHERE event_object_table = 'orders'
ORDER BY trigger_name;

-- 2. Check recent notifications
SELECT 'Recent order notifications:' as order_notifs;
SELECT type, title, user_id, created_at
FROM notifications 
WHERE type = 'order_placed' 
AND created_at >= NOW() - INTERVAL '2 hours'
ORDER BY created_at DESC;

-- 3. Check recent push queue entries for orders
SELECT 'Recent order push queue:' as push_queue;
SELECT notification_type, title, user_id, processed, created_at
FROM push_notification_queue 
WHERE notification_type = 'order_placed'
AND created_at >= NOW() - INTERVAL '2 hours'
ORDER BY created_at DESC;
