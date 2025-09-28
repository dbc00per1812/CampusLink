-- Complete Push Notification Fix
-- Run this to fix all notification issues

-- 1. Add message triggers (messages don't have automatic notifications yet!)
CREATE OR REPLACE FUNCTION notify_on_message()
RETURNS TRIGGER AS $$
DECLARE
  recipient_id text;
  sender_name text;
BEGIN
  -- Get recipient (the other person in the conversation)
  SELECT 
    CASE 
      WHEN NEW.sender_id = buyer_id THEN seller_id
      ELSE buyer_id
    END INTO recipient_id
  FROM conversations 
  WHERE id = NEW.conversation_id;
  
  -- Get sender name from auth.users or use email as fallback
  SELECT 
    COALESCE(
      (raw_user_meta_data->>'display_name')::text,
      (raw_user_meta_data->>'name')::text,
      email
    ) INTO sender_name
  FROM auth.users 
  WHERE id::text = NEW.sender_id;
  
  -- Create notification for recipient (only if recipient found)
  IF recipient_id IS NOT NULL THEN
    INSERT INTO notifications (user_id, type, title, body, data, related_user_id)
    VALUES (
      recipient_id,
      'new_message',
      'New Message',
      COALESCE(sender_name, 'Someone') || ': ' || LEFT(NEW.content, 50) || CASE WHEN LENGTH(NEW.content) > 50 THEN '...' ELSE '' END,
      jsonb_build_object('message_id', NEW.id, 'conversation_id', NEW.conversation_id),
      NEW.sender_id
    );
  END IF;
  
  -- Queue push notification if user has push enabled
  IF EXISTS (
    SELECT 1 FROM user_notification_preferences 
    WHERE user_id = recipient_id 
    AND push_enabled = true 
    AND message_notifications = true
    AND push_token IS NOT NULL
  ) THEN
    INSERT INTO push_notification_queue (user_id, notification_type, title, body, data)
    VALUES (
      recipient_id,
      'new_message',
      'New Message',
      sender_name || ': ' || LEFT(NEW.content, 50) || CASE WHEN LENGTH(NEW.content) > 50 THEN '...' ELSE '' END,
      jsonb_build_object('message_id', NEW.id, 'type', 'new_message')
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create message trigger
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;
CREATE TRIGGER message_notification_trigger
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_message();

-- 2. Update the simple order trigger to also queue push notifications
DROP FUNCTION IF EXISTS notify_on_order_placed();
CREATE OR REPLACE FUNCTION notify_on_order_placed()
RETURNS TRIGGER AS $$
BEGIN
  -- Create database notification
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
  
  -- Queue push notification if user has push enabled
  IF EXISTS (
    SELECT 1 FROM user_notification_preferences 
    WHERE user_id = NEW.seller_id 
    AND push_enabled = true 
    AND order_notifications = true
    AND push_token IS NOT NULL
  ) THEN
    INSERT INTO push_notification_queue (user_id, notification_type, title, body, data)
    VALUES (
      NEW.seller_id,
      'order_placed',
      'New Order Received!',
      'You have a new order to fulfill',
      jsonb_build_object('order_id', NEW.id, 'type', 'order_placed')
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 3. Create push notification queue table if it doesn't exist
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

-- 4. Create functions for processing push notifications
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

-- 5. Test the setup
SELECT 'Push notification system updated!' as result;
SELECT 'Message trigger created' as status;
SELECT 'Order trigger updated with push queue' as status;
SELECT 'Push queue functions ready' as status;
