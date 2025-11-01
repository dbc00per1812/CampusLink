-- ============================================
-- DIAGNOSE: Why Message Notifications Aren't Working
-- ============================================
-- This will help us find exactly where the flow is breaking
-- ============================================

-- STEP 1: Check if message trigger exists
-- ============================================
SELECT '=' as separator;
SELECT '1️⃣ MESSAGE TRIGGER CHECK' as step;
SELECT '=' as separator;

SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'messages'
  AND trigger_name LIKE '%notification%';

-- Expected: message_notification_trigger on messages table (AFTER INSERT)

-- STEP 2: Check if notify_new_message function exists
-- ============================================
SELECT '=' as separator;
SELECT '2️⃣ NOTIFY FUNCTION CHECK' as step;
SELECT '=' as separator;

SELECT 
    routine_name,
    routine_type,
    security_type
FROM information_schema.routines
WHERE routine_name = 'notify_new_message';

-- Expected: notify_new_message function with DEFINER security

-- STEP 3: Check if push queue trigger exists
-- ============================================
SELECT '=' as separator;
SELECT '3️⃣ PUSH QUEUE TRIGGER CHECK' as step;
SELECT '=' as separator;

SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'notifications'
  AND trigger_name LIKE '%push%';

-- Expected: push_queue_trigger on notifications table (AFTER INSERT)

-- STEP 4: Check if queue_push_notification function exists
-- ============================================
SELECT '=' as separator;
SELECT '4️⃣ QUEUE PUSH FUNCTION CHECK' as step;
SELECT '=' as separator;

SELECT 
    routine_name,
    routine_type,
    security_type
FROM information_schema.routines
WHERE routine_name LIKE '%queue_push%';

-- Expected: queue_push_notification function with DEFINER security

-- STEP 5: Check recent messages (last 5)
-- ============================================
SELECT '=' as separator;
SELECT '5️⃣ RECENT MESSAGES' as step;
SELECT '=' as separator;

SELECT 
    id,
    sender_id,
    conversation_id,
    LEFT(content, 50) as content_preview,
    created_at
FROM messages
ORDER BY created_at DESC
LIMIT 5;

-- STEP 6: Check recent notifications (last 10)
-- ============================================
SELECT '=' as separator;
SELECT '6️⃣ RECENT NOTIFICATIONS' as step;
SELECT '=' as separator;

SELECT 
    id,
    user_id,
    type,
    title,
    LEFT(body, 50) as body_preview,
    message_id,
    created_at
FROM notifications
ORDER BY created_at DESC
LIMIT 10;

-- Expected: Should see notification created for each message
-- If messages exist but NO matching notifications -> Trigger #1 is broken

-- STEP 7: Check push notification queue
-- ============================================
SELECT '=' as separator;
SELECT '7️⃣ PUSH QUEUE STATUS' as step;
SELECT '=' as separator;

SELECT 
    id,
    user_id,
    notification_type,
    title,
    LEFT(body, 50) as body_preview,
    processed,
    error,
    created_at
FROM push_notification_queue
ORDER BY created_at DESC
LIMIT 10;

-- Expected: Should see push queue entry for each notification
-- If notifications exist but NO queue entries -> Trigger #2 is broken

-- STEP 8: Check user notification preferences for test accounts
-- ============================================
SELECT '=' as separator;
SELECT '8️⃣ USER PREFERENCES CHECK' as step;
SELECT '=' as separator;

SELECT 
    user_id,
    push_enabled,
    CASE 
        WHEN push_token IS NOT NULL THEN 'Has Token (' || LEFT(push_token, 20) || '...)'
        ELSE 'No Token ❌'
    END as token_status,
    updated_at
FROM user_notification_preferences
ORDER BY updated_at DESC
LIMIT 5;

-- Expected: Users should have push_enabled = true AND a push_token
-- If no push_token -> The app hasn't registered for push notifications

-- STEP 9: Count unprocessed items in queue
-- ============================================
SELECT '=' as separator;
SELECT '9️⃣ UNPROCESSED QUEUE ITEMS' as step;
SELECT '=' as separator;

SELECT 
    COUNT(*) as unprocessed_count,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM push_notification_queue
WHERE processed = false;

-- Expected: Should be 0 if edge function is running regularly
-- If many unprocessed -> Edge function not running or failing

-- STEP 10: Check for any processing errors
-- ============================================
SELECT '=' as separator;
SELECT '🔟 RECENT PROCESSING ERRORS' as step;
SELECT '=' as separator;

SELECT 
    id,
    user_id,
    notification_type,
    error,
    created_at
FROM push_notification_queue
WHERE error IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- Expected: Ideally no errors
-- If errors exist -> They tell us exactly what's failing

-- STEP 11: Verify conversations exist
-- ============================================
SELECT '=' as separator;
SELECT '1️⃣1️⃣ RECENT CONVERSATIONS' as step;
SELECT '=' as separator;

SELECT 
    id,
    buyer_id,
    seller_id,
    created_at,
    updated_at
FROM conversations
ORDER BY updated_at DESC
LIMIT 5;

-- ============================================
-- INTERPRETATION GUIDE
-- ============================================
-- 
-- IF: Messages exist but NO notifications
-- → The message_notification_trigger isn't working
-- → Solution: Run RESTORE_WORKING_MESSAGES.sql
--
-- IF: Notifications exist but NO push queue entries
-- → The push_queue_trigger isn't working
-- → Solution: Run FINAL_FIX_PUSH.sql
--
-- IF: Push queue entries exist but all unprocessed
-- → The edge function isn't running
-- → Solution: Check Supabase cron job OR manually invoke
--
-- IF: Push queue has "No user preferences found" errors
-- → User hasn't set up notification preferences
-- → Solution: App needs to call updatePushToken on login
--
-- IF: User preferences shows "No Token"
-- → App hasn't registered device token with APNs
-- → Solution: Check iOS permission & NotificationService registration
--
-- IF: Everything looks good but still no notifications
-- → Check if device token is valid for correct APNs environment
-- → Check if APNS_ENV matches your device (sandbox vs production)
-- ============================================

