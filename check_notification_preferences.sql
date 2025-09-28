-- Check user notification preferences to see why order notifications aren't working

-- 1. Check the structure of user_notification_preferences
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_notification_preferences'
ORDER BY ordinal_position;

-- 2. Check actual user preferences data
SELECT 
    user_id,
    push_enabled,
    order_notifications,
    message_notifications,
    payment_notifications,
    rating_notifications,
    marketplace_notifications,
    push_token IS NOT NULL as has_push_token
FROM public.user_notification_preferences
LIMIT 10;

-- 3. Check if there are users without notification preferences set up
SELECT 
    COUNT(*) as total_users,
    COUNT(unp.user_id) as users_with_prefs
FROM auth.users u
LEFT JOIN public.user_notification_preferences unp ON u.id = unp.user_id;

-- 4. Check recent orders and their sellers
SELECT 
    o.id as order_id,
    o.seller_id,
    o.buyer_id,
    o.order_status,
    o.created_at,
    unp.push_enabled,
    unp.order_notifications,
    unp.push_token IS NOT NULL as has_push_token
FROM public.orders o
LEFT JOIN public.user_notification_preferences unp ON o.seller_id = unp.user_id
ORDER BY o.created_at DESC
LIMIT 5;
