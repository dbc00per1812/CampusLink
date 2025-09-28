-- Debug what's happening with the order trigger right now

-- 1. Check most recent order
SELECT 'Most recent order:' as info;
SELECT id, buyer_id, seller_id, listing_id, price_cents, created_at
FROM orders 
ORDER BY created_at DESC 
LIMIT 1;

-- 2. Check if that order created a database notification
WITH recent_order AS (
  SELECT id, created_at FROM orders ORDER BY created_at DESC LIMIT 1
)
SELECT 'Database notification for recent order:' as info;
SELECT n.type, n.title, n.user_id, n.created_at
FROM notifications n, recent_order r
WHERE n.order_id = r.id;

-- 3. Check if that order created a push queue entry
WITH recent_order AS (
  SELECT id, created_at FROM orders ORDER BY created_at DESC LIMIT 1
)
SELECT 'Push queue for recent order:' as info;
SELECT pq.notification_type, pq.title, pq.user_id, pq.created_at
FROM push_notification_queue pq, recent_order r
WHERE pq.data->>'order_id' = r.id::text;

-- 4. Check what triggers exist on orders table
SELECT 'Current order triggers:' as info;
SELECT trigger_name, event_object_table
FROM information_schema.triggers 
WHERE event_object_table = 'orders';

-- 5. Check the actual trigger function source
SELECT 'Trigger function source:' as info;
SELECT routine_name, routine_definition 
FROM information_schema.routines 
WHERE routine_name LIKE '%order%trigger%' 
AND routine_type = 'FUNCTION';
