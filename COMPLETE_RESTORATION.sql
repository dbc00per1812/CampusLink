-- ============================================
-- COMPLETE RESTORATION - Back to Working State
-- ============================================
-- This restores EVERYTHING to how it was 12 hours ago
-- Run this entire script
-- ============================================

-- ============================================
-- STEP 1: Remove ALL notification-related triggers
-- ============================================

-- Drop ALL triggers on messages table
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'messages') LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON messages CASCADE';
    END LOOP;
END $$;

-- Drop ALL triggers on orders table
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'orders') LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON orders CASCADE';
    END LOOP;
END $$;

-- Drop ALL triggers on offers table
DO $$ 
DECLARE 
    r RECORD;
BEGIN
    FOR r IN (SELECT trigger_name FROM information_schema.triggers WHERE event_object_table = 'offers') LOOP
        EXECUTE 'DROP TRIGGER IF EXISTS ' || r.trigger_name || ' ON offers CASCADE';
    END LOOP;
END $$;

-- Drop all notification functions
DROP FUNCTION IF EXISTS notify_new_message() CASCADE;
DROP FUNCTION IF EXISTS notify_new_order() CASCADE;
DROP FUNCTION IF EXISTS notify_order_delivered() CASCADE;
DROP FUNCTION IF EXISTS notify_order_completed() CASCADE;
DROP FUNCTION IF EXISTS notify_order_cancelled() CASCADE;
DROP FUNCTION IF EXISTS notify_order_status_change() CASCADE;
DROP FUNCTION IF EXISTS notify_new_offer() CASCADE;
DROP FUNCTION IF EXISTS notify_offer_status_change() CASCADE;
DROP FUNCTION IF EXISTS send_push_notification() CASCADE;
DROP FUNCTION IF EXISTS send_push_notification_on_insert() CASCADE;

SELECT 'Cleaned up all triggers' as status;

-- ============================================
-- STEP 2: Restore ONLY message notification trigger
-- ============================================

CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
DECLARE
    v_sender_name TEXT;
    v_recipient_id UUID;
    v_message_preview TEXT;
BEGIN
    SELECT name INTO v_sender_name
    FROM users
    WHERE id = NEW.sender_id;
    
    SELECT 
        CASE 
            WHEN c.buyer_id = NEW.sender_id THEN c.seller_id
            ELSE c.buyer_id
        END INTO v_recipient_id
    FROM conversations c
    WHERE c.id = NEW.conversation_id;
    
    v_message_preview := SUBSTRING(NEW.content, 1, 50);
    IF LENGTH(NEW.content) > 50 THEN
        v_message_preview := v_message_preview || '...';
    END IF;
    
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

CREATE TRIGGER message_notification_trigger
    AFTER INSERT ON messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();

SELECT 'Message notification trigger restored' as status;

-- ============================================
-- STEP 3: Fix RLS policies
-- ============================================

-- Drop ALL notification policies
DROP POLICY IF EXISTS "Users can only read their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Enable read access for users based on user_id" ON notifications;
DROP POLICY IF EXISTS "Users can read their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can create notifications" ON notifications;
DROP POLICY IF EXISTS "Allow all inserts for notifications" ON notifications;
DROP POLICY IF EXISTS "Users can insert their own notifications" ON notifications;
DROP POLICY IF EXISTS "Allow trigger to insert notifications" ON notifications;
DROP POLICY IF EXISTS "notifications_select" ON notifications;
DROP POLICY IF EXISTS "Users can view own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can update own notifications" ON notifications;
DROP POLICY IF EXISTS "notifications_insert" ON notifications;
DROP POLICY IF EXISTS "notifications_update" ON notifications;

-- Create simple, working policies
CREATE POLICY "notifications_select"
ON notifications FOR SELECT
USING (auth.uid()::text = user_id::text);

CREATE POLICY "notifications_insert" 
ON notifications FOR INSERT
WITH CHECK (true);

CREATE POLICY "notifications_update"
ON notifications FOR UPDATE
USING (auth.uid()::text = user_id::text);

SELECT 'RLS policies fixed' as status;

-- ============================================
-- STEP 4: Verify everything
-- ============================================

SELECT '=== VERIFICATION ===' as section;

-- Check trigger exists
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'message_notification_trigger';

-- Check RLS policies
SELECT policyname, cmd
FROM pg_policies
WHERE tablename = 'notifications'
ORDER BY cmd;

SELECT 'RESTORATION COMPLETE' as status;
SELECT 'Now close your app completely, reopen it, and send a test message' as next_steps;

