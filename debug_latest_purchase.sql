-- Debug: Why didn't you get notified for the latest purchase?

-- Step 1: Get the most recent order where YOU are the seller
SELECT 'Latest order where you are the SELLER:' as info;
SELECT 
  o.id as order_id,
  o.buyer_id,
  o.seller_id,
  o.order_status,
  o.payment_status,
  o.created_at,
  l.title as listing_title,
  l.user_id as listing_owner
FROM orders o
JOIN listings l ON o.listing_id = l.id
WHERE o.seller_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'  -- Your user ID
   OR l.user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'     -- Or listing owner is you
ORDER BY o.created_at DESC
LIMIT 1;

-- Step 2: Check if notification was created for this order
SELECT 'Notifications for your recent sales:' as info;
SELECT 
  n.id,
  n.type,
  n.title,
  n.body,
  n.created_at,
  n.order_id
FROM notifications n
WHERE n.user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
  AND n.type = 'order_placed'
ORDER BY n.created_at DESC
LIMIT 5;

-- Step 3: Check if the trigger exists
SELECT 'Order notification trigger status:' as info;
SELECT 
  trigger_name,
  event_manipulation,
  action_timing,
  action_statement
FROM information_schema.triggers 
WHERE event_object_table = 'orders'
AND trigger_name = 'order_notification_trigger';

-- Step 4: Test the trigger manually with your user as seller
SELECT 'Creating test order with YOU as seller:' as info;
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
  (SELECT id FROM listings WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539' AND status = 'active' LIMIT 1),
  'dc385c1b-77a4-4c96-91d4-3f5315ab4588',  -- John as buyer
  '50b58786-ffe6-4b99-b7d3-a1b12e21c539',  -- You as seller
  1999,
  'card',
  'placed',
  'succeeded',
  NOW(),
  NOW()
);

-- Step 5: Check if test notification was created
SELECT 'Check for test order notification:' as verify;
SELECT * FROM notifications 
WHERE user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
  AND type = 'order_placed'
  AND created_at > NOW() - INTERVAL '1 minute'
ORDER BY created_at DESC;

-- Step 6: Common issues
SELECT 'POSSIBLE ISSUES:' as diagnosis;
SELECT 'If no notification: Trigger not working' as issue_1;
SELECT 'If seller_id != your_id: Order assigned to wrong user' as issue_2;
SELECT 'If listing owner != seller_id: Mismatch in order creation' as issue_3;
