-- ============================================
-- DEBUG: Add extensive logging to trigger
-- ============================================
-- This will show us exactly what happens when trigger fires
-- Check Postgres logs after running this and sending a message
-- ============================================

DROP FUNCTION IF EXISTS notify_new_message() CASCADE;

CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER
SECURITY DEFINER
SET search_path = public
LANGUAGE plpgsql
AS $$
DECLARE
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_message_preview TEXT;
BEGIN
    RAISE NOTICE '🔔 notify_new_message TRIGGERED!';
    RAISE NOTICE '   Message ID: %', NEW.id;
    RAISE NOTICE '   Sender ID: %', NEW.sender_id;
    RAISE NOTICE '   Conversation ID: %', NEW.conversation_id;
    RAISE NOTICE '   Content: %', NEW.content;
    
    BEGIN
        -- Get sender's name
        SELECT name INTO v_sender_name
        FROM users
        WHERE id = NEW.sender_id;
        
        RAISE NOTICE '   Sender name: %', COALESCE(v_sender_name, 'NULL');
        
        -- Get recipient
        SELECT 
            CASE 
                WHEN c.buyer_id = NEW.sender_id THEN c.seller_id
                ELSE c.buyer_id
            END INTO v_recipient_id
        FROM conversations c
        WHERE c.id = NEW.conversation_id;
        
        RAISE NOTICE '   Recipient ID: %', COALESCE(v_recipient_id::text, 'NULL');
        
        IF v_recipient_id IS NULL THEN
            RAISE WARNING '❌ Could not determine recipient!';
            RETURN NEW;
        END IF;
        
        -- Create preview
        v_message_preview := SUBSTRING(NEW.content, 1, 50);
        IF LENGTH(NEW.content) > 50 THEN
            v_message_preview := v_message_preview || '...';
        END IF;
        
        RAISE NOTICE '   Preview: %', v_message_preview;
        RAISE NOTICE '   Attempting to INSERT notification...';
        
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
        
        RAISE NOTICE '✅ Notification inserted successfully!';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ Error in notify_new_message: %', SQLERRM;
        RAISE WARNING '   Error detail: %', SQLSTATE;
        -- Don't re-raise, let message insert succeed
    END;
    
    RETURN NEW;
END;
$$;

-- Recreate trigger
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;

CREATE TRIGGER message_notification_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

-- Grant permissions
GRANT EXECUTE ON FUNCTION notify_new_message() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_message() TO anon;
GRANT EXECUTE ON FUNCTION notify_new_message() TO service_role;

SELECT 'Debug trigger installed - check Postgres logs after sending message' as status;


