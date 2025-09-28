-- Test Notification Flow
-- This script tests the end-to-end notification flow

-- Step 1: Get your user ID (replace with your actual user email)
-- SELECT id, email FROM auth.users WHERE email = 'your-email@example.com';

-- Step 2: Create a test notification (replace 'your-user-id' with actual UUID)
/*
INSERT INTO notifications (
  user_id,
  type,
  title,
  body,
  data,
  is_read,
  is_delivered
) VALUES (
  'your-user-id-here',
  'order_placed',
  'Test Notification',
  'This is a test notification to verify the system works',
  jsonb_build_object('test', true),
  false,
  false
);
*/

-- Step 3: Check if notification was created
SELECT * FROM notifications WHERE title = 'Test Notification' ORDER BY created_at DESC LIMIT 1;

-- Step 4: Check if push notification was queued (if user has push enabled)
SELECT * FROM push_notification_queue WHERE title = 'Test Notification' ORDER BY created_at DESC LIMIT 1;

-- Step 5: Check user's notification preferences
-- SELECT * FROM user_notification_preferences WHERE user_id = 'your-user-id-here';

-- Step 6: Test creating an order to trigger real notification
-- First get some real user IDs and listing IDs from your database
SELECT 'User IDs:' as info;
SELECT id, email FROM auth.users LIMIT 3;

SELECT 'Listing IDs:' as info;  
SELECT id, title, user_id as owner_id FROM listings WHERE status = 'active' LIMIT 3;

-- Step 7: Instructions for manual order creation
/*
To test order notifications, create a real order:

1. Replace the UUIDs below with real values from the queries above
2. Make sure buyer_id ≠ seller_id (different users)
3. Uncomment and run:

INSERT INTO orders (
  listing_id,
  buyer_id,
  seller_id,
  price_cents,
  payment_method,
  order_status,
  payment_status,
  created_at,
  updated_at
) VALUES (
  'real-listing-id-here',
  'real-buyer-id-here', 
  'real-seller-id-here',
  1000,
  'card',
  'placed',
  'succeeded',
  now(),
  now()
);

4. Check if notification was created:
SELECT * FROM notifications WHERE type = 'order_placed' ORDER BY created_at DESC LIMIT 1;

5. Check push queue:
SELECT * FROM push_notification_queue WHERE notification_type = 'order_placed' ORDER BY created_at DESC LIMIT 1;
*/
