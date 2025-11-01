-- ============================================
-- SETUP AUTOMATIC PUSH NOTIFICATION PROCESSING
-- ============================================
-- This uses Supabase's built-in cron (better than Vercel)
-- Runs every minute to process the push queue
-- ============================================

-- Step 1: Enable pg_cron extension
SELECT cron.schedule(
    'process-push-notifications',  -- job name
    '* * * * *',                    -- every minute
    $$
    SELECT
      net.http_post(
          url:='https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue',
          headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MzU2OTkxOSwiZXhwIjoyMDY5MTQ1OTE5fQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw"}'::jsonb,
          body:='{}'::jsonb
      ) as request_id;
    $$
);

-- Step 2: Verify it's scheduled
SELECT 
    jobid,
    jobname,
    schedule,
    active
FROM cron.job
WHERE jobname = 'process-push-notifications';

-- ============================================
-- BEFORE RUNNING:
-- Replace YOUR_SERVICE_ROLE_KEY_HERE with your actual key
-- Get it from: Supabase Dashboard → Settings → API → service_role key
-- ============================================

-- To unschedule (if needed):
-- SELECT cron.unschedule('process-push-notifications');
-- ============================================


