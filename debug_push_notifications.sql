-- Debug Push Notification Delivery
-- Run this to see why push notifications aren't being delivered

-- Step 1: Check if user has push token registered
SELECT 'Step 1: Push Token Registration' as debug_step;
SELECT 
  user_id,
  push_enabled,
  push_token,
  push_platform,
  order_notifications,
  marketplace_notifications,
  created_at
FROM user_notification_preferences
ORDER BY created_at DESC
LIMIT 5;

-- If push_token is NULL, that's the problem!

-- Step 2: Check recent notifications in database
SELECT 'Step 2: Recent Notifications in Database' as debug_step;
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  is_delivered,
  created_at
FROM notifications
ORDER BY created_at DESC
LIMIT 5;

-- Step 3: Check if push notification queue exists and has entries
SELECT 'Step 3: Push Notification Queue' as debug_step;
SELECT 
  id,
  user_id,
  notification_type,
  title,
  processed,
  error,
  created_at
FROM push_notification_queue
ORDER BY created_at DESC
LIMIT 5;

-- Step 4: Check if messages create notifications (they might not have triggers)
SELECT 'Step 4: Message-related notifications' as debug_step;
SELECT * FROM notifications WHERE type = 'new_message' ORDER BY created_at DESC LIMIT 3;

-- Step 5: Check what edge functions exist
-- (You'll need to check this in Supabase dashboard > Edge Functions)

SELECT 'Debug Summary:' as info;
SELECT 'If push_token is NULL: User needs to register for notifications in iOS app' as fix_1;
SELECT 'If queue is empty: Triggers need to queue push notifications' as fix_2;  
SELECT 'If queue has unprocessed entries: Edge function not running' as fix_3;
SELECT 'If no message notifications: Message triggers missing' as fix_4;
