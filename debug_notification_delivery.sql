-- Debug notification delivery system

-- 1. Check recent notifications and their delivery status
SELECT 
    id,
    user_id,  -- Fixed: using user_id instead of recipient_id
    notification_type,
    title,
    body,
    data,
    is_read,
    created_at,
    delivered_at,
    push_sent_at
FROM public.notifications 
ORDER BY created_at DESC 
LIMIT 10;

-- 2. Check if users have push tokens
SELECT 
    id,
    email,
    push_token IS NOT NULL as has_push_token,
    LENGTH(push_token) as token_length,
    updated_at as token_updated
FROM auth.users 
WHERE push_token IS NOT NULL
ORDER BY updated_at DESC
LIMIT 5;

-- 3. Check notification preferences
SELECT 
    user_id,
    push_notifications_enabled,
    order_notifications_enabled,
    created_at
FROM public.user_notification_preferences
ORDER BY created_at DESC
LIMIT 10;

-- 4. Check if there are any failed push notification logs
SELECT 
    notification_id,
    status,
    error_message,
    created_at
FROM public.push_notification_logs
ORDER BY created_at DESC
LIMIT 10;
