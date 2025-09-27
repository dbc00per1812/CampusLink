-- Simple Cron Setup for Push Notifications
-- This approach doesn't require storing service role key in the database

-- Enable pg_cron extension if not already enabled
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a simple function that just marks notifications as ready for processing
CREATE OR REPLACE FUNCTION mark_notifications_ready()
RETURNS void
LANGUAGE plpgsql
AS $$
BEGIN
  -- Simply update a timestamp or status to indicate readiness
  -- The edge function will handle the actual processing
  UPDATE notifications
  SET updated_at = NOW()
  WHERE type = 'new_message'
    AND is_delivered = false
    AND created_at > NOW() - INTERVAL '5 minutes';
END;
$$;

-- Schedule a simple job that runs every minute
SELECT cron.schedule(
  'mark-notifications-ready',
  '* * * * *', -- Every minute
  'SELECT mark_notifications_ready();'
);

-- To check if the job is scheduled:
-- SELECT * FROM cron.job;

-- To remove the job if needed:
-- SELECT cron.unschedule('mark-notifications-ready');
