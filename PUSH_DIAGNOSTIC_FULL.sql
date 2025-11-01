-- ============================================
-- COMPREHENSIVE PUSH NOTIFICATION DIAGNOSTIC
-- ============================================
-- This will show us EVERYTHING about the current state
-- ============================================

-- 1. CHECK IF PUSH QUEUE TABLE EXISTS
-- ====================================
SELECT 
    'PUSH_NOTIFICATION_QUEUE TABLE' as check_name,
    COUNT(*) as record_count,
    COUNT(*) FILTER (WHERE processed = false) as unprocessed,
    COUNT(*) FILTER (WHERE processed = true) as processed,
    COUNT(*) FILTER (WHERE error IS NOT NULL) as has_errors,
    MAX(created_at) as most_recent
FROM push_notification_queue;

-- 2. CHECK ALL TRIGGERS ON NOTIFICATIONS TABLE
-- ============================================
SELECT 
    'TRIGGERS ON NOTIFICATIONS TABLE' as check_name;
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'notifications'
ORDER BY trigger_name;

-- 3. CHECK ALL TRIGGERS ON MESSAGES TABLE
-- =======================================
SELECT 
    'TRIGGERS ON MESSAGES TABLE' as check_name;
SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    LEFT(action_statement, 100) as action
FROM information_schema.triggers
WHERE event_object_table = 'messages'
ORDER BY trigger_name;

-- 4. CHECK ALL FUNCTIONS RELATED TO NOTIFICATIONS
-- ==============================================
SELECT 
    'NOTIFICATION RELATED FUNCTIONS' as check_name;
SELECT 
    routine_name,
    routine_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND (
    routine_name LIKE '%notification%'
    OR routine_name LIKE '%push%'
    OR routine_name LIKE '%queue%'
)
ORDER BY routine_name;

-- 5. CHECK RECENT NOTIFICATIONS
-- =============================
SELECT 
    'RECENT NOTIFICATIONS (Last 10)' as check_name;
SELECT 
    id,
    user_id,
    type,
    title,
    LEFT(body, 50) as body_preview,
    read,
    created_at
FROM notifications
ORDER BY created_at DESC
LIMIT 10;

-- 6. CHECK USERS WITH PUSH TOKENS
-- ===============================
SELECT 
    'USERS WITH PUSH TOKENS' as check_name;
SELECT 
    u.id,
    u.name,
    u.email,
    p.push_token IS NOT NULL as has_token,
    p.push_enabled,
    p.push_platform,
    LEFT(p.push_token, 20) as token_preview
FROM users u
LEFT JOIN user_notification_preferences p ON p.user_id = u.id
WHERE p.push_token IS NOT NULL
ORDER BY u.created_at DESC
LIMIT 10;

-- 7. CHECK RLS POLICIES ON PUSH QUEUE
-- ===================================
SELECT 
    'RLS POLICIES ON PUSH_NOTIFICATION_QUEUE' as check_name;
SELECT 
    policyname,
    cmd,
    qual,
    with_check
FROM pg_policies
WHERE tablename = 'push_notification_queue';

-- 8. CHECK CRON JOBS
-- ==================
SELECT 
    'CRON JOBS' as check_name;
SELECT 
    jobname,
    schedule,
    active,
    database
FROM cron.job
WHERE jobname LIKE '%push%' OR jobname LIKE '%notification%'
ORDER BY jobid;

-- 9. CHECK IF HTTP EXTENSION EXISTS
-- =================================
SELECT 
    'HTTP EXTENSION' as check_name,
    CASE 
        WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'http')
        THEN 'INSTALLED ✅'
        ELSE 'NOT INSTALLED ❌'
    END as status;

-- 10. SAMPLE PUSH QUEUE ENTRIES
-- =============================
SELECT 
    'SAMPLE PUSH QUEUE ENTRIES (Last 10)' as check_name;
SELECT 
    id,
    user_id,
    notification_type,
    title,
    processed,
    processed_at,
    error,
    created_at
FROM push_notification_queue
ORDER BY created_at DESC
LIMIT 10;

-- ============================================
-- SUMMARY
-- ============================================
SELECT 
    '=== DIAGNOSTIC COMPLETE ===' as status,
    'Review the output above to understand current state' as next_step;
