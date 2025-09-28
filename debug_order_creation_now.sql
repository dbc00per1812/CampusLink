-- Check if order was actually created and if notification triggered

-- 1. Check recent orders (last 10 minutes)
SELECT 'Recent orders:' as info;
SELECT 
  id,
  buyer_id,
  seller_id,
  order_status,
  payment_status,
  price_cents,
  created_at
FROM orders 
WHERE created_at >= NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC
LIMIT 3;

-- 2. Check if your user ID is correct
SELECT 'Your user ID check:' as check_user;
SELECT id, email 
FROM auth.users 
WHERE id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539';

-- 3. Check recent notifications for you
SELECT 'Your recent notifications:' as your_notifs;
SELECT 
  type,
  title,
  body,
  created_at,
  order_id
FROM notifications 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
  AND created_at >= NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;

-- 4. Check if order trigger exists
SELECT 'Order trigger status:' as trigger_check;
SELECT trigger_name, event_object_table
FROM information_schema.triggers 
WHERE trigger_name = 'simple_order_trigger';

-- 5. If there was an order, check if notification was created
WITH recent_order AS (
  SELECT id, seller_id, buyer_id
  FROM orders 
  WHERE created_at >= NOW() - INTERVAL '10 minutes'
  ORDER BY created_at DESC 
  LIMIT 1
)
SELECT 'Order notification check:' as order_notif_check;
SELECT 
  'Order seller_id: ' || o.seller_id as order_info,
  'Notification count: ' || COUNT(n.id) as notif_count
FROM recent_order o
LEFT JOIN notifications n ON n.user_id = o.seller_id AND n.order_id = o.id
GROUP BY o.seller_id;
