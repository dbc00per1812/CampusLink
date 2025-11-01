-- ============================================
-- DIAGNOSTIC: Find Out Why Notifications Aren't Working
-- ============================================
-- Run this entire script and share the results
-- This will help us figure out exactly what's broken
-- ============================================

-- ============================================
-- CHECK 1: Are the triggers installed?
-- ============================================
SELECT '=== CHECK 1: TRIGGERS ===' as check;

SELECT 
    trigger_name,
    event_object_table as table_name,
    action_timing,
    event_manipulation as event_type
FROM information_schema.triggers
WHERE event_object_table IN ('messages', 'orders', 'offers')
AND trigger_schema = 'public'
ORDER BY event_object_table, trigger_name;

-- Should show at least message_notification_trigger for messages table
-- If this shows NOTHING for messages, the trigger isn't installed

-- ============================================
-- CHECK 2: Are the functions installed?
-- ============================================
SELECT '=== CHECK 2: FUNCTIONS ===' as check;

SELECT 
    routine_name,
    routine_type,
    routine_definition
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE 'notify_%'
ORDER BY routine_name;

-- Should show notify_new_message, notify_new_order, etc.

-- ============================================
-- CHECK 3: Recent messages - were any sent?
-- ============================================
SELECT '=== CHECK 3: RECENT MESSAGES ===' as check;

SELECT 
    m.id,
    m.sender_id,
    m.conversation_id,
    m.content,
    m.created_at,
    sender.name as sender_name
FROM messages m
LEFT JOIN users sender ON m.sender_id = sender.id
ORDER BY m.created_at DESC
LIMIT 5;

-- This shows if messages are actually being sent

-- ============================================
-- CHECK 4: Were notifications created for those messages?
-- ============================================
SELECT '=== CHECK 4: MESSAGE NOTIFICATIONS ===' as check;

SELECT 
    n.id,
    n.type,
    n.title,
    n.body,
    n.user_id as recipient_id,
    n.related_user_id as sender_id,
    n.message_id,
    n.created_at,
    recipient.name as recipient_name,
    sender.name as sender_name
FROM notifications n
LEFT JOIN users recipient ON n.user_id = recipient.id
LEFT JOIN users sender ON n.related_user_id = sender.id
WHERE n.type = 'new_message'
ORDER BY n.created_at DESC
LIMIT 5;

-- If no rows: notifications aren't being created
-- If rows but old timestamps: trigger stopped working at some point

-- ============================================
-- CHECK 5: Are there conversations?
-- ============================================
SELECT '=== CHECK 5: CONVERSATIONS ===' as check;

SELECT 
    c.id,
    c.buyer_id,
    c.seller_id,
    buyer.name as buyer_name,
    seller.name as seller_name,
    c.last_message_at
FROM conversations c
LEFT JOIN users buyer ON c.buyer_id = buyer.id
LEFT JOIN users seller ON c.seller_id = seller.id
ORDER BY c.last_message_at DESC
LIMIT 5;

-- Need this to match sender_id to recipient_id

-- ============================================
-- CHECK 6: RLS Policies on notifications table
-- ============================================
SELECT '=== CHECK 6: RLS POLICIES ===' as check;

SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_expression,
    with_check as check_expression
FROM pg_policies 
WHERE tablename = 'notifications'
ORDER BY cmd;

-- Need to see if INSERT is allowed

-- ============================================
-- CHECK 7: Test the function manually
-- ============================================
SELECT '=== CHECK 7: MANUAL FUNCTION TEST ===' as check;

-- Get the most recent message to test with
DO $$
DECLARE
    v_test_message_id UUID;
    v_test_sender_id UUID;
    v_test_conversation_id UUID;
    v_test_content TEXT;
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_message_preview TEXT;
BEGIN
    -- Get the most recent message
    SELECT id, sender_id, conversation_id, content
    INTO v_test_message_id, v_test_sender_id, v_test_conversation_id, v_test_content
    FROM messages
    ORDER BY created_at DESC
    LIMIT 1;
    
    IF v_test_message_id IS NOT NULL THEN
        RAISE NOTICE 'Testing with message ID: %', v_test_message_id;
        RAISE NOTICE 'Sender ID: %', v_test_sender_id;
        RAISE NOTICE 'Conversation ID: %', v_test_conversation_id;
        
        -- Get sender's name
        SELECT name INTO v_sender_name
        FROM users
        WHERE id = v_test_sender_id;
        
        RAISE NOTICE 'Sender name: %', COALESCE(v_sender_name, 'NULL');
        
        -- Determine recipient
        SELECT 
            CASE 
                WHEN c.buyer_id = v_test_sender_id THEN c.seller_id
                ELSE c.buyer_id
            END INTO v_recipient_id
        FROM conversations c
        WHERE c.id = v_test_conversation_id;
        
        RAISE NOTICE 'Recipient ID: %', COALESCE(v_recipient_id::text, 'NULL');
        
        -- Create preview
        v_message_preview := SUBSTRING(v_test_content, 1, 50);
        IF LENGTH(v_test_content) > 50 THEN
            v_message_preview := v_message_preview || '...';
        END IF;
        
        RAISE NOTICE 'Message preview: %', v_message_preview;
        
        -- Try to insert notification
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
                jsonb_build_object('message_id', v_test_message_id::text, 'conversation_id', v_test_conversation_id::text),
                v_test_message_id,
                v_test_sender_id,
                NOW()
            );
            RAISE NOTICE '✅ SUCCESS: Notification inserted manually!';
        EXCEPTION WHEN OTHERS THEN
            RAISE NOTICE '❌ ERROR: Could not insert notification: %', SQLERRM;
        END;
    ELSE
        RAISE NOTICE 'No messages found in database';
    END IF;
END $$;

-- ============================================
-- CHECK 8: Check if RLS is enabled
-- ============================================
SELECT '=== CHECK 8: RLS STATUS ===' as check;

SELECT 
    tablename,
    rowsecurity as rls_enabled
FROM pg_tables
WHERE schemaname = 'public'
AND tablename IN ('notifications', 'messages', 'conversations');

-- ============================================
-- SUMMARY
-- ============================================
SELECT '=== SUMMARY ===' as check;
SELECT 'Copy ALL output above and share it so we can diagnose the issue!' as instructions;



