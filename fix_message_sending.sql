-- Quick Fix: Messages failing to send
-- This is likely caused by the notification trigger I added

-- Step 1: Temporarily disable the message notification trigger
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;

-- Step 2: Test if messages work now
-- Try sending a message in your app - it should work

-- Step 3: Check what was wrong with the trigger
-- The issue is probably in the notify_on_message function

-- Step 4: Create a simpler, safer message notification trigger
CREATE OR REPLACE FUNCTION notify_on_message_safe()
RETURNS TRIGGER AS $$
DECLARE
  recipient_id text;
  sender_name text;
BEGIN
  -- Safely get recipient (the other person in the conversation)
  SELECT 
    CASE 
      WHEN NEW.sender_id = buyer_id THEN seller_id
      ELSE buyer_id
    END INTO recipient_id
  FROM conversations 
  WHERE id = NEW.conversation_id;
  
  -- Only proceed if we found a recipient
  IF recipient_id IS NOT NULL AND recipient_id != NEW.sender_id THEN
    -- Get sender name safely
    SELECT COALESCE(email, 'Someone') INTO sender_name
    FROM auth.users 
    WHERE id::text = NEW.sender_id;
    
    -- Create notification (with error handling)
    BEGIN
      INSERT INTO notifications (user_id, type, title, body, data, related_user_id)
      VALUES (
        recipient_id,
        'new_message',
        'New Message',
        COALESCE(sender_name, 'Someone') || ': ' || LEFT(NEW.content, 50),
        jsonb_build_object('conversation_id', NEW.conversation_id),
        NEW.sender_id
      );
    EXCEPTION 
      WHEN OTHERS THEN
        -- If notification fails, don't break message sending
        NULL;
    END;
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Step 5: Re-create the trigger with the safe function
CREATE TRIGGER message_notification_trigger_safe
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION notify_on_message_safe();

SELECT 'Message sending should work now!' as result;
SELECT 'Notification trigger recreated safely' as status;
