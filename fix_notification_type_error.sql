-- Fix the type casting error in the notification query

-- Check recent order notifications with proper type casting
SELECT 'Recent order notifications:' as result;
SELECT 
  n.id,
  n.user_id,
  n.type,
  n.title,
  n.body,
  n.created_at,
  u.email as user_email
FROM notifications n
JOIN auth.users u ON n.user_id = u.id::text  -- Cast uuid to text
WHERE n.type = 'order_placed'
AND n.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY n.created_at DESC;

-- Also check ALL recent notifications for your user
SELECT 'All recent notifications for you:' as your_notifications;
SELECT 
  id,
  type,
  title,
  body,
  created_at
FROM notifications 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
AND created_at > NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;

SELECT 'Type casting fixed - notifications should work now!' as status;
