-- FINAL WORKING ORDER TRIGGER - Copy exact message pattern

-- Remove any broken order triggers
DROP TRIGGER IF EXISTS simple_working_order_trigger ON orders;
DROP TRIGGER IF EXISTS notify_on_order_trigger ON orders;
DROP FUNCTION IF EXISTS simple_working_order_function();
DROP FUNCTION IF EXISTS notify_on_order();

-- Create the exact same pattern as working message notifications
CREATE OR REPLACE FUNCTION order_notification_trigger()
RETURNS TRIGGER AS $$
DECLARE
  listing_owner_id UUID;
BEGIN
  -- Get listing owner
  SELECT user_id INTO listing_owner_id 
  FROM listings 
  WHERE id = NEW.listing_id;
  
  -- Only create notifications if owner exists and not self-purchase
  IF listing_owner_id IS NOT NULL AND listing_owner_id != NEW.buyer_id THEN
    
    -- 1. Create database notification
    INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
    VALUES (
      listing_owner_id,
      'order_placed',
      'New Order!',
      'Someone bought your item',
      jsonb_build_object('order_id', NEW.id::text),
      NEW.id,
      NEW.buyer_id
    );
    
    -- 2. Create push notification queue entry
    INSERT INTO push_notification_queue (user_id, notification_type, title, body, data)
    VALUES (
      listing_owner_id,
      'order_placed',
      'New Order!',
      'Someone bought your item',
      jsonb_build_object('order_id', NEW.id::text, 'type', 'order_placed')
    );
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER order_notification_trigger
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION order_notification_trigger();

-- Test it immediately
SELECT 'Order notification trigger created' as status;
SELECT 'Test by buying something now!' as next_step;
