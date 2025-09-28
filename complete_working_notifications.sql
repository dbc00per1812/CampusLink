-- COMPLETE WORKING NOTIFICATIONS - Database + Push Queue

CREATE OR REPLACE FUNCTION complete_order_notification()
RETURNS TRIGGER AS $$
DECLARE
  listing_owner_id UUID;
BEGIN
  -- Get who owns the listing
  SELECT user_id INTO listing_owner_id
  FROM listings
  WHERE id = NEW.listing_id;
  
  -- Only notify if we found the owner and it's not self-purchase
  IF listing_owner_id IS NOT NULL AND listing_owner_id != NEW.buyer_id THEN
    -- 1. Create database notification
    INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
    VALUES (
      listing_owner_id,
      'order_placed',
      'New Order!',
      'Someone bought your item for $' || (NEW.price_cents::float / 100.0)::text,
      jsonb_build_object('order_id', NEW.id::text),
      NEW.id,
      NEW.buyer_id
    );
    
    -- 2. Create push notification queue entry (if user has push enabled)
    IF EXISTS (
      SELECT 1 FROM user_notification_preferences 
      WHERE user_id = listing_owner_id 
      AND push_enabled = true 
      AND order_notifications = true
      AND push_token IS NOT NULL
    ) THEN
      INSERT INTO push_notification_queue (user_id, notification_type, title, body, data)
      VALUES (
        listing_owner_id,
        'order_placed',
        'New Order!',
        'Someone bought your item for $' || (NEW.price_cents::float / 100.0)::text,
        jsonb_build_object('order_id', NEW.id::text, 'type', 'order_placed')
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
DROP TRIGGER IF EXISTS working_order_trigger ON orders;
DROP TRIGGER IF EXISTS complete_order_trigger ON orders;

CREATE TRIGGER complete_order_trigger
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION complete_order_notification();

SELECT '✅ Complete order notifications created (database + push queue)' as result;
