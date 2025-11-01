-- ============================================
-- COMPLETE PUSH NOTIFICATION FLOW TEST
-- ============================================
-- Run this to verify the entire push notification system
-- ============================================

-- 1. CHECK IF EDGE FUNCTION EXISTS
-- =================================
SELECT 
    '1️⃣ EDGE FUNCTION CHECK' as test_step,
    'Go to Supabase Dashboard → Edge Functions' as instruction,
    'You should see: process-push-queue' as expected_result;

-- 2. CHECK ENVIRONMENT VARIABLES
-- ==============================
SELECT 
    '2️⃣ ENVIRONMENT VARIABLES CHECK' as test_step,
    'Go to Supabase Dashboard → Settings → Edge Functions' as instruction,
    'Verify these secrets exist: APNS_TEAM_ID, APNS_KEY_ID, APNS_PRIVATE_KEY, BUNDLE_ID, APNS_ENV' as expected_result;

-- 3. CHECK DATABASE TRIGGER EXISTS
-- =================================
SELECT 
    '3️⃣ DATABASE TRIGGER CHECK' as test_step;

SELECT 
    trigger_name,
    event_manipulation,
    action_timing,
    CASE 
        WHEN trigger_name = 'push_queue_trigger' THEN '✅ CORRECT'
        ELSE '❌ WRONG TRIGGER'
    END as status
FROM information_schema.triggers
WHERE event_object_table = 'notifications'
ORDER BY trigger_name;

-- If no results, trigger is missing!

-- 4. CHECK TRIGGER FUNCTION EXISTS
-- =================================
SELECT 
    '4️⃣ TRIGGER FUNCTION CHECK' as test_step;

SELECT 
    routine_name,
    CASE 
        WHEN routine_name = 'queue_push_notification' THEN '✅ CORRECT'
        ELSE '❌ OTHER FUNCTION'
    END as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name LIKE '%push%'
ORDER BY routine_name;

-- 5. CHECK PUSH QUEUE TABLE
-- ==========================
SELECT 
    '5️⃣ PUSH QUEUE TABLE CHECK' as test_step;

SELECT 
    COUNT(*) as total_records,
    COUNT(*) FILTER (WHERE processed = false) as unprocessed,
    COUNT(*) FILTER (WHERE processed = true) as processed,
    COUNT(*) FILTER (WHERE error IS NOT NULL) as has_errors,
    MAX(created_at) as most_recent,
    MAX(processed_at) as last_processed,
    CASE 
        WHEN MAX(processed_at) > NOW() - INTERVAL '5 minutes' THEN '✅ RECENTLY PROCESSED'
        WHEN MAX(processed_at) IS NULL THEN '⚠️ NEVER PROCESSED'
        ELSE '⚠️ NOT PROCESSING (last processed > 5 min ago)'
    END as processing_status
FROM push_notification_queue;

-- 6. CHECK USERS WITH PUSH TOKENS
-- ================================
SELECT 
    '6️⃣ USER PUSH TOKEN CHECK' as test_step;

SELECT 
    u.id,
    u.name,
    u.email,
    p.push_token IS NOT NULL as has_token,
    p.push_enabled as push_enabled,
    p.push_platform as platform,
    LEFT(p.push_token, 10) || '...' || RIGHT(p.push_token, 10) as token_preview,
    LENGTH(p.push_token) as token_length,
    CASE 
        WHEN p.push_token IS NULL THEN '❌ NO TOKEN'
        WHEN LENGTH(p.push_token) != 64 THEN '⚠️ INVALID TOKEN LENGTH'
        WHEN p.push_enabled = false THEN '⚠️ PUSH DISABLED'
        ELSE '✅ READY FOR PUSH'
    END as status
FROM users u
LEFT JOIN user_notification_preferences p ON p.user_id = u.id
ORDER BY u.created_at DESC
LIMIT 10;

-- 7. CHECK RECENT NOTIFICATIONS
-- ==============================
SELECT 
    '7️⃣ RECENT NOTIFICATIONS CHECK' as test_step;

SELECT 
    n.id,
    n.user_id,
    n.type,
    n.title,
    LEFT(n.body, 30) as body_preview,
    n.created_at,
    CASE 
        WHEN q.id IS NOT NULL THEN '✅ IN QUEUE'
        ELSE '❌ NOT IN QUEUE'
    END as queue_status,
    q.processed as queue_processed,
    q.error as queue_error
FROM notifications n
LEFT JOIN push_notification_queue q ON q.user_id = n.user_id AND q.created_at >= n.created_at AND q.created_at < n.created_at + INTERVAL '5 seconds'
ORDER BY n.created_at DESC
LIMIT 10;

-- 8. CHECK CRON JOB
-- =================
SELECT 
    '8️⃣ CRON JOB CHECK' as test_step;

SELECT 
    jobname,
    schedule,
    active,
    database,
    CASE 
        WHEN active = true THEN '✅ ACTIVE'
        ELSE '❌ INACTIVE'
    END as status
FROM cron.job
WHERE jobname LIKE '%push%' OR jobname LIKE '%notification%';

-- If no results, cron job is not set up!

-- 9. CHECK CRON JOB RUNS
-- =======================
SELECT 
    '9️⃣ CRON JOB HISTORY CHECK' as test_step;

SELECT 
    j.jobname,
    d.runid,
    d.status,
    d.start_time,
    d.end_time,
    EXTRACT(EPOCH FROM (d.end_time - d.start_time)) as duration_seconds,
    CASE 
        WHEN d.status = 'succeeded' THEN '✅ SUCCESS'
        WHEN d.status = 'failed' THEN '❌ FAILED'
        ELSE '⚠️ ' || d.status
    END as result
FROM cron.job j
LEFT JOIN cron.job_run_details d ON d.jobid = j.jobid
WHERE j.jobname LIKE '%push%' OR j.jobname LIKE '%notification%'
ORDER BY d.start_time DESC NULLS LAST
LIMIT 10;

-- 10. RLS POLICIES CHECK
-- ======================
SELECT 
    '🔟 RLS POLICIES CHECK' as test_step;

SELECT 
    schemaname,
    tablename,
    policyname,
    cmd,
    CASE 
        WHEN policyname LIKE '%push_queue%' THEN '✅ CORRECT'
        ELSE '⚠️ CHECK POLICY'
    END as status
FROM pg_policies
WHERE tablename = 'push_notification_queue'
ORDER BY policyname;

-- ============================================
-- SUMMARY
-- ============================================
SELECT 
    '📊 DIAGNOSTIC SUMMARY' as section,
    'Check all test steps above' as instruction,
    'All ✅ = System is working correctly' as success_criteria,
    'Any ❌ or ⚠️ = Follow recovery guide' as action_required;

-- ============================================
-- NEXT STEPS BASED ON RESULTS
-- ============================================

SELECT 
    '📝 INTERPRETATION GUIDE' as section;

-- If Step 1-2: Edge function doesn't exist
--   → Deploy edge function (see PUSH_NOTIFICATION_RECOVERY.md Step 1-2)

-- If Step 3-4: Trigger doesn't exist
--   → Run Step 3 SQL from PUSH_NOTIFICATION_RECOVERY.md

-- If Step 5: Queue has unprocessed items for > 5 minutes
--   → Cron job not working or edge function failing

-- If Step 6: Users don't have tokens
--   → Users need to open app and allow notifications

-- If Step 7: Notifications not making it to queue
--   → Trigger isn't firing, check Step 3-4

-- If Step 8-9: Cron job not set up or failing
--   → Run Step 4 SQL from PUSH_NOTIFICATION_RECOVERY.md

-- If Step 10: RLS policies missing
--   → Run Step 3 SQL from PUSH_NOTIFICATION_RECOVERY.md

-- ============================================
-- MANUAL TEST
-- ============================================

SELECT 
    '🧪 MANUAL TEST STEPS' as section,
    '1. Send a message in your app' as step_1,
    '2. Run Step 5 query above - should show unprocessed = 1' as step_2,
    '3. Wait 2 minutes' as step_3,
    '4. Run Step 5 query again - should show processed = 1' as step_4,
    '5. Check your phone for push notification' as step_5;

-- ============================================
-- TROUBLESHOOTING QUICK REFERENCE
-- ============================================

SELECT 
    '🔧 QUICK FIXES' as section;

-- Problem: No trigger (Step 3-4)
-- Solution: Run this:
/*
DROP TRIGGER IF EXISTS push_queue_trigger ON notifications CASCADE;
DROP FUNCTION IF EXISTS queue_push_notification() CASCADE;

CREATE OR REPLACE FUNCTION queue_push_notification()
RETURNS TRIGGER AS $$
DECLARE
    v_push_enabled BOOLEAN;
    v_has_token BOOLEAN;
BEGIN
    SELECT 
        COALESCE(push_enabled, true),
        push_token IS NOT NULL
    INTO v_push_enabled, v_has_token
    FROM user_notification_preferences
    WHERE user_id = NEW.user_id;
    
    IF v_push_enabled AND v_has_token THEN
        INSERT INTO push_notification_queue (
            user_id, notification_type, title, body, data, processed, created_at
        ) VALUES (
            NEW.user_id, NEW.type, NEW.title, NEW.body, 
            COALESCE(NEW.data, '{}'::jsonb), false, NOW()
        );
    END IF;
    
    RETURN NEW;
EXCEPTION WHEN OTHERS THEN
    RAISE WARNING 'Failed to queue push notification: %', SQLERRM;
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

CREATE TRIGGER push_queue_trigger
    AFTER INSERT ON notifications
    FOR EACH ROW
    EXECUTE FUNCTION queue_push_notification();
*/

-- Problem: No cron job (Step 8)
-- Solution: See PUSH_NOTIFICATION_RECOVERY.md Step 4

-- Problem: Edge function doesn't exist (Step 1)
-- Solution: Deploy it: npx supabase functions deploy process-push-queue --project-ref vnmzijluyctlufnzxast

-- ============================================
-- END OF DIAGNOSTIC
-- ============================================



