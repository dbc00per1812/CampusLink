-- Check the very latest order and see what happened

-- Step 1: Check the absolute latest order
SELECT 'Latest Order:' as info;
SELECT 
  id,
  listing_id,
  buyer_id,
  seller_id,
  order_status,
  payment_status,
  created_at
FROM orders 
ORDER BY created_at DESC 
LIMIT 1;

-- Step 2: Check if notification was created for this latest order
SELECT 'Notification for Latest Order:' as info;
SELECT 
  n.id,
  n.user_id,
  n.type,
  n.title,
  n.created_at,
  o.id as order_id,
  o.created_at as order_created_at
FROM notifications n
RIGHT JOIN orders o ON n.order_id = o.id
WHERE o.created_at = (SELECT MAX(created_at) FROM orders)
ORDER BY n.created_at DESC;

-- Step 3: Check your user ID
SELECT 'Your User ID:' as info;
SELECT id, email FROM auth.users WHERE email LIKE '%buckled%' OR email LIKE '%lu.edu%';

-- Step 4: Manual test - create a notification for you right now
SELECT 'Creating manual test notification...' as info;
INSERT INTO notifications (user_id, type, title, body, data, created_at)
VALUES (
  '50b58786-ffe6-4b99-b7d3-a1b12e21c539',  -- Your user ID
  'order_placed',
  'MANUAL TEST NOTIFICATION',
  'If you see this in your app, the app can display notifications',
  jsonb_build_object('test', true, 'timestamp', NOW()),
  NOW()
);

-- Step 5: Check if the manual notification was created
SELECT 'Manual Notification Check:' as info;
SELECT * FROM notifications 
WHERE title = 'MANUAL TEST NOTIFICATION'
ORDER BY created_at DESC;

SELECT 'INSTRUCTIONS:' as instructions;
SELECT 'Check your CampusLink app notifications NOW' as step_1;
SELECT 'If manual test shows up: Triggers are broken' as diagnosis_1;
SELECT 'If manual test does NOT show up: App notification display broken' as diagnosis_2;
