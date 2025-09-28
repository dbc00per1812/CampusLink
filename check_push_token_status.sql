-- Quick Check: Why aren't you getting push notifications?
-- Run this first to identify the main issue

-- Step 1: Check if you have a push token registered
SELECT 'STEP 1: Push Token Check' as debug_step;

-- Check your user preferences (replace YOUR_EMAIL with your actual email)
SELECT 
  u.id as user_id,
  u.email,
  unp.push_enabled,
  unp.push_token,
  unp.order_notifications,
  unp.message_notifications,
  unp.marketplace_notifications,
  unp.created_at
FROM auth.users u
LEFT JOIN user_notification_preferences unp ON u.id::text = unp.user_id
WHERE u.email = 'YOUR_EMAIL_HERE'  -- REPLACE WITH YOUR EMAIL
ORDER BY u.created_at DESC;

-- Step 2: Check if notifications are being created in database
SELECT 'STEP 2: Recent Notifications' as debug_step;
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
LIMIT 10;

-- Step 3: Check push notification queue
SELECT 'STEP 3: Push Queue Status' as debug_step;
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
LIMIT 10;

-- Step 4: Count unread notifications per user
SELECT 'STEP 4: Unread Counts' as debug_step;
SELECT 
  user_id,
  COUNT(*) as unread_count
FROM notifications 
WHERE is_read = false 
GROUP BY user_id 
ORDER BY unread_count DESC 
LIMIT 5;

-- DIAGNOSIS:
SELECT '=== DIAGNOSIS ===' as diagnosis;
SELECT 'If push_token is NULL: You need to enable notifications in iOS Settings > CampusLink' as issue_1;
SELECT 'If notifications exist but queue is empty: Triggers not creating push queue entries' as issue_2;
SELECT 'If queue has unprocessed entries: Edge function not running or not deployed' as issue_3;
SELECT 'If no notifications at all: Database triggers not created' as issue_4;
