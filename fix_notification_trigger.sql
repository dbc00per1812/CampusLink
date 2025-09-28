-- Fix the broken notification trigger that's causing the JSON error
-- The issue is manual JSON string concatenation: '{"order_id": "' || NEW.id || '"}'::jsonb
-- This creates malformed JSON. We need to use jsonb_build_object() instead.

DROP FUNCTION IF EXISTS notify_order_status_change() CASCADE;

CREATE OR REPLACE FUNCTION notify_order_status_change()
RETURNS TRIGGER AS $$
DECLARE
  buyer_prefs record;
  seller_prefs record;
  listing_info record;
BEGIN
  -- Get listing info for context
  SELECT title INTO listing_info FROM public.listings WHERE id = NEW.listing_id;
  
  -- Notify buyer
  IF NEW.order_status = 'seller_confirmed' THEN
    PERFORM create_notification(
      NEW.buyer_id,
      'order_confirmed',
      'Order Confirmed!',
      'Your order for "' || COALESCE(listing_info.title, 'Unknown Item') || '" has been confirmed by the seller.',
      jsonb_build_object('order_id', NEW.id::text),  -- FIXED: Use jsonb_build_object
      NEW.id
    );
  ELSIF NEW.order_status = 'in_progress' THEN
    PERFORM create_notification(
      NEW.buyer_id,
      'order_in_progress',
      'Order In Progress',
      'Your order for "' || COALESCE(listing_info.title, 'Unknown Item') || '" is now being prepared.',
      jsonb_build_object('order_id', NEW.id::text),  -- FIXED: Use jsonb_build_object
      NEW.id
    );
  ELSIF NEW.order_status = 'completed' THEN
    PERFORM create_notification(
      NEW.buyer_id,
      'order_completed',
      'Order Completed!',
      'Your order for "' || COALESCE(listing_info.title, 'Unknown Item') || '" has been completed. Rate your experience!',
      jsonb_build_object('order_id', NEW.id::text),  -- FIXED: Use jsonb_build_object
      NEW.id
    );
  ELSIF NEW.order_status = 'cancelled' THEN
    PERFORM create_notification(
      NEW.buyer_id,
      'order_cancelled',
      'Order Cancelled',
      'Your order for "' || COALESCE(listing_info.title, 'Unknown Item') || '" has been cancelled.',
      jsonb_build_object('order_id', NEW.id::text),  -- FIXED: Use jsonb_build_object
      NEW.id
    );
  END IF;
  
  -- Notify seller (THIS IS THE LINE 51 THAT WAS FAILING)
  IF NEW.order_status = 'placed' THEN
    PERFORM create_notification(
      NEW.seller_id,
      'order_placed',
      'New Order!',
      'You have a new order for "' || COALESCE(listing_info.title, 'Unknown Item') || '"',
      jsonb_build_object('order_id', NEW.id::text),  -- FIXED: Use jsonb_build_object instead of manual JSON
      NEW.id,
      NULL,
      NEW.listing_id,
      NEW.buyer_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Recreate the trigger
DROP TRIGGER IF EXISTS order_notification_trigger ON public.orders;
CREATE TRIGGER order_notification_trigger
    AFTER INSERT OR UPDATE ON public.orders
    FOR EACH ROW
    EXECUTE FUNCTION notify_order_status_change();
