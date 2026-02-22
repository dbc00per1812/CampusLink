-- ============================================================================
-- FIX MESSAGE NOTIFICATION TRIGGER
-- ============================================================================
-- This script fixes and improves the message notification trigger to ensure
-- message notifications are sent correctly.
-- ============================================================================

-- First, check if the trigger exists and is enabled
SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    CASE WHEN tgenabled = 'O' THEN '✅ ENABLED' ELSE '❌ DISABLED' END AS status
FROM pg_trigger 
WHERE tgname = 'on_new_message';

-- ============================================================================
-- IMPROVED MESSAGE NOTIFICATION TRIGGER
-- ============================================================================
-- This version includes better error handling and logging

CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
    sender_name TEXT;
    recipient_id UUID;
    conversation_exists BOOLEAN;
BEGIN
    -- Check if conversation exists
    SELECT EXISTS(SELECT 1 FROM conversations WHERE id = NEW.conversation_id) 
    INTO conversation_exists;
    
    IF NOT conversation_exists THEN
        RAISE WARNING 'Conversation % does not exist for message %', NEW.conversation_id, NEW.id;
        RETURN NEW;
    END IF;
    
    -- Get sender name (using 'name' column from users table)
    SELECT COALESCE(name, 'Someone') INTO sender_name
    FROM users WHERE id = NEW.sender_id;
    
    -- Get recipient (the other participant in the conversation)
    -- conversations table uses buyer_id and seller_id
    SELECT 
        CASE 
            WHEN c.buyer_id = NEW.sender_id THEN c.seller_id 
            ELSE c.buyer_id 
        END INTO recipient_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id;
    
    -- Don't notify if recipient is the sender or if recipient_id is NULL
    IF recipient_id IS NULL THEN
        RAISE WARNING 'Could not determine recipient for message % in conversation %', NEW.id, NEW.conversation_id;
        RETURN NEW;
    END IF;
    
    IF recipient_id = NEW.sender_id THEN
        -- Don't notify if sender is sending to themselves (shouldn't happen, but safety check)
        RETURN NEW;
    END IF;
    
    -- Send notification
    BEGIN
        PERFORM send_onesignal_notification(
            recipient_id,
            sender_name,
            LEFT(NEW.content, 100),
            jsonb_build_object(
                'type', 'new_message',
                'conversation_id', NEW.conversation_id,
                'message_id', NEW.id,
                'screen', 'Chat'
            )
        );
    EXCEPTION WHEN OTHERS THEN
        -- Log error but don't fail the insert
        RAISE WARNING 'Failed to send notification for message %: %', NEW.id, SQLERRM;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Recreate the trigger
DROP TRIGGER IF EXISTS on_new_message ON messages;
CREATE TRIGGER on_new_message
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

-- ============================================================================
-- VERIFICATION: Test the trigger setup
-- ============================================================================

SELECT 
    tgname AS trigger_name,
    tgrelid::regclass AS table_name,
    CASE WHEN tgenabled = 'O' THEN '✅ ENABLED' ELSE '❌ DISABLED' END AS status
FROM pg_trigger 
WHERE tgname = 'on_new_message';

-- ============================================================================
-- DIAGNOSTIC QUERY: Check recent messages and their notifications
-- ============================================================================
-- Run this to see if notifications are being created for messages

SELECT 
    m.id AS message_id,
    m.conversation_id,
    m.sender_id,
    m.content,
    m.created_at AS message_created_at,
    c.buyer_id,
    c.seller_id,
    CASE 
        WHEN c.buyer_id = m.sender_id THEN c.seller_id 
        ELSE c.buyer_id 
    END AS expected_recipient_id,
    n.id AS notification_id,
    n.user_id AS notification_user_id,
    n.type AS notification_type,
    n.created_at AS notification_created_at
FROM messages m
LEFT JOIN conversations c ON c.id = m.conversation_id
LEFT JOIN notifications n ON n.message_id = m.id AND n.type = 'new_message'
ORDER BY m.created_at DESC
LIMIT 20;
