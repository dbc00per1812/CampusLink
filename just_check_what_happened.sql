-- Just check what actually happened in the last 20 minutes

SELECT 'Recent orders:' as info;
SELECT id, buyer_id, seller_id, order_status, payment_status, price_cents, created_at
FROM orders 
WHERE created_at >= NOW() - INTERVAL '20 minutes'
ORDER BY created_at DESC;

SELECT 'Recent notifications:' as info;  
SELECT type, title, user_id, created_at
FROM notifications 
WHERE created_at >= NOW() - INTERVAL '20 minutes'
ORDER BY created_at DESC;

SELECT 'Order trigger exists?:' as info;
SELECT trigger_name FROM information_schema.triggers WHERE trigger_name = 'simple_order_trigger';
