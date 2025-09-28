-- Simple Notification Setup - Run this ONCE
-- Creates tables, triggers, and functions for notifications

-- 1. Create notifications table
CREATE TABLE IF NOT EXISTS notifications (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE,
  type text NOT NULL,
  title text NOT NULL,
  body text NOT NULL,
  data jsonb DEFAULT '{}',
  is_read boolean DEFAULT false,
  is_delivered boolean DEFAULT false,
  created_at timestamp with time zone DEFAULT now(),
  order_id uuid REFERENCES orders(id) ON DELETE CASCADE,
  listing_id uuid REFERENCES listings(id) ON DELETE CASCADE,
  related_user_id uuid REFERENCES auth.users(id) ON DELETE SET NULL
);

-- 2. Create user preferences table
CREATE TABLE IF NOT EXISTS user_notification_preferences (
  id uuid DEFAULT gen_random_uuid() PRIMARY KEY,
  user_id uuid NOT NULL REFERENCES auth.users(id) ON DELETE CASCADE UNIQUE,
  push_enabled boolean DEFAULT true,
  push_token text,
  order_notifications boolean DEFAULT true,
  marketplace_notifications boolean DEFAULT true,
  created_at timestamp with time zone DEFAULT now()
);

-- 3. Create function for order notifications
CREATE OR REPLACE FUNCTION notify_on_order_placed()
RETURNS TRIGGER AS $$
BEGIN
  INSERT INTO notifications (user_id, type, title, body, data, order_id, related_user_id)
  VALUES (
    NEW.seller_id,
    'order_placed',
    'New Order Received!',
    'You have a new order to fulfill',
    jsonb_build_object('order_id', NEW.id, 'price_cents', NEW.price_cents),
    NEW.id,
    NEW.buyer_id
  );
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 4. Create trigger for new orders
DROP TRIGGER IF EXISTS order_notification_trigger ON orders;
CREATE TRIGGER order_notification_trigger
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_order_placed();

-- 5. Create preferences for existing users
INSERT INTO user_notification_preferences (user_id)
SELECT id FROM auth.users
WHERE id NOT IN (SELECT user_id FROM user_notification_preferences)
ON CONFLICT (user_id) DO NOTHING;

-- 6. Test query
SELECT 'Notification system setup complete!' as result;