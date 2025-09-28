-- SIMPLE ORDER NOTIFICATIONS - No bullshit, just works

CREATE OR REPLACE FUNCTION simple_order_notification()
RETURNS TRIGGER AS $$
DECLARE
  listing_owner_id text;
BEGIN
  -- Get who owns the listing
  SELECT user_id INTO listing_owner_id
  FROM listings
  WHERE id = NEW.listing_id;
  
  -- Notify listing owner when order is placed
  IF listing_owner_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
    VALUES (
      listing_owner_id,
      'order_placed',
      'New Order!',
      'Someone bought your item',
      jsonb_build_object('order_id', NEW.id),
      NEW.id,
      NEW.buyer_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger for new orders only
CREATE TRIGGER simple_order_trigger
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION simple_order_notification();

SELECT 'Order notifications fixed. Test by buying something.' as result;
