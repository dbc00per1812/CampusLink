-- Test the complete notification flow

-- 1. Check if users have push notification preferences set up
SELECT 
    COUNT(*) as total_users_with_prefs,
    COUNT(*) FILTER (WHERE push_notifications_enabled = true) as push_enabled_users,
    COUNT(*) FILTER (WHERE push_token IS NOT NULL AND push_token != '') as users_with_tokens
FROM public.user_notification_preferences;

-- 2. Create a test notification to verify the trigger works
INSERT INTO public.notifications (
    user_id,
    type,
    title,
    body,
    data,
    is_delivered
) VALUES (
    (SELECT user_id FROM public.user_notification_preferences LIMIT 1), -- Use an existing user
    'test_notification',
    'Test Notification',
    'This is a test to verify the notification system works',
    '{"test": true}'::jsonb,
    false
);

-- 3. Check if the test notification was created
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

-- 4. Process the test notification
SELECT * FROM process_and_send_notifications();

-- 5. Verify the test notification was processed
SELECT 
    id,
    user_id,
    type,
    title,
    is_delivered,
    delivered_at,
    created_at
FROM public.notifications 
WHERE type = 'test_notification'
ORDER BY created_at DESC
LIMIT 1;
