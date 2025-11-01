-- ============================================
-- EMERGENCY FIX: RESTORE MESSAGE NOTIFICATIONS
-- ============================================
-- This restores ONLY message notifications to working state
-- Run this immediately to fix the broken message notifications
-- ============================================

-- Drop any broken trigger
DROP TRIGGER IF EXISTS message_notification_trigger ON messages CASCADE;
DROP TRIGGER IF EXISTS new_message_notification_trigger ON messages CASCADE;
DROP FUNCTION IF EXISTS notify_new_message() CASCADE;

-- Recreate the WORKING message notification function
-- This is the exact code that was working before
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

-- Recreate the trigger
CREATE TRIGGER message_notification_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

-- Grant permissions
GRANT EXECUTE ON FUNCTION notify_new_message() TO authenticated;

-- Verify it's working
SELECT 
    trigger_name,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'message_notification_trigger';

-- Should show 1 row: message_notification_trigger | messages | AFTER



