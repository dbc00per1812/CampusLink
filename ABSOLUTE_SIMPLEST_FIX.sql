-- ============================================
-- ABSOLUTE SIMPLEST FIX
-- ============================================
-- Just run this entire script. Don't think about it.
-- It will restore message notifications to working state.
-- ============================================

-- Clean slate
DROP TRIGGER IF EXISTS message_notification_trigger ON messages CASCADE;
DROP TRIGGER IF EXISTS new_message_notification_trigger ON messages CASCADE;
DROP FUNCTION IF EXISTS notify_new_message() CASCADE;

-- Create the function
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_message_preview TEXT;
BEGIN
    -- Get sender's name
    SELECT name INTO v_sender_name
    FROM users
    WHERE id = NEW.sender_id;
    
    -- Get recipient
    SELECT 
        CASE 
            WHEN c.buyer_id = NEW.sender_id THEN c.seller_id
            ELSE c.buyer_id
        END INTO v_recipient_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id;
    
    -- Create preview
    v_message_preview := SUBSTRING(NEW.content, 1, 50);
    IF LENGTH(NEW.content) > 50 THEN
        v_message_preview := v_message_preview || '...';
    END IF;
    
    -- Insert notification
    INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        data,
        message_id,
        related_user_id,
        created_at
    ) VALUES (
        v_recipient_id,
        'new_message',
        'New Message',
        COALESCE(v_sender_name, 'Someone') || ': ' || v_message_preview,
        jsonb_build_object('message_id', NEW.id::text, 'conversation_id', NEW.conversation_id::text),
        NEW.id,
        NEW.sender_id,
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER message_notification_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

-- Grant permissions
GRANT EXECUTE ON FUNCTION notify_new_message() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_message() TO anon;
GRANT EXECUTE ON FUNCTION notify_new_message() TO service_role;

-- Verify
SELECT 'SUCCESS: Trigger installed' as status;

SELECT 
    trigger_name,
    event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'message_notification_trigger';

-- Now test by sending a message in your app



