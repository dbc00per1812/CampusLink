-- Copy the working message trigger pattern for orders

-- First, let's see what the working message trigger looks like
SELECT 'Current message trigger function:' as info;

-- Now create the EXACT same pattern for orders
CREATE OR REPLACE FUNCTION working_order_trigger()
RETURNS TRIGGER AS $$
DECLARE
  listing_owner_id UUID;
BEGIN
  -- Get the listing owner
  SELECT user_id INTO listing_owner_id
  FROM listings 
  WHERE id = NEW.listing_id;
  
  -- Skip if no owner found or self-purchase
  IF listing_owner_id IS NULL OR listing_owner_id = NEW.buyer_id THEN
    RETURN NEW;
  END IF;
  
  -- Create database notification
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
  
  -- Create push queue entry - EXACT same pattern as message trigger
  INSERT INTO push_notification_queue (user_id, notification_type, title, body, data)
  VALUES (
    listing_owner_id,
    'order_placed',
    'New Order!', 
    'Someone bought your item',
    jsonb_build_object('order_id', NEW.id::text, 'type', 'order_placed')
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Replace the trigger
DROP TRIGGER IF EXISTS notify_on_order_trigger ON orders;
DROP TRIGGER IF EXISTS complete_order_trigger ON orders;

CREATE TRIGGER working_order_trigger_final
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION working_order_trigger();

SELECT '✅ Copied working message trigger pattern to orders' as result;
