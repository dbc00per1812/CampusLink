-- Debug: What should the app be seeing?
-- This mimics exactly what the NotificationService.fetchNotifications() query does

-- Step 1: Show exactly what the app's query returns
SELECT 'What app should fetch (ordered by created_at DESC):' as info;
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  is_read,
  is_delivered,
  order_id,
  message_id,
  listing_id,
  related_user_id,
  created_at
FROM notifications
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'  -- Your user ID
ORDER BY created_at DESC
LIMIT 50;

-- Step 2: Count notifications by type for your user
SELECT 'Notification counts by type for your user:' as info;
SELECT 
  type,
  COUNT(*) as count,
  COUNT(*) FILTER (WHERE is_read = false) as unread_count
FROM notifications 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
GROUP BY type
ORDER BY count DESC;

-- Step 3: Show the most recent notifications of each type
SELECT 'Most recent notification of each type:' as info;
WITH ranked_notifications AS (
  SELECT 
    *,
    ROW_NUMBER() OVER (PARTITION BY type ORDER BY created_at DESC) as rn
  FROM notifications
  WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
)
SELECT 
  type,
  title,
  body,
  is_read,
  created_at
FROM ranked_notifications
WHERE rn = 1
ORDER BY created_at DESC;

-- Step 4: Check if there are any decoding issues
SELECT 'Check for potential decoding problems:' as info;
SELECT 
  id,
  type,
  title,
  length(data::text) as data_length,
  data,
  created_at
FROM notifications
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
AND type = 'order_placed'
ORDER BY created_at DESC
LIMIT 5;

-- Step 5: Manual app refresh test
SELECT 'Creating a fresh test notification with current timestamp:' as info;
INSERT INTO notifications (user_id, type, title, body, data, created_at)
VALUES (
  '50b58786-ffe6-4b99-b7d3-a1b12e21c539',
  'order_placed',
  'APP REFRESH TEST - Order Notification',
  'This should appear immediately after you refresh in the app',
  jsonb_build_object('test', true, 'created', NOW()::text),
  NOW()
);

SELECT 'Test notification created! Refresh your app notifications now.' as instruction;
