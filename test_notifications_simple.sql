-- Simple Notification Test
-- Run this AFTER running setup_notifications_now.sql

-- Step 1: Get your user IDs (you'll need 2 different users)
SELECT id, email FROM auth.users ORDER BY created_at DESC LIMIT 5;

-- Step 2: Get a listing ID 
SELECT id, title, user_id as owner_id FROM listings WHERE status = 'active' LIMIT 3;

-- Step 3: Create a test order (REPLACE THE UUIDs WITH REAL ONES FROM ABOVE)
-- Make sure buyer_id ≠ seller_id (different users)
/*
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
  'REPLACE_WITH_REAL_LISTING_ID',
  'REPLACE_WITH_BUYER_ID',
  'REPLACE_WITH_SELLER_ID', 
  1500,
  'card',
  'placed',
  'succeeded',
  now(),
  now()
);
*/

-- Step 4: Check if notification was created
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  created_at
FROM notifications 
WHERE type = 'order_placed' 
ORDER BY created_at DESC 
LIMIT 1;

-- If you see a notification above, it's working! 🎉
-- If not, check that:
-- 1. buyer_id ≠ seller_id (different users)  
-- 2. The UUIDs are real values from your database
-- 3. The triggers were created (run quick_notification_check.sql)
