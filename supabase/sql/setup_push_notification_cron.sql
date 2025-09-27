-- Setup Push Notification Cron Job
-- This sets up a scheduled job to process push notifications every minute

-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- First, set the service role key as a configuration parameter
-- This allows the database to use it in HTTP calls
-- Replace YOUR_SERVICE_ROLE_KEY with your actual key when running this
ALTER DATABASE postgres SET "app.settings.service_role_key" = 'YOUR_SERVICE_ROLE_KEY';

-- Create a function to process the queue
CREATE OR REPLACE FUNCTION trigger_push_queue_processor()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Call the edge function to process pending notifications
  PERFORM net.http_post(
    url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
END;
$$;

-- Schedule the job to run every minute
SELECT cron.schedule(
  'process-push-notifications',
  '* * * * *', -- Every minute
  'SELECT trigger_push_queue_processor();'
);

-- To check if the job is scheduled:
-- SELECT * FROM cron.job;

-- To remove the job if needed:
-- SELECT cron.unschedule('process-push-notifications');
