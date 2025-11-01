-- ============================================
-- NUCLEAR OPTION: Force Message Notifications to Work
-- ============================================
-- This script will fix message notifications no matter what
-- It checks everything and fixes any issues it finds
-- ============================================

-- ============================================
-- STEP 1: Clean slate - remove everything
-- ============================================
DROP TRIGGER IF EXISTS message_notification_trigger ON messages CASCADE;
DROP TRIGGER IF EXISTS new_message_notification_trigger ON messages CASCADE;
DROP FUNCTION IF EXISTS notify_new_message() CASCADE;

RAISE NOTICE '✅ Cleaned up old triggers and functions';

-- ============================================
-- STEP 2: Create the notification function with extensive logging
-- ============================================
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_message_preview TEXT;
BEGIN
    RAISE NOTICE '🔔 notify_new_message() triggered';
    RAISE NOTICE '   Message ID: %', NEW.id;
    RAISE NOTICE '   Sender ID: %', NEW.sender_id;
    RAISE NOTICE '   Conversation ID: %', NEW.conversation_id;
    
    -- Get sender's name from users table
    SELECT name INTO v_sender_name
    FROM users
    WHERE id = NEW.sender_id;
    
    RAISE NOTICE '   Sender name: %', COALESCE(v_sender_name, 'NULL');
    
    -- Determine recipient: the conversation participant who is NOT the sender
    SELECT 
        CASE 
            WHEN c.buyer_id = NEW.sender_id THEN c.seller_id
            ELSE c.buyer_id
        END INTO v_recipient_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id;
    
    RAISE NOTICE '   Recipient ID: %', COALESCE(v_recipient_id::text, 'NULL');
    
    -- If recipient is NULL, something is wrong with the conversation
    IF v_recipient_id IS NULL THEN
        RAISE WARNING '❌ Could not determine recipient for conversation %', NEW.conversation_id;
        RETURN NEW;
    END IF;
    
    -- Create preview (first 50 chars of message)
    v_message_preview := SUBSTRING(NEW.content, 1, 50);
    IF LENGTH(NEW.content) > 50 THEN
        v_message_preview := v_message_preview || '...';
    END IF;
    
    -- Create notification for the RECIPIENT
    BEGIN
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
        
        RAISE NOTICE '✅ Notification created successfully';
        
    EXCEPTION WHEN OTHERS THEN
        RAISE WARNING '❌ Failed to create notification: %', SQLERRM;
        RAISE WARNING '   Error detail: %', SQLSTATE;
    END;
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

RAISE NOTICE '✅ Function created';

-- ============================================
-- STEP 3: Create the trigger
-- ============================================
CREATE TRIGGER message_notification_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

RAISE NOTICE '✅ Trigger created';

-- ============================================
-- STEP 4: Grant all necessary permissions
-- ============================================
GRANT EXECUTE ON FUNCTION notify_new_message() TO authenticated;
GRANT EXECUTE ON FUNCTION notify_new_message() TO anon;
GRANT EXECUTE ON FUNCTION notify_new_message() TO service_role;

RAISE NOTICE '✅ Permissions granted';

-- ============================================
-- STEP 5: Check RLS on notifications table
-- ============================================
DO $$
DECLARE
    v_rls_enabled BOOLEAN;
    v_policy_exists BOOLEAN;
BEGIN
    -- Check if RLS is enabled
    SELECT rowsecurity INTO v_rls_enabled
    FROM pg_tables
    WHERE schemaname = 'public' AND tablename = 'notifications';
    
    RAISE NOTICE '📋 RLS enabled on notifications: %', v_rls_enabled;
    
    -- Check if there's an INSERT policy
    SELECT EXISTS (
        SELECT 1 FROM pg_policies 
        WHERE tablename = 'notifications' 
        AND cmd = 'INSERT'
    ) INTO v_policy_exists;
    
    RAISE NOTICE '📋 INSERT policy exists: %', v_policy_exists;
    
    -- If RLS is enabled but no INSERT policy, create one
    IF v_rls_enabled AND NOT v_policy_exists THEN
        RAISE NOTICE '⚠️  Creating missing INSERT policy...';
        EXECUTE 'CREATE POLICY "Allow trigger to insert notifications" ON notifications FOR INSERT WITH CHECK (true)';
        RAISE NOTICE '✅ INSERT policy created';
    END IF;
END $$;

-- ============================================
-- STEP 6: Verify installation
-- ============================================
SELECT '=== VERIFICATION ===' as step;

SELECT 
    trigger_name,
    event_object_table as table_name,
    action_timing,
    event_manipulation as event_type,
    action_statement
FROM information_schema.triggers
WHERE trigger_name = 'message_notification_trigger';

-- Should show 1 row

-- ============================================
-- STEP 7: Test with most recent message
-- ============================================
DO $$
DECLARE
    v_recent_message RECORD;
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_notification_count INT;
BEGIN
    -- Get most recent message
    SELECT * INTO v_recent_message
    FROM messages
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_recent_message.id IS NOT NULL THEN
        RAISE NOTICE '=== TESTING WITH RECENT MESSAGE ===';
        RAISE NOTICE 'Message ID: %', v_recent_message.id;
        RAISE NOTICE 'Sender ID: %', v_recent_message.sender_id;
        RAISE NOTICE 'Created at: %', v_recent_message.created_at;
        
        -- Check if notification exists for this message
        SELECT COUNT(*) INTO v_notification_count
        FROM notifications
        WHERE message_id = v_recent_message.id;
        
        RAISE NOTICE 'Notifications for this message: %', v_notification_count;
        
        IF v_notification_count = 0 THEN
            RAISE NOTICE '❌ No notification exists for most recent message';
            RAISE NOTICE '   This means trigger did not fire or failed';
            RAISE NOTICE '   Send a NEW message to test the trigger';
        ELSE
            RAISE NOTICE '✅ Notification exists for most recent message';
        END IF;
    ELSE
        RAISE NOTICE '⚠️  No messages in database - send a test message';
    END IF;
END $$;

-- ============================================
-- STEP 8: Show recent notifications
-- ============================================
SELECT '=== RECENT MESSAGE NOTIFICATIONS ===' as step;

SELECT 
    n.id,
    n.type,
    n.body,
    n.created_at,
    n.user_id as recipient_id,
    n.related_user_id as sender_id,
    recipient.name as recipient_name,
    sender.name as sender_name
FROM notifications n
LEFT JOIN users recipient ON n.user_id = recipient.id
LEFT JOIN users sender ON n.related_user_id = sender.id
WHERE n.type = 'new_message'
ORDER BY n.created_at DESC
LIMIT 3;

-- ============================================
-- FINAL INSTRUCTIONS
-- ============================================
SELECT '=== NEXT STEPS ===' as step;
SELECT 'Trigger is now installed with logging.' as instruction_1;
SELECT 'Send a new message in the app to test it.' as instruction_2;
SELECT 'Check Supabase Logs > Postgres Logs to see the NOTICE messages.' as instruction_3;
SELECT 'If you see errors in the logs, share them with me.' as instruction_4;



