-- Simple check for what happened with your order attempt

-- 1. Check recent orders (last 10 minutes)
SELECT 'Recent orders (last 10 min):' as info;
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
ORDER BY created_at DESC;

-- 2. Check your recent notifications
SELECT 'Your recent notifications:' as your_notifs;
SELECT 
  type,
  title,
  body,
  created_at
FROM notifications 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
  AND created_at >= NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;

-- 3. Check if order trigger exists
SELECT 'Order trigger status:' as trigger_check;
SELECT trigger_name 
FROM information_schema.triggers 
WHERE trigger_name = 'simple_order_trigger';

-- 4. Check if ANY orders exist at all today
SELECT 'All orders today:' as all_today;
SELECT COUNT(*) as order_count
FROM orders 
WHERE created_at >= CURRENT_DATE;
