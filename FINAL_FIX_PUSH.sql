-- ============================================
-- FINAL PUSH NOTIFICATION FIX
-- ============================================
-- This will fix everything in one go
-- ============================================

-- STEP 1: Check current state
-- ============================

-- Do we have ANY triggers on notifications table?
SELECT 'CURRENT TRIGGERS ON NOTIFICATIONS:' as status;
SELECT trigger_name, action_statement
FROM information_schema.triggers
WHERE event_object_table = 'notifications';

-- Do we have device tokens?
SELECT 'USERS WITH PUSH TOKENS:' as status;
SELECT 
    u.id,
    u.email,
    u.name,
    p.push_token IS NOT NULL as has_token,
    p.push_enabled,
    p.push_platform
FROM users u
LEFT JOIN user_notification_preferences p ON p.user_id = u.id
LIMIT 5;

-- What's in push queue?
SELECT 'CURRENT PUSH QUEUE:' as status;
SELECT COUNT(*) as total, COUNT(*) FILTER (WHERE processed = false) as unprocessed
FROM push_notification_queue;

-- STEP 2: Drop any existing push queue trigger
-- =============================================
DROP TRIGGER IF EXISTS push_queue_trigger ON notifications CASCADE;
DROP TRIGGER IF EXISTS queue_push_notification_trigger ON notifications CASCADE;
DROP TRIGGER IF EXISTS create_push_queue_trigger ON notifications CASCADE;
DROP FUNCTION IF EXISTS queue_push_notification() CASCADE;
DROP FUNCTION IF EXISTS create_push_queue_entry() CASCADE;

-- STEP 3: Create the correct trigger
-- ===================================
CREATE OR REPLACE FUNCTION queue_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_push_enabled BOOLEAN;
    v_has_token BOOLEAN;
BEGIN
    -- Check if user has push enabled and a token
    SELECT 
        COALESCE(push_enabled, true),
        push_token IS NOT NULL
    INTO v_push_enabled, v_has_token
    FROM user_notification_preferences
    WHERE user_id = NEW.user_id;
    
    -- Only queue if user has push enabled and has a device token
    IF v_push_enabled AND v_has_token THEN
        INSERT INTO push_notification_queue (
            user_id,
            notification_type,
            title,
            body,
            data,
            processed,
            created_at
        ) VALUES (
            NEW.user_id,
            NEW.type,
            NEW.title,
            NEW.body,
            COALESCE(NEW.data, '{}'::jsonb),
            false,
            NOW()
        );
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    -- Don't fail the notification creation if push queue fails
    RAISE WARNING 'Failed to queue push notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger
CREATE TRIGGER push_queue_trigger
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION queue_push_notification();

-- STEP 4: Check RLS policies on push_notification_queue
-- ======================================================
SELECT 'RLS POLICIES ON PUSH_QUEUE:' as status;
SELECT policyname, cmd, qual, with_check
FROM pg_policies
WHERE tablename = 'push_notification_queue';

-- If restrictive, fix them
DROP POLICY IF EXISTS "Users can view own push queue" ON push_notification_queue;
DROP POLICY IF EXISTS "Service role can insert push queue" ON push_notification_queue;
DROP POLICY IF EXISTS "Allow trigger insert" ON push_notification_queue;

-- Simple policies: let triggers insert (SECURITY DEFINER), let users view their own
CREATE POLICY "push_queue_select"
ON push_notification_queue FOR SELECT
USING (auth.uid() = user_id);

CREATE POLICY "push_queue_insert"
ON push_notification_queue FOR INSERT
WITH CHECK (true); -- Triggers run as SECURITY DEFINER

-- STEP 5: Verify setup
-- =====================
SELECT 'FINAL VERIFICATION:' as status;
SELECT 
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'notifications'
AND trigger_name = 'push_queue_trigger';

-- ============================================
-- NOW TEST IT:
-- ============================================
-- 1. Send a message in your app
-- 2. Run this query to check:
--
-- SELECT * FROM notifications ORDER BY created_at DESC LIMIT 3;
-- SELECT * FROM push_notification_queue ORDER BY created_at DESC LIMIT 3;
--
-- You should see:
-- - New record in notifications ✅
-- - New record in push_notification_queue with processed=false ✅
-- - Within 1 minute, processed should change to true ✅
-- ============================================


