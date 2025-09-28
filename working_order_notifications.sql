-- WORKING ORDER NOTIFICATIONS - Fixed UUID types

CREATE OR REPLACE FUNCTION working_order_notification()
RETURNS TRIGGER AS $$
DECLARE
  listing_owner_id UUID;  -- ✅ FIXED: UUID type, not text
BEGIN
  -- Get who owns the listing
  SELECT user_id INTO listing_owner_id
  FROM listings
  WHERE id = NEW.listing_id;
  
  -- Only notify if we found the owner and it's not the buyer buying their own stuff
  IF listing_owner_id IS NOT NULL AND listing_owner_id != NEW.buyer_id THEN
    INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
    VALUES (
      listing_owner_id,  -- ✅ Now UUID type
      'order_placed',
      'New Order!',
      'Someone bought your item for $' || (NEW.price_cents::float / 100.0)::text,
      jsonb_build_object('order_id', NEW.id::text),
      NEW.id,
      NEW.buyer_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER working_order_trigger
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION working_order_notification();

SELECT '✅ Order notifications fixed with proper UUID handling' as result;
