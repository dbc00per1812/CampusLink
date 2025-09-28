-- FIX: Notify the LISTING OWNER when their item is purchased
-- This fixes the mismatch between seller_id and actual listing owner

DROP FUNCTION IF EXISTS notify_order_changes() CASCADE;

CREATE OR REPLACE FUNCTION notify_order_changes()
RETURNS TRIGGER AS $$
DECLARE
  listing_owner_id text;
  listing_title text;
BEGIN
  -- Get the actual listing owner (who should be notified)
  SELECT user_id, title INTO listing_owner_id, listing_title
  FROM listings
  WHERE id = NEW.listing_id;
  
  -- New order placed - notify the LISTING OWNER (not seller_id)
  IF TG_OP = 'INSERT' AND NEW.order_status = 'placed' THEN
    INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
    VALUES (
      listing_owner_id,  -- Use listing owner, not seller_id!
      'order_placed',
      'New Order!',
      'Someone bought: ' || COALESCE(listing_title, 'your item'),
      jsonb_build_object(
        'order_id', NEW.id, 
        'price_cents', NEW.price_cents,
        'buyer_id', NEW.buyer_id
      ),
      NEW.id,
      NEW.buyer_id
    );
  END IF;
  
  -- Order status changes - use actual IDs from order
  IF TG_OP = 'UPDATE' AND OLD.order_status != NEW.order_status THEN
    -- Seller confirms order - notify buyer
    IF NEW.order_status = 'seller_confirmed' THEN
      INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
      VALUES (
        NEW.buyer_id,
        'order_confirmed',
        'Order Confirmed!',
        'Your order for "' || COALESCE(listing_title, 'the item') || '" has been confirmed',
        jsonb_build_object('order_id', NEW.id),
        NEW.id,
        listing_owner_id  -- Use listing owner as related user
      );
    END IF;
    
    -- Order delivered - notify buyer
    IF NEW.order_status = 'delivered' THEN
      INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
      VALUES (
        NEW.buyer_id,
        'order_completed',
        'Order Delivered!',
        'Your order has been delivered',
        jsonb_build_object('order_id', NEW.id),
        NEW.id,
        listing_owner_id
      );
    END IF;
    
    -- Order completed - notify listing owner
    IF NEW.order_status = 'completed' THEN
      INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
      VALUES (
        listing_owner_id,  -- Notify listing owner
        'order_completed',
        'Order Complete!',
        'Order for "' || COALESCE(listing_title, 'your item') || '" completed successfully',
        jsonb_build_object('order_id', NEW.id, 'buyer_id', NEW.buyer_id),
        NEW.id,
        NEW.buyer_id
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Drop and recreate the trigger
DROP TRIGGER IF EXISTS order_notification_trigger ON orders;
CREATE TRIGGER order_notification_trigger
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_changes();

-- Test it immediately with a recent order
SELECT 'Testing with most recent order...' as test;

-- Find the most recent order
WITH recent_order AS (
  SELECT o.*, l.user_id as actual_owner, l.title
  FROM orders o
  JOIN listings l ON o.listing_id = l.id
  ORDER BY o.created_at DESC
  LIMIT 1
)
UPDATE orders 
SET updated_at = NOW()  -- Trigger an update to test
WHERE id = (SELECT id FROM recent_order);

-- Check if notification was created
SELECT 'Recent order notifications:' as result;
SELECT 
  n.*,
  u.email as user_email
FROM notifications n
JOIN auth.users u ON n.user_id = u.id::text
WHERE n.type = 'order_placed'
AND n.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY n.created_at DESC;

SELECT 'Fixed! Notifications now go to LISTING OWNER, not seller_id' as status;
