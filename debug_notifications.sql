-- Debug Notifications System
-- Run this to check if everything is set up correctly

-- 1. Check if notification triggers exist
SELECT 
  schemaname,
  tablename,
  triggername,
  definition
FROM pg_triggers 
WHERE triggername LIKE '%notification%'
ORDER BY tablename, triggername;

-- 2. Check if notification functions exist
SELECT 
  proname as function_name,
  prorettype::regtype as return_type
FROM pg_proc 
WHERE proname LIKE '%notification%'
ORDER BY proname;

-- 3. Check recent notifications created
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  data,
  is_read,
  is_delivered,
  order_id,
  listing_id,
  created_at
FROM notifications 
ORDER BY created_at DESC 
LIMIT 10;

-- 4. Check push notification queue
SELECT 
  id,
  user_id,
  notification_type,
  title,
  body,
  data,
  processed,
  error,
  created_at
FROM push_notification_queue 
ORDER BY created_at DESC 
LIMIT 10;

-- 5. Check user notification preferences for current users
SELECT 
  user_id,
  push_enabled,
  push_token,
  order_notifications,
  marketplace_notifications,
  created_at
FROM user_notification_preferences
ORDER BY created_at DESC
LIMIT 5;

-- 6. Check recent orders to see if they should have triggered notifications
SELECT 
  id,
  buyer_id,
  seller_id,
  order_status,
  payment_status,
  created_at,
  updated_at
FROM orders 
ORDER BY created_at DESC 
LIMIT 5;

-- 7. Check recent offers
SELECT 
  id,
  seek_listing_id,
  seller_id,
  seeker_id,
  status,
  price_cents,
  created_at
FROM offers 
ORDER BY created_at DESC 
LIMIT 5;

-- 8. Test notification creation manually (replace with actual user IDs)
-- INSERT INTO notifications (
--   user_id,
--   type,
--   title,
--   body,
--   data
-- ) VALUES (
--   'your-user-id-here',
--   'order_placed',
--   'Test Notification',
--   'This is a test notification',
--   '{}'::jsonb
-- );

-- 9. Count unread notifications per user
SELECT 
  user_id,
  COUNT(*) as unread_count
FROM notifications 
WHERE is_read = false
GROUP BY user_id
ORDER BY unread_count DESC;

-- 10. Check if tables exist
SELECT table_name, table_type 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('notifications', 'user_notification_preferences', 'push_notification_queue')
ORDER BY table_name;
