-- Create Order Notifications
-- This file sets up automatic notifications for order-related events

-- Function to create notification when order is placed
CREATE OR REPLACE FUNCTION create_order_placed_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger on new orders with 'placed' status
  IF NEW.order_status = 'placed' THEN
    -- Create notification for seller
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      order_id,
      related_user_id,
      is_read,
      is_delivered
    ) VALUES (
      NEW.seller_id,
      'order_placed',
      'New Order Received!',
      'You have a new order to fulfill',
      jsonb_build_object(
        'order_id', NEW.id,
        'buyer_id', NEW.buyer_id,
        'price_cents', NEW.price_cents,
        'payment_method', NEW.payment_method
      ),
      NEW.id,
      NEW.buyer_id,
      false,
      false
    );
    
    -- Check if seller has push notifications enabled and send push
    IF EXISTS (
      SELECT 1 FROM user_notification_preferences 
      WHERE user_id = NEW.seller_id 
      AND push_enabled = true 
      AND order_notifications = true
    ) THEN
      -- Queue push notification for processing
      INSERT INTO push_notification_queue (
        user_id,
        notification_type,
        title,
        body,
        data
      ) VALUES (
        NEW.seller_id,
        'order_placed',
        'New Order Received!',
        'You have a new order to fulfill',
        jsonb_build_object(
          'order_id', NEW.id,
          'type', 'order_placed'
        )
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Function to create notification when seller confirms order
CREATE OR REPLACE FUNCTION create_order_confirmed_notification()
RETURNS TRIGGER AS $$
BEGIN
  -- Only trigger when status changes to 'seller_confirmed'
  IF OLD.order_status != 'seller_confirmed' AND NEW.order_status = 'seller_confirmed' THEN
    -- Create notification for buyer
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      order_id,
      related_user_id,
      is_read,
      is_delivered
    ) VALUES (
      NEW.buyer_id,
      'order_confirmed',
      'Order Confirmed!',
      'Your order has been confirmed by the seller',
      jsonb_build_object(
        'order_id', NEW.id,
        'seller_id', NEW.seller_id,
        'price_cents', NEW.price_cents
      ),
      NEW.id,
      NEW.seller_id,
      false,
      false
    );
    
    -- Check if buyer has push notifications enabled and send push
    IF EXISTS (
      SELECT 1 FROM user_notification_preferences 
      WHERE user_id = NEW.buyer_id 
      AND push_enabled = true 
      AND order_notifications = true
    ) THEN
      -- Queue push notification for processing
      INSERT INTO push_notification_queue (
        user_id,
        notification_type,
        title,
        body,
        data
      ) VALUES (
        NEW.buyer_id,
        'order_confirmed',
        'Order Confirmed!',
        'Your order has been confirmed by the seller',
        jsonb_build_object(
          'order_id', NEW.id,
          'type', 'order_confirmed'
        )
      );
    END IF;
  END IF;
  
  -- Also handle other status changes
  IF OLD.order_status != NEW.order_status THEN
    -- Order delivered notification
    IF NEW.order_status = 'delivered' THEN
      INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        data,
        order_id,
        related_user_id,
        is_read,
        is_delivered
      ) VALUES (
        NEW.buyer_id,
        'order_completed',
        'Order Delivered!',
        'Your order has been marked as delivered',
        jsonb_build_object('order_id', NEW.id),
        NEW.id,
        NEW.seller_id,
        false,
        false
      );
    END IF;
    
    -- Order cancelled notification
    IF NEW.order_status = 'cancelled' THEN
      -- Notify both parties
      INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        data,
        order_id,
        related_user_id,
        is_read,
        is_delivered
      ) VALUES 
      (
        NEW.buyer_id,
        'order_cancelled',
        'Order Cancelled',
        'Your order has been cancelled',
        jsonb_build_object('order_id', NEW.id),
        NEW.id,
        NEW.seller_id,
        false,
        false
      ),
      (
        NEW.seller_id,
        'order_cancelled',
        'Order Cancelled',
        'The order has been cancelled',
        jsonb_build_object('order_id', NEW.id),
        NEW.id,
        NEW.buyer_id,
        false,
        false
      );
    END IF;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create triggers for order notifications
DROP TRIGGER IF EXISTS trigger_order_placed_notification ON orders;
CREATE TRIGGER trigger_order_placed_notification
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION create_order_placed_notification();

DROP TRIGGER IF EXISTS trigger_order_status_notification ON orders;
CREATE TRIGGER trigger_order_status_notification
  AFTER UPDATE ON orders
  FOR EACH ROW
  WHEN (OLD.order_status IS DISTINCT FROM NEW.order_status)
  EXECUTE FUNCTION create_order_confirmed_notification();

-- Create push notification queue table if it doesn't exist
CREATE TABLE IF NOT EXISTS push_notification_queue (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  notification_type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}',
  processed boolean DEFAULT false,
  processed_at timestamp with time zone,
  error text,
  created_at timestamp with time zone DEFAULT now()
);

-- Create index for unprocessed notifications
CREATE INDEX IF NOT EXISTS idx_push_queue_unprocessed 
  ON push_notification_queue(processed, created_at) 
  WHERE processed = false;

-- Function to process push notification queue (to be called by edge function)
CREATE OR REPLACE FUNCTION get_unprocessed_push_notifications(batch_size int DEFAULT 10)
RETURNS TABLE (
  id uuid,
  user_id uuid,
  notification_type text,
  title text,
  body text,
  data jsonb,
  push_token text
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    pq.id,
    pq.user_id,
    pq.notification_type,
    pq.title,
    pq.body,
    pq.data,
    unp.push_token
  FROM push_notification_queue pq
  JOIN user_notification_preferences unp ON unp.user_id = pq.user_id
  WHERE pq.processed = false
    AND unp.push_enabled = true
    AND unp.push_token IS NOT NULL
  ORDER BY pq.created_at
  LIMIT batch_size;
END;
$$ LANGUAGE plpgsql;

-- Function to mark push notifications as processed
CREATE OR REPLACE FUNCTION mark_push_notifications_processed(notification_ids uuid[], error_msg text DEFAULT NULL)
RETURNS void AS $$
BEGIN
  UPDATE push_notification_queue
  SET 
    processed = true,
    processed_at = now(),
    error = error_msg
  WHERE id = ANY(notification_ids);
END;
$$ LANGUAGE plpgsql;
