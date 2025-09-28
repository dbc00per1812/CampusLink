-- Test order notification system

-- 1. Check if the order notification trigger is working
SELECT 
    tgname AS trigger_name,
    tgenabled AS enabled,
    pg_get_triggerdef(oid) AS definition
FROM pg_trigger 
WHERE tgrelid = 'public.orders'::regclass
  AND tgname LIKE '%notification%';

-- 2. Check recent orders to see if they should have triggered notifications
SELECT 
    id,
    buyer_id,
    seller_id,
    order_status,
    created_at,
    updated_at
FROM public.orders 
ORDER BY created_at DESC 
LIMIT 5;

-- 3. Check if there are any order-related notifications
SELECT 
    id,
    user_id,
    type,
    title,
    body,
    data,
    is_delivered,
    created_at
FROM public.notifications 
WHERE type LIKE '%order%'
ORDER BY created_at DESC 
LIMIT 10;

-- 4. Check if the create_notification function exists and works
SELECT proname, pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'create_notification';
