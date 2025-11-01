-- ============================================
-- VERIFY PUSH NOTIFICATIONS ARE BEING PROCESSED
-- ============================================
-- Run this after waiting 1-2 minutes
-- ============================================

-- Check how many have been processed
SELECT 
    'PROCESSING STATUS:' as check_name,
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE processed = true) as processed,
    COUNT(*) FILTER (WHERE processed = false) as pending,
    COUNT(*) FILTER (WHERE error IS NOT NULL) as errors
FROM push_notification_queue;

-- See the most recent processed notifications
SELECT 
    'RECENTLY PROCESSED:' as check_name,
    id,
    notification_type,
    title,
    processed,
    processed_at,
    error,
    created_at
FROM push_notification_queue
WHERE processed = true
ORDER BY processed_at DESC
LIMIT 10;

-- Check if there were any errors
SELECT 
    'ERRORS (if any):' as check_name,
    id,
    notification_type,
    title,
    error,
    created_at
FROM push_notification_queue
WHERE error IS NOT NULL
ORDER BY created_at DESC
LIMIT 5;

-- Check when cron job last ran
SELECT 
    'CRON JOB STATUS:' as check_name,
    jobname,
    last_run,
    next_run,
    active
FROM cron.job_run_details
WHERE jobid = 2
ORDER BY run_id DESC
LIMIT 1;

-- ============================================
-- WHAT YOU SHOULD SEE:
-- - processed count increasing (should be 15 or close to it)
-- - processed_at timestamps within last few minutes
-- - hopefully no errors!
-- - cron last_run should be recent (within last minute)
-- ============================================


