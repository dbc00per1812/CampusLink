-- Simple notification check without type casting issues

-- Just check notifications directly
SELECT 'All recent notifications (last 10 minutes):' as info;
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  created_at
FROM notifications 
WHERE created_at > NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;

-- Check specifically for your notifications
SELECT 'Your recent notifications:' as your_notifs;
SELECT 
  id,
  type,
  title,
  body,
  created_at
FROM notifications 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
ORDER BY created_at DESC
LIMIT 10;

-- Check if trigger exists
SELECT 'Order notification trigger status:' as trigger_check;
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'orders'
AND trigger_name = 'order_notification_trigger';

SELECT 'If you see notifications above, the system is working!' as result;
