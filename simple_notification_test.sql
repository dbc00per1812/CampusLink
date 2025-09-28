-- Simple test without relying on specific column names

-- 1. Check if there are any users in the system
SELECT COUNT(*) as total_users FROM auth.users;

-- 2. Check if user_notification_preferences table exists and has data
SELECT COUNT(*) as total_prefs FROM public.user_notification_preferences;

-- 3. Create a test notification for any existing user
INSERT INTO public.notifications (
    user_id,
    type,
    title,
    body,
    data,
    is_delivered
) 
SELECT 
    id,
    'test_notification',
    'Test Notification',
    'This is a test to verify the notification system works',
    '{"test": true}'::jsonb,
    false
FROM auth.users 
LIMIT 1;

-- 4. Check if the test notification was created
SELECT 
    id,
    user_id,
    type,
    title,
    is_delivered,
    created_at
FROM public.notifications 
WHERE type = 'test_notification'
ORDER BY created_at DESC
LIMIT 1;

-- 5. Check current notification counts
SELECT 
    COUNT(*) as total_notifications,
    COUNT(*) FILTER (WHERE is_delivered = true) as delivered_count,
    COUNT(*) FILTER (WHERE is_delivered = false) as pending_count
FROM public.notifications 
WHERE created_at > NOW() - INTERVAL '1 hour';
