-- Enable the http extension for cron to call edge functions
CREATE EXTENSION IF NOT EXISTS http WITH SCHEMA extensions;

-- Try the cron again (unschedule and reschedule)
SELECT cron.unschedule('process-push-notifications');

SELECT cron.schedule(
    'process-push-notifications',
    '* * * * *',
    $$
    SELECT
      extensions.http_post(
          url:='https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue',
          headers:='{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTc1MzU2OTkxOSwiZXhwIjoyMDY5MTQ1OTE5fQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw"}'::jsonb,
          body:='{}'::jsonb
      );
    $$
);


