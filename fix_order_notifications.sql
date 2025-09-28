-- Fix Order Notifications
-- Check and fix order notification triggers

-- Step 1: Check if order triggers exist
SELECT 'STEP 1: Order Triggers Status' as debug_step;
SELECT trigger_name, event_manipulation, action_timing
FROM information_schema.triggers 
WHERE event_object_table = 'orders'
ORDER BY trigger_name; 

-- Step 2: Check recent orders to see if they should have triggered notifications
SELECT 'STEP 2: Recent Orders' as debug_step;
SELECT 
  id,
  buyer_id,
  seller_id,
  order_status,
  payment_status,
  created_at
FROM orders 
ORDER BY created_at DESC 
LIMIT 5;

-- Step 3: Check if any order notifications were created
SELECT 'STEP 3: Recent Order Notifications' as debug_step;
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  order_id,
  created_at
FROM notifications 
WHERE type LIKE '%order%'
ORDER BY created_at DESC 
LIMIT 5;

-- Step 4: Create working order notification trigger
CREATE OR REPLACE FUNCTION notify_on_order_placed_working()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger on new orders with 'placed' status
  IF NEW.order_status = 'placed' THEN
    -- Create notification for seller
    INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
    VALUES (
      NEW.seller_id,
      'order_placed',
      'New Order Received!',
      'You have a new order to fulfill',
      jsonb_build_object('order_id', NEW.id, 'price_cents', NEW.price_cents),
      NEW.id,
      NEW.buyer_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Create the trigger
DROP TRIGGER IF EXISTS order_notification_trigger ON orders;
DROP TRIGGER IF EXISTS trigger_order_placed_notification ON orders;

CREATE TRIGGER order_notification_trigger_working
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_order_placed_working();

-- Step 6: Test with a manual order (replace with real IDs)
SELECT 'STEP 6: Ready to test' as debug_step;
SELECT 'Get real user and listing IDs:' as instruction;
SELECT 'Users:' as users_label;
SELECT id as user_id, email FROM auth.users LIMIT 3;
SELECT 'Listings:' as listings_label;
SELECT id as listing_id, title, user_id as owner_id FROM listings WHERE status = 'active' LIMIT 3;

SELECT 'Test order creation (replace UUIDs):' as test_instruction;
SELECT '
-- Make sure buyer_id != seller_id (different users!)
INSERT INTO orders (
  listing_id,
  buyer_id,
  seller_id,
  price_cents,
  payment_method,
  order_status,
  payment_status
) VALUES (
  ''LISTING_ID_HERE'',
  ''BUYER_ID_HERE'',
  ''SELLER_ID_HERE'',
  1000,
  ''card'',
  ''placed'',
  ''succeeded''
);
' as test_query;

SELECT 'Order notification trigger recreated!' as result;
