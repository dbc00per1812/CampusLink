-- Check current push notification setup

SELECT '=== USER PUSH PREFERENCES ===' as info;
SELECT 
  user_id,
  push_enabled,
  push_token IS NOT NULL as has_token,
  order_notifications,
  message_notifications
FROM user_notification_preferences 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539';

SELECT '=== RECENT PUSH QUEUE ENTRIES ===' as info;
SELECT 
  user_id,
  notification_type,
  title,
  processed,
  created_at
FROM push_notification_queue 
WHERE created_at >= NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;

SELECT '=== RECENT NOTIFICATIONS ===' as info;
SELECT 
  user_id,
  type,
  title,
  created_at
FROM notifications 
WHERE created_at >= NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
