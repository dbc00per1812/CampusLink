-- ============================================
-- TEST: Verify Push Notifications Are Working
-- ============================================
-- Run this AFTER you've sent a test message
-- ============================================

-- 1. Check recent notifications created
SELECT 
    'RECENT NOTIFICATIONS:' as check_name,
    id,
    user_id,
    type,
    title,
    LEFT(body, 50) as body_preview,
    created_at
FROM notifications
ORDER BY created_at DESC
LIMIT 5;

-- 2. Check if they made it to push queue
SELECT 
    'PUSH QUEUE (Should have matching entries):' as check_name,
    id,
    user_id,
    notification_type,
    title,
    LEFT(body, 50) as body_preview,
    processed,
    processed_at,
    error,
    created_at
FROM push_notification_queue
ORDER BY created_at DESC
LIMIT 5;

-- 3. Check push token status
SELECT 
    'YOUR PUSH TOKEN STATUS:' as check_name,
    u.id,
    u.email,
    p.push_enabled,
    p.push_token IS NOT NULL as has_token,
    LENGTH(p.push_token) as token_length,
    p.push_platform
FROM users u
LEFT JOIN user_notification_preferences p ON p.user_id = u.id
WHERE u.email = (SELECT email FROM auth.users WHERE id = auth.uid())
LIMIT 1;

-- 4. Check trigger exists
SELECT 
    'TRIGGER STATUS:' as check_name,
    trigger_name,
    event_manipulation,
    action_timing
FROM information_schema.triggers
WHERE event_object_table = 'notifications'
AND trigger_name = 'push_queue_trigger';

-- ============================================
-- WHAT TO LOOK FOR:
-- ============================================
-- 1. Recent notifications exist ✅
-- 2. Matching entries in push_queue with processed=false ✅
-- 3. You have push_enabled=true and has_token=true ✅
-- 4. Trigger exists ✅
--
-- If all 4 are ✅ but still no push:
-- - Check Vercel cron is running (api/process-notifications.js)
-- - Check edge function logs in Supabase dashboard
-- - Check if processed_at gets updated (means edge function is working)
-- ============================================


