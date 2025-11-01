-- Fix Message Notification Sender Display Issue
-- Problem: Notifications show recipient's name instead of sender's name
-- Solution: Update the trigger to correctly get sender info and send to recipient

-- ============================================
-- DROP EXISTING TRIGGER AND FUNCTION
-- ============================================
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;
DROP TRIGGER IF EXISTS new_message_notification_trigger ON messages;
DROP FUNCTION IF EXISTS notify_new_message() CASCADE;

-- ============================================
-- CREATE CORRECT NOTIFICATION FUNCTION
-- ============================================
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_message_preview TEXT;
BEGIN
    -- Get sender's name from users table
    SELECT name INTO v_sender_name
    FROM users
    WHERE id = NEW.sender_id;
    
    -- Determine recipient: the conversation participant who is NOT the sender
    SELECT 
        CASE 
            WHEN c.buyer_id = NEW.sender_id THEN c.seller_id
            ELSE c.buyer_id
        END INTO v_recipient_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id;
    
    -- Create preview (first 50 chars of message)
    v_message_preview := SUBSTRING(NEW.content, 1, 50);
    IF LENGTH(NEW.content) > 50 THEN
        v_message_preview := v_message_preview || '...';
    END IF;
    
    -- Create notification for the RECIPIENT (not the sender!)
    -- The notification should show the SENDER's name
    INSERT INTO notifications (
        user_id,           -- Who receives the notification (recipient)
        type,
        title,
        body,              -- Should show sender's name
        data,
        message_id,
        related_user_id,   -- The sender
        created_at
    ) VALUES (
        v_recipient_id,                                    -- Send to recipient
        'new_message',
        'New Message',
        COALESCE(v_sender_name, 'Someone') || ': ' || v_message_preview,  -- Show sender's name
        jsonb_build_object('message_id', NEW.id::text, 'conversation_id', NEW.conversation_id::text),
        NEW.id,
        NEW.sender_id,                                     -- Related user is the sender
        NOW()
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- ============================================
-- CREATE TRIGGER
-- ============================================
CREATE TRIGGER message_notification_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

-- ============================================
-- VERIFY THE FIX
-- ============================================
-- Run this query to check recent message notifications:
-- SELECT 
--     n.id,
--     n.user_id as recipient_id,
--     n.related_user_id as sender_id,
--     n.title,
--     n.body,
--     n.created_at,
--     recipient.name as recipient_name,
--     sender.name as sender_name
-- FROM notifications n
-- LEFT JOIN users recipient ON n.user_id::uuid = recipient.id
-- LEFT JOIN users sender ON n.related_user_id::uuid = sender.id
-- WHERE n.type = 'new_message'
-- ORDER BY n.created_at DESC
-- LIMIT 10;

