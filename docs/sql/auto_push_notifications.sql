-- ============================================================================
-- AUTO PUSH NOTIFICATIONS - Run these in Supabase SQL Editor
-- ============================================================================
-- This enables automatic push notification delivery without manual curl commands.
-- 
-- RECOMMENDED: Use OPTION B (instant trigger) for near-instant notifications
-- ============================================================================


-- ============================================================================
-- STEP 1: Enable the pg_net extension (REQUIRED for both options)
-- Go to: Supabase Dashboard > Database > Extensions > Search "pg_net" > Enable
-- Or run this SQL:
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;


-- ============================================================================
-- OPTION B: INSTANT TRIGGER (RECOMMENDED)
-- ============================================================================
-- Notifications are sent within seconds of being queued.
-- Copy and paste this entire block into SQL Editor and run it.
-- ============================================================================

-- Create the trigger function that calls the edge function
CREATE OR REPLACE FUNCTION trigger_process_push_queue()
RETURNS TRIGGER AS $$
BEGIN
    -- Call the edge function asynchronously using pg_net
    -- Using the anon key for authentication
    PERFORM net.http_post(
        url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw'
        ),
        body := '{}'::jsonb
    );
    
    RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- Create the trigger on push_notification_queue table
DROP TRIGGER IF EXISTS on_push_notification_insert ON push_notification_queue;
CREATE TRIGGER on_push_notification_insert
    AFTER INSERT ON push_notification_queue
    FOR EACH ROW
    EXECUTE FUNCTION trigger_process_push_queue();


-- ============================================================================
-- VERIFICATION: Run this to confirm the trigger is set up
-- ============================================================================

SELECT 
    tgname AS trigger_name,
    CASE WHEN tgenabled = 'O' THEN 'ENABLED' ELSE 'DISABLED' END AS status
FROM pg_trigger 
WHERE tgrelid = 'push_notification_queue'::regclass
AND tgname = 'on_push_notification_insert';


-- ============================================================================
-- OPTION A (ALTERNATIVE): CRON JOB - Every minute fallback
-- ============================================================================
-- Only use this if the trigger approach doesn't work for you.
-- This adds up to 60 second delay but is very reliable.
-- 
-- First enable pg_cron: Dashboard > Database > Extensions > pg_cron > Enable
-- Then run:
-- ============================================================================

-- CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;
-- 
-- SELECT cron.schedule(
--     'process-push-notifications',
--     '* * * * *',
--     $$
--     SELECT net.http_post(
--         url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue',
--         headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw"}'::jsonb,
--         body := '{}'::jsonb
--     );
--     $$
-- );
-- 
-- -- Check cron jobs: SELECT * FROM cron.job;
-- -- Delete if needed: SELECT cron.unschedule('process-push-notifications');


-- ============================================================================
-- CLEANUP (if you ever need to remove the trigger)
-- ============================================================================

-- DROP TRIGGER IF EXISTS on_push_notification_insert ON push_notification_queue;
-- DROP FUNCTION IF EXISTS trigger_process_push_queue();

