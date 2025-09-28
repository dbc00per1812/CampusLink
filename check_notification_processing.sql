-- Check if there's a system to process database notifications into push notifications

-- 1. Check for any triggers on the notifications table
SELECT 
    tgname AS trigger_name,
    tgenabled AS enabled,
    pg_get_triggerdef(oid) AS definition
FROM pg_trigger 
WHERE tgrelid = 'public.notifications'::regclass;

-- 2. Check for any cron jobs that might process notifications
SELECT 
    jobname,
    schedule,
    command,
    active
FROM cron.job
WHERE command LIKE '%notification%' OR command LIKE '%push%';

-- 3. Check recent notifications that haven't been delivered
SELECT 
    id,
    recipient_id,
    notification_type,
    title,
    body,
    is_read,
    created_at,
    delivered_at,
    push_sent_at,
    CASE 
        WHEN delivered_at IS NULL THEN 'NOT_DELIVERED'
        WHEN push_sent_at IS NULL THEN 'DELIVERED_NO_PUSH'
        ELSE 'FULLY_DELIVERED'
    END as delivery_status
FROM public.notifications 
WHERE created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC 
LIMIT 20;

-- 4. Check if there's a function to process pending notifications
SELECT 
    proname AS function_name,
    pg_get_functiondef(oid) AS definition
FROM pg_proc 
WHERE proname LIKE '%process%notification%' 
   OR proname LIKE '%send%push%'
   OR proname LIKE '%notification%queue%';

-- 5. Check user notification preferences to see if push is enabled
SELECT 
    user_id,
    push_notifications_enabled,
    order_notifications_enabled,
    push_token IS NOT NULL as has_push_token,
    LENGTH(push_token) as token_length
FROM public.user_notification_preferences
LIMIT 10;
