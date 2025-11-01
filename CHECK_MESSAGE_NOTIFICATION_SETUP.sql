-- ============================================
-- COMPREHENSIVE CHECK: Message Notification System
-- ============================================
-- Run this to diagnose why message notifications aren't working
-- ============================================

-- STEP 1: Check if message trigger exists
-- ============================================
SELECT '1️⃣ MESSAGE TRIGGER CHECK:' as step;
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'messages'
AND trigger_name LIKE '%notification%';

-- STEP 2: Check if notify_new_message function exists
-- ============================================
SELECT '2️⃣ NOTIFY FUNCTION CHECK:' as step;
SELECT 
    routine_name,
    routine_type,
    security_type
FROM information_schema.routines
WHERE routine_name = 'notify_new_message';

-- STEP 3: Check if push queue trigger exists on notifications table
-- ============================================
SELECT '3️⃣ PUSH QUEUE TRIGGER CHECK:' as step;
SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_statement,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'notifications'
AND trigger_name LIKE '%push%';

-- STEP 4: Check if queue_push_notification function exists
-- ============================================
SELECT '4️⃣ QUEUE PUSH FUNCTION CHECK:' as step;
SELECT 
    routine_name,
    routine_type,
    security_type
FROM information_schema.routines
WHERE routine_name LIKE '%push%';

-- STEP 5: Check recent messages
-- ============================================
SELECT '5️⃣ RECENT MESSAGES:' as step;
SELECT 
    id,
    sender_id,
    conversation_id,
    content,
    created_at
FROM messages
ORDER BY created_at DESC
LIMIT 5;

-- STEP 6: Check recent notifications
-- ============================================
SELECT '6️⃣ RECENT NOTIFICATIONS:' as step;
SELECT 
    id,
    user_id,
    type,
    title,
    body,
    message_id,
    created_at
FROM notifications
ORDER BY created_at DESC
LIMIT 10;

-- STEP 7: Check push notification queue
-- ============================================
SELECT '7️⃣ PUSH QUEUE STATUS:' as step;
SELECT 
    id,
    user_id,
    notification_type,
    title,
    body,
    processed,
    created_at
FROM push_notification_queue
ORDER BY created_at DESC
LIMIT 10;

-- STEP 8: Check user notification preferences
-- ============================================
SELECT '8️⃣ USER PREFERENCES:' as step;
SELECT 
    user_id,
    push_enabled,
    CASE 
        WHEN push_token IS NOT NULL THEN 'Has Token'
        ELSE 'No Token'
    END as token_status,
    updated_at
FROM user_notification_preferences
ORDER BY updated_at DESC
LIMIT 5;

-- STEP 9: Check if there are unprocessed items in queue
-- ============================================
SELECT '9️⃣ UNPROCESSED QUEUE ITEMS:' as step;
SELECT 
    COUNT(*) as unprocessed_count,
    MIN(created_at) as oldest,
    MAX(created_at) as newest
FROM push_notification_queue
WHERE processed = false;

