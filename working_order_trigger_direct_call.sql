-- WORKING ORDER TRIGGER - Copy exact message pattern with direct edge function call

-- Remove broken triggers
DROP TRIGGER IF EXISTS order_notification_trigger ON orders;
DROP FUNCTION IF EXISTS order_notification_trigger();

-- Create exact same pattern as working message notifications
CREATE OR REPLACE FUNCTION notify_new_order()
RETURNS TRIGGER AS $$
DECLARE
  listing_owner_id UUID;
  owner_name text;
BEGIN
  -- Get listing owner
  SELECT l.user_id, u.name 
  INTO listing_owner_id, owner_name
  FROM listings l
  LEFT JOIN users u ON u.id = l.user_id
  WHERE l.id = NEW.listing_id;
  
  -- Only send notification if owner exists and not self-purchase
  IF listing_owner_id IS NOT NULL AND listing_owner_id != NEW.buyer_id THEN
    
    -- Create database notification (same as before)
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
    
    -- DIRECT EDGE FUNCTION CALL - Same as working message notifications
    PERFORM net.http_post(
      url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-direct',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'user_id', listing_owner_id::text,
        'title', 'New Order!',
        'body', 'Someone bought your item for $' || (NEW.price_cents::float / 100.0)::text,
        'type', 'order_placed',
        'data', jsonb_build_object(
          'order_id', NEW.id::text,
          'buyer_id', NEW.buyer_id::text,
          'price_cents', NEW.price_cents
        )
      )
    );
    
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger - exact same pattern as message trigger
CREATE TRIGGER notify_new_order_trigger
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_order();

SELECT '✅ Order notifications now use EXACT same pattern as working message notifications' as result;
