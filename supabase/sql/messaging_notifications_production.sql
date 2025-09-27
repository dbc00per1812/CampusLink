-- Production Messaging Notifications System
-- This creates the missing link between messaging and push notifications

-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_net;

-- Function to send push notification for new messages
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
  recipient_id uuid;
  sender_name text;
  message_preview text;
  conversation_title text;
BEGIN
  -- Get recipient (the user who is NOT the sender)
  SELECT 
    CASE 
      WHEN c.buyer_id = NEW.sender_id THEN c.seller_id
      ELSE c.buyer_id
    END,
    CASE 
      WHEN c.buyer_id = NEW.sender_id THEN s.name
      ELSE b.name
    END,
    COALESCE(l.title, 'CampusLink Message'),
    LEFT(NEW.content, 100) || CASE WHEN LENGTH(NEW.content) > 100 THEN '...' ELSE '' END
  INTO recipient_id, sender_name, conversation_title, message_preview
  FROM conversations c
  LEFT JOIN users s ON s.id = c.seller_id
  LEFT JOIN users b ON b.id = c.buyer_id
  LEFT JOIN listings l ON l.id = c.listing_id
  WHERE c.id = NEW.conversation_id;

  -- Only send notification if recipient exists and is not the sender
  IF recipient_id IS NOT NULL AND recipient_id != NEW.sender_id THEN
    -- Log the trigger execution
    INSERT INTO trigger_debug_log (message_id, message_content, sender_id, conversation_id)
    VALUES (NEW.id, NEW.content, NEW.sender_id, NEW.conversation_id);

    -- Call edge function to send push notification
    PERFORM net.http_post(
      url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-direct',
      headers := jsonb_build_object(
        'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key', true),
        'Content-Type', 'application/json'
      ),
      body := jsonb_build_object(
        'user_id', recipient_id::text,
        'title', CASE 
          WHEN sender_name IS NOT NULL THEN sender_name
          ELSE 'New Message'
        END,
        'body', message_preview,
        'type', 'new_message',
        'data', jsonb_build_object(
          'message_id', NEW.id::text,
          'conversation_id', NEW.conversation_id::text,
          'sender_id', NEW.sender_id::text,
          'sender_name', COALESCE(sender_name, 'Unknown'),
          'conversation_title', conversation_title
        )
      )
    );
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;

-- Create the trigger
CREATE TRIGGER message_notification_trigger
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message();

-- Function to test messaging notifications
CREATE OR REPLACE FUNCTION test_messaging_notification(
  p_conversation_id uuid,
  p_sender_id uuid,
  p_content text
) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  test_message_id uuid;
  result jsonb;
BEGIN
  -- Insert a test message
  INSERT INTO messages (conversation_id, sender_id, content)
  VALUES (p_conversation_id, p_sender_id, p_content)
  RETURNING id INTO test_message_id;

  -- Get the result
  SELECT jsonb_build_object(
    'success', true,
    'message_id', test_message_id,
    'message', 'Test message inserted and trigger fired'
  ) INTO result;

  RETURN result;
END;
$$;

-- Function to get messaging notification status
CREATE OR REPLACE FUNCTION get_messaging_notification_status()
RETURNS TABLE(
  trigger_exists boolean,
  trigger_function_exists boolean,
  recent_messages bigint,
  recent_notifications bigint,
  recent_trigger_logs bigint
) LANGUAGE plpgsql AS $$
BEGIN
  RETURN QUERY
  SELECT 
    EXISTS(
      SELECT 1 FROM pg_trigger 
      WHERE tgname = 'message_notification_trigger' 
      AND tgrelid = 'messages'::regclass
    ) as trigger_exists,
    EXISTS(
      SELECT 1 FROM pg_proc 
      WHERE proname = 'notify_new_message'
    ) as trigger_function_exists,
    (SELECT COUNT(*) FROM messages WHERE created_at > now() - interval '1 hour') as recent_messages,
    (SELECT COUNT(*) FROM notifications WHERE type = 'new_message' AND created_at > now() - interval '1 hour') as recent_notifications,
    (SELECT COUNT(*) FROM trigger_debug_log WHERE created_at > now() - interval '1 hour') as recent_trigger_logs;
END;
$$;

-- Grant permissions
GRANT EXECUTE ON FUNCTION notify_new_message() TO authenticated;
GRANT EXECUTE ON FUNCTION test_messaging_notification(uuid, uuid, text) TO authenticated;
GRANT EXECUTE ON FUNCTION get_messaging_notification_status() TO authenticated;
GRANT SELECT ON trigger_debug_log TO authenticated;

-- Add RLS policies for trigger_debug_log
ALTER TABLE trigger_debug_log ENABLE ROW LEVEL SECURITY;

CREATE POLICY "Users can view their own trigger logs" ON trigger_debug_log
  FOR SELECT USING (
    EXISTS(
      SELECT 1 FROM messages m 
      JOIN conversations c ON c.id = m.conversation_id
      WHERE m.id = trigger_debug_log.message_id 
      AND (c.buyer_id = auth.uid() OR c.seller_id = auth.uid())
    )
  );
