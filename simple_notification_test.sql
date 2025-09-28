-- Simple Notification Test
-- Run this AFTER setup_notifications_now.sql

-- Step 1: Check if setup worked
SELECT 'Checking setup...' as step;

-- Check tables exist
SELECT table_name FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('notifications', 'user_notification_preferences');

-- Check triggers exist  
SELECT trigger_name FROM information_schema.triggers 
WHERE event_object_table = 'orders' 
AND trigger_name LIKE '%notification%';

-- Step 2: Get test data
SELECT 'Getting test data...' as step;

-- Get 2 different users (you need different buyer/seller)
SELECT id, email FROM auth.users ORDER BY created_at DESC LIMIT 3;

-- Get a listing
SELECT id, title, user_id FROM listings WHERE status = 'active' LIMIT 2;

-- Step 3: Create test order (REPLACE UUIDs WITH REAL ONES)
SELECT 'Ready to test! Replace UUIDs below and uncomment:' as step;

/*
INSERT INTO orders (
  listing_id,
  buyer_id,
  seller_id, 
  price_cents,
  payment_method,
  order_status,
  payment_status
) VALUES (
  'REPLACE_WITH_LISTING_ID',
  'REPLACE_WITH_BUYER_ID',
  'REPLACE_WITH_SELLER_ID',
  1000,
  'card', 
  'placed',
  'succeeded'
);
*/

-- Step 4: Check if notification was created
SELECT 'Checking for notifications...' as step;
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 3;
