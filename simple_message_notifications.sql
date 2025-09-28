-- SIMPLE MESSAGE NOTIFICATIONS - No bullshit, just works

CREATE OR REPLACE FUNCTION simple_message_notification()
RETURNS TRIGGER AS $$
DECLARE
  recipient_id text;
BEGIN
  -- Get the other person in the conversation
  SELECT 
    CASE 
      WHEN NEW.sender_id = buyer_id THEN seller_id
      ELSE buyer_id
    END INTO recipient_id
  FROM conversations 
  WHERE id = NEW.conversation_id;
  
  -- Create notification (simple, no complex logic)
  IF recipient_id IS NOT NULL AND recipient_id != NEW.sender_id THEN
    INSERT INTO notifications (user_id, type, title, body, data, related_user_id)
    VALUES (
      recipient_id,
      'new_message',
      'New Message',
      LEFT(NEW.content, 50),
      jsonb_build_object('conversation_id', NEW.conversation_id),
      NEW.sender_id
    );
  END IF;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER simple_message_trigger
  AFTER INSERT ON messages
  FOR EACH ROW
  EXECUTE FUNCTION simple_message_notification();

SELECT 'Message notifications fixed. Send a message to test.' as result;
