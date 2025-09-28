-- COMPREHENSIVE NOTIFICATION SETUP
-- This adds notification triggers for ALL major actions

-- 1. ORDER NOTIFICATIONS
CREATE OR REPLACE FUNCTION notify_order_changes()
RETURNS TRIGGER AS $$
BEGIN
  -- New order placed
  IF TG_OP = 'INSERT' THEN
    INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
    VALUES (
      NEW.seller_id,
      'order_placed',
      'New Order!',
      'You have a new order to fulfill',
      jsonb_build_object('order_id', NEW.id, 'price_cents', NEW.price_cents),
      NEW.id,
      NEW.buyer_id
    );
  END IF;
  
  -- Order status changes
  IF TG_OP = 'UPDATE' AND OLD.order_status != NEW.order_status THEN
    -- Seller confirms order
    IF NEW.order_status = 'seller_confirmed' THEN
      INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
      VALUES (
        NEW.buyer_id,
        'order_confirmed',
        'Order Confirmed!',
        'Your order has been confirmed',
        jsonb_build_object('order_id', NEW.id),
        NEW.id,
        NEW.seller_id
      );
    END IF;
    
    -- Order delivered
    IF NEW.order_status = 'delivered' THEN
      INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
      VALUES (
        NEW.buyer_id,
        'order_completed',
        'Order Delivered!',
        'Your order has been delivered',
        jsonb_build_object('order_id', NEW.id),
        NEW.id,
        NEW.seller_id
      );
    END IF;
    
    -- Order completed
    IF NEW.order_status = 'completed' THEN
      -- Notify seller
      INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
      VALUES (
        NEW.seller_id,
        'order_completed',
        'Order Complete!',
        'Order has been completed successfully',
        jsonb_build_object('order_id', NEW.id),
        NEW.id,
        NEW.buyer_id
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. OFFER NOTIFICATIONS  
CREATE OR REPLACE FUNCTION notify_offer_changes()
RETURNS TRIGGER AS $$
DECLARE
  seek_title text;
BEGIN
  -- New offer
  IF TG_OP = 'INSERT' THEN
    SELECT title INTO seek_title FROM listings WHERE id = NEW.seek_listing_id;
    
    INSERT INTO notifications (user_id, type, title, body, data, listing_id, related_user_id)
    VALUES (
      NEW.seeker_id,
      'listing_interest',
      'New Offer!',
      'Someone made an offer on: ' || COALESCE(seek_title, 'your post'),
      jsonb_build_object('offer_id', NEW.id, 'price_cents', NEW.price_cents),
      NEW.seek_listing_id,
      NEW.seller_id
    );
  END IF;
  
  -- Offer status changes
  IF TG_OP = 'UPDATE' AND OLD.status != NEW.status THEN
    IF NEW.status IN ('accepted', 'declined') THEN
      INSERT INTO notifications (user_id, type, title, body, data, listing_id, related_user_id)
      VALUES (
        NEW.seller_id,
        'marketplace_activity',
        'Offer ' || INITCAP(NEW.status),
        'Your offer has been ' || NEW.status,
        jsonb_build_object('offer_id', NEW.id, 'status', NEW.status),
        NEW.seek_listing_id,
        NEW.seeker_id
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. PAYMENT NOTIFICATIONS
CREATE OR REPLACE FUNCTION notify_payment_changes()
RETURNS TRIGGER AS $$
BEGIN
  IF NEW.status = 'succeeded' AND (TG_OP = 'INSERT' OR OLD.status != NEW.status) THEN
    INSERT INTO notifications (user_id, type, title, body, data, related_user_id)
    VALUES (
      NEW.buyer_id,
      'payment_succeeded',
      'Payment Successful!',
      'Your payment of $' || (NEW.amount_cents / 100.0)::numeric(10,2) || ' was processed',
      jsonb_build_object('payment_id', NEW.id, 'amount_cents', NEW.amount_cents),
      NEW.seller_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. RATING NOTIFICATIONS
CREATE OR REPLACE FUNCTION notify_new_rating()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, body, data, related_user_id)
  VALUES (
    NEW.rated_user_id,
    'rating_received',
    'New Rating!',
    'You received a ' || NEW.rating || ' star rating',
    jsonb_build_object('rating_id', NEW.id, 'rating', NEW.rating),
    NEW.rater_user_id
  );
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 5. LISTING NOTIFICATIONS (when someone messages about a listing)
CREATE OR REPLACE FUNCTION notify_listing_interest()
RETURNS TRIGGER AS $$
DECLARE
  listing_owner_id text;
  listing_title text;
BEGIN
  -- Get listing owner if conversation is about a listing
  IF NEW.listing_id IS NOT NULL THEN
    SELECT user_id, title INTO listing_owner_id, listing_title 
    FROM listings 
    WHERE id = NEW.listing_id;
    
    -- If first message in conversation, notify listing owner
    IF NOT EXISTS (SELECT 1 FROM conversations WHERE id = NEW.id AND id != NEW.id) THEN
      INSERT INTO notifications (user_id, type, title, body, data, listing_id, related_user_id)
      VALUES (
        listing_owner_id,
        'listing_interest',
        'Interest in Your Listing!',
        'Someone is interested in: ' || COALESCE(listing_title, 'your item'),
        jsonb_build_object('conversation_id', NEW.id),
        NEW.listing_id,
        CASE WHEN NEW.buyer_id = listing_owner_id THEN NEW.seller_id ELSE NEW.buyer_id END
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- DROP ALL OLD TRIGGERS
DROP TRIGGER IF EXISTS order_notification_trigger ON orders;
DROP TRIGGER IF EXISTS order_notification_trigger_working ON orders;
DROP TRIGGER IF EXISTS trigger_order_placed_notification ON orders;
DROP TRIGGER IF EXISTS trigger_order_status_notification ON orders;
DROP TRIGGER IF EXISTS offer_notification_trigger ON offers;
DROP TRIGGER IF EXISTS payment_notification_trigger ON payments;
DROP TRIGGER IF EXISTS rating_notification_trigger ON ratings;
DROP TRIGGER IF EXISTS conversation_notification_trigger ON conversations;

-- CREATE ALL NEW TRIGGERS
CREATE TRIGGER order_notification_trigger
  AFTER INSERT OR UPDATE ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_order_changes();

CREATE TRIGGER offer_notification_trigger
  AFTER INSERT OR UPDATE ON offers
  FOR EACH ROW
  EXECUTE FUNCTION notify_offer_changes();

CREATE TRIGGER payment_notification_trigger
  AFTER INSERT OR UPDATE ON payments
  FOR EACH ROW
  EXECUTE FUNCTION notify_payment_changes();

CREATE TRIGGER rating_notification_trigger
  AFTER INSERT ON ratings
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_rating();

CREATE TRIGGER conversation_notification_trigger
  AFTER INSERT ON conversations
  FOR EACH ROW
  EXECUTE FUNCTION notify_listing_interest();

-- SUMMARY
SELECT 'All notification triggers created!' as status;
SELECT 'Notifications will now be sent for:' as info;
SELECT '- New orders (seller notified)' as feature_1;
SELECT '- Order confirmations (buyer notified)' as feature_2;
SELECT '- Order delivery/completion (both parties)' as feature_3;
SELECT '- New offers on seeks (seeker notified)' as feature_4;
SELECT '- Offer accepted/declined (offer maker notified)' as feature_5;
SELECT '- Successful payments (buyer notified)' as feature_6;
SELECT '- New ratings (rated user notified)' as feature_7;
SELECT '- Listing interest (owner notified)' as feature_8;
