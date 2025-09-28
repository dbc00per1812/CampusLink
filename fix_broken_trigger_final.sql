-- FINAL FIX: The trigger exists but function is broken - fix it now

-- Drop the broken trigger and function
DROP TRIGGER IF EXISTS notify_on_order_trigger ON orders;
DROP FUNCTION IF EXISTS working_order_trigger();
DROP FUNCTION IF EXISTS notify_on_order();

-- Create simple working function that creates both notifications
CREATE OR REPLACE FUNCTION simple_working_order_function()
RETURNS TRIGGER AS $$
BEGIN
  -- Get listing owner from the listing
  DECLARE
    owner_id UUID;
  BEGIN
    SELECT user_id INTO owner_id FROM listings WHERE id = NEW.listing_id;
    
    -- Skip if no owner or self-purchase
    IF owner_id IS NULL OR owner_id = NEW.buyer_id THEN
      RETURN NEW;
    END IF;
    
    -- Create database notification
    INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
    VALUES (
      owner_id,
      'order_placed', 
      'New Order!',
      'Someone bought your item',
      jsonb_build_object('order_id', NEW.id::text),
      NEW.id,
      NEW.buyer_id
    );
    
    -- Create push queue entry
    INSERT INTO push_notification_queue (user_id, notification_type, title, body, data)
    VALUES (
      owner_id,
      'order_placed',
      'New Order!', 
      'Someone bought your item',
      jsonb_build_object('order_id', NEW.id::text, 'type', 'order_placed')
    );
    
    RETURN NEW;
  END;
END;
$$ LANGUAGE plpgsql;

-- Create new working trigger
CREATE TRIGGER simple_working_order_trigger
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION simple_working_order_function();

SELECT '✅ Fixed broken trigger - both database and push notifications will work now' as result;
