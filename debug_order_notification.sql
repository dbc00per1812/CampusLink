-- Debug: Why didn't you get the order notification?
-- Let's trace what happened with the recent order

-- Step 1: Check the most recent order details
SELECT 'STEP 1: Most Recent Order Details' as debug_step;
SELECT 
  id as order_id,
  listing_id,
  buyer_id,
  seller_id,
  order_status,
  payment_status,
  created_at,
  updated_at
FROM orders 
ORDER BY created_at DESC 
LIMIT 1;

-- Step 2: Check if trigger exists and is working
SELECT 'STEP 2: Order Triggers Status' as debug_step;
SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'orders'
AND trigger_name LIKE '%notification%';

-- Step 3: Check if notification was created for the recent order
SELECT 'STEP 3: Notifications for Recent Order' as debug_step;
SELECT 
  n.id,
  n.user_id,
  n.type,
  n.title,
  n.body,
  n.order_id,
  n.related_user_id,
  n.created_at
FROM notifications n
JOIN orders o ON n.order_id = o.id
WHERE o.created_at >= NOW() - INTERVAL '1 hour'
ORDER BY n.created_at DESC;

-- Step 4: Check your user ID to verify you should have gotten the notification
SELECT 'STEP 4: Your User Info' as debug_step;
SELECT 
  u.id as your_user_id,
  u.email
FROM auth.users u
ORDER BY u.created_at DESC
LIMIT 3;

-- Step 5: Check if the seller_id in the order matches your user_id
SELECT 'STEP 5: Order vs Your User ID Match' as debug_step;
SELECT 
  o.id as order_id,
  o.seller_id as order_seller_id,
  o.buyer_id as order_buyer_id,
  l.user_id as listing_owner_id,
  l.title as listing_title
FROM orders o
JOIN listings l ON o.listing_id = l.id
ORDER BY o.created_at DESC
LIMIT 1;

-- Step 6: Manual trigger test
SELECT 'STEP 6: Manual Notification Test' as debug_step;
SELECT 'Run this to create a test notification:' as instruction;
SELECT '
-- Replace YOUR_USER_ID with your actual user ID from Step 4
INSERT INTO notifications (user_id, type, title, body, data)
VALUES (
  ''YOUR_USER_ID_HERE'',
  ''order_placed'',
  ''Manual Test Order'',
  ''Testing if notifications appear in app'',
  jsonb_build_object(''test'', true)
);
' as manual_test;

SELECT 'DIAGNOSIS:' as diagnosis;
SELECT 'If no trigger found: Trigger creation failed' as issue_1;
SELECT 'If notification exists but you didnt see it: App notification fetching issue' as issue_2;
SELECT 'If seller_id != your_user_id: Order not for your listing' as issue_3;
SELECT 'If order_status != placed: Trigger condition not met' as issue_4;
