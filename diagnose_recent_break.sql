-- Quick Diagnosis: What broke recently?
-- Since push notifications were working before, let's find what changed

-- Step 1: Check if you still have push tokens (should be there if it was working)
SELECT 'STEP 1: Push Token Status' as debug_step;
SELECT 
  COUNT(*) as users_with_push_tokens
FROM user_notification_preferences 
WHERE push_token IS NOT NULL 
AND push_enabled = true;

-- If this is > 0, push tokens are fine

-- Step 2: Check recent notifications - are they being created?
SELECT 'STEP 2: Recent Database Notifications' as debug_step;
SELECT 
  DATE(created_at) as date,
  COUNT(*) as notification_count,
  type
FROM notifications 
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at), type
ORDER BY date DESC, type;

-- Step 3: Check push queue - are notifications being queued for push?
SELECT 'STEP 3: Push Queue Activity' as debug_step;
SELECT 
  DATE(created_at) as date,
  COUNT(*) as queued_pushes,
  COUNT(*) FILTER (WHERE processed = true) as processed_pushes,
  COUNT(*) FILTER (WHERE processed = false) as unprocessed_pushes
FROM push_notification_queue 
WHERE created_at >= NOW() - INTERVAL '7 days'
GROUP BY DATE(created_at)
ORDER BY date DESC;

-- Step 4: Check if triggers still exist
SELECT 'STEP 4: Trigger Status' as debug_step;
SELECT 
  schemaname,
  tablename, 
  triggername
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid  
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE triggername LIKE '%notification%'
ORDER BY tablename;

-- Step 5: Quick test - create a notification manually to see if push works
SELECT 'STEP 5: Manual Test Available' as debug_step;
SELECT 'Run this to test push manually:' as instruction;
SELECT '
INSERT INTO notifications (user_id, type, title, body, data)
SELECT user_id, ''test'', ''Test Push'', ''Manual test notification'', ''{}''::jsonb
FROM user_notification_preferences 
WHERE push_token IS NOT NULL 
LIMIT 1;
' as test_query;

-- LIKELY ISSUES (in order of probability):
SELECT '=== MOST LIKELY CAUSES ===' as diagnosis;
SELECT 'If queued_pushes = 0: Triggers stopped queueing push notifications' as cause_1;
SELECT 'If unprocessed_pushes > 0: Edge function stopped running' as cause_2;  
SELECT 'If no recent notifications: App stopped creating orders/messages' as cause_3;
SELECT 'If triggers missing: Database migration removed them' as cause_4;
