-- Test if order notifications are working with the simple trigger

-- 1. Check if the simple order trigger exists
SELECT 'Order trigger status:' as info;
SELECT trigger_name, event_object_table
FROM information_schema.triggers 
WHERE trigger_name = 'simple_order_trigger';

-- 2. Create a test notification manually to verify app can display them
INSERT INTO notifications (user_id, type, title, body, data)
VALUES (
  '50b58786-ffe6-4b99-b7d3-a1b12e21c539',
  'order_placed',
  'TEST: Manual Order Notification',
  'Testing if order notifications show in app',
  jsonb_build_object('test', true)
);

-- 3. Check your recent notifications
SELECT 'Your recent notifications:' as your_notifs;
SELECT 
  type,
  title,
  body,
  created_at
FROM notifications 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
ORDER BY created_at DESC
LIMIT 5;

SELECT 'Steps:' as instructions;
SELECT '1. Check your app - do you see the TEST notification above?' as step_1;
SELECT '2. If yes, have someone buy one of your items' as step_2;
SELECT '3. You should get "New Order!" notification when they buy' as step_3;
