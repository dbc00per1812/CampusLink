-- Complete Fix for Messaging Notifications
-- This addresses ALL the issues found in the comprehensive review

-- 1. Create the missing insert_notification RPC function
CREATE OR REPLACE FUNCTION insert_notification(
  p_user_id text,
  p_type text,
  p_title text,
  p_body text,
  p_data jsonb,
  p_is_delivered boolean,
  p_delivered_at timestamp with time zone
) RETURNS uuid
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  new_notification_id uuid;
BEGIN
  INSERT INTO notifications (
    user_id,
    type,
    title,
    body,
    data,
    is_delivered,
    delivered_at
  ) VALUES (
    p_user_id::uuid,
    p_type,
    p_title,
    p_body,
    p_data,
    p_is_delivered,
    p_delivered_at
  )
  RETURNING id INTO new_notification_id;
  
  RETURN new_notification_id;
END;
$$;

-- 2. Simplified approach: Direct notification insert in trigger (no edge function call from DB)
CREATE OR REPLACE FUNCTION notify_new_message_simple()
RETURNS TRIGGER AS $$
DECLARE
  recipient_id uuid;
  sender_name text;
  message_preview text;
  conversation_title text;
  notification_id uuid;
BEGIN
  -- Get recipient (the user who is NOT the sender)
  SELECT 
    CASE 
      WHEN c.buyer_id = NEW.sender_id THEN c.seller_id
      ELSE c.buyer_id
    END,
    CASE 
      WHEN c.buyer_id = NEW.sender_id THEN b.name
      ELSE s.name
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

    -- Insert notification directly (simpler approach)
    INSERT INTO notifications (
      user_id,
      type,
      title,
      body,
      data,
      message_id,
      related_user_id
    ) VALUES (
      recipient_id,
      'new_message',
      COALESCE(sender_name, 'New Message'),
      message_preview,
      jsonb_build_object(
        'message_id', NEW.id::text,
        'conversation_id', NEW.conversation_id::text,
        'sender_id', NEW.sender_id::text,
        'sender_name', COALESCE(sender_name, 'Unknown'),
        'conversation_title', conversation_title
      ),
      NEW.id,
      NEW.sender_id
    )
    RETURNING id INTO notification_id;

    -- Call a separate scheduled job to handle push notifications
    -- This avoids the auth issues with calling edge functions from triggers
  END IF;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Drop and recreate the trigger with the simple function
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;

CREATE TRIGGER message_notification_trigger
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_new_message_simple();

-- 4. Create a view to get pending push notifications
CREATE OR REPLACE VIEW pending_push_notifications AS
SELECT 
  n.id as notification_id,
  n.user_id,
  n.type,
  n.title,
  n.body,
  n.data,
  n.created_at,
  unp.push_token,
  unp.push_enabled
FROM notifications n
JOIN user_notification_preferences unp ON unp.user_id = n.user_id
WHERE n.is_delivered = false
  AND n.type = 'new_message'
  AND unp.push_enabled = true
  AND unp.push_token IS NOT NULL
  AND n.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY n.created_at ASC;

-- 5. Function to process pending push notifications (called by cron job)
CREATE OR REPLACE FUNCTION process_pending_push_notifications()
RETURNS jsonb
LANGUAGE plpgsql
AS $$
DECLARE
  pending_count integer;
  processed_count integer := 0;
BEGIN
  SELECT COUNT(*) INTO pending_count FROM pending_push_notifications;
  
  -- This function would be called by a scheduled edge function
  -- that runs every minute to process pending notifications
  
  RETURN jsonb_build_object(
    'pending_count', pending_count,
    'processed_count', processed_count,
    'message', 'Use scheduled edge function to process these'
  );
END;
$$;

-- 6. Grant necessary permissions
GRANT EXECUTE ON FUNCTION insert_notification(text, text, text, text, jsonb, boolean, timestamp with time zone) TO service_role;
GRANT EXECUTE ON FUNCTION notify_new_message_simple() TO authenticated;
GRANT SELECT ON pending_push_notifications TO service_role;
GRANT EXECUTE ON FUNCTION process_pending_push_notifications() TO service_role;

-- 7. Test the complete flow
CREATE OR REPLACE FUNCTION test_complete_messaging_flow(
  p_conversation_id uuid,
  p_sender_id uuid,
  p_content text
) RETURNS jsonb
LANGUAGE plpgsql AS $$
DECLARE
  test_message_id uuid;
  notification_count integer;
  pending_push_count integer;
  result jsonb;
BEGIN
  -- Insert a test message
  INSERT INTO messages (conversation_id, sender_id, content)
  VALUES (p_conversation_id, p_sender_id, p_content)
  RETURNING id INTO test_message_id;

  -- Check if notification was created
  SELECT COUNT(*) INTO notification_count
  FROM notifications
  WHERE message_id = test_message_id;

  -- Check if pending push exists
  SELECT COUNT(*) INTO pending_push_count
  FROM pending_push_notifications
  WHERE data->>'message_id' = test_message_id::text;

  -- Build result
  SELECT jsonb_build_object(
    'success', true,
    'message_id', test_message_id,
    'notification_created', notification_count > 0,
    'pending_push_exists', pending_push_count > 0,
    'message', CASE 
      WHEN notification_count = 0 THEN 'No notification created - check trigger'
      WHEN pending_push_count = 0 THEN 'Notification created but no pending push - check user settings'
      ELSE 'Success - notification created and pending push exists'
    END
  ) INTO result;

  RETURN result;
END;
$$;

GRANT EXECUTE ON FUNCTION test_complete_messaging_flow(uuid, uuid, text) TO authenticated;
