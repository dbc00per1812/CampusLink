-- TEST ALL NOTIFICATIONS
-- Run this after setup_all_notifications.sql to verify everything works

-- Get test users
SELECT 'Test Users:' as info;
SELECT id, email FROM auth.users ORDER BY created_at DESC LIMIT 3;

-- Get test listing
SELECT 'Test Listing:' as info;
SELECT id, title, user_id FROM listings WHERE status = 'active' LIMIT 1;

-- Instructions for testing each notification type:
SELECT '=== HOW TO TEST EACH NOTIFICATION ===' as instructions;

SELECT '1. ORDER NOTIFICATIONS:' as test_1;
SELECT '   - Create an order (buyer places order on someone else listing)' as step_1;
SELECT '   - Seller should get "New Order!" notification' as expected_1;
SELECT '   - Then seller confirms order -> Buyer gets "Order Confirmed!"' as expected_2;

SELECT '2. OFFER NOTIFICATIONS:' as test_2;
SELECT '   - Find a seek post and make an offer' as step_2;
SELECT '   - Seeker should get "New Offer!" notification' as expected_3;
SELECT '   - Seeker accepts/declines -> Offer maker gets notification' as expected_4;

SELECT '3. MESSAGE NOTIFICATIONS:' as test_3;
SELECT '   - Send a message in any conversation' as step_3;
SELECT '   - Other person gets "New Message" notification' as expected_5;

SELECT '4. PAYMENT NOTIFICATIONS:' as test_4;
SELECT '   - Complete any payment' as step_4;
SELECT '   - Buyer gets "Payment Successful!" notification' as expected_6;

SELECT '5. RATING NOTIFICATIONS:' as test_5;
SELECT '   - Rate someone after a transaction' as step_5;
SELECT '   - They get "New Rating!" notification' as expected_7;

-- Quick manual test
SELECT 'Creating test notification to verify system works:' as manual_test;
INSERT INTO notifications (user_id, type, title, body, data)
SELECT 
  id,
  'marketplace_activity',
  'Notification System Active!',
  'All notification triggers have been installed',
  jsonb_build_object('test', true)
FROM auth.users
ORDER BY created_at DESC
LIMIT 1;

SELECT 'Check your app now - you should see "Notification System Active!"' as verify;
