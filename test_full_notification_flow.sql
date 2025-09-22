-- Test the full notification flow by calling send-push-direct
SELECT net.http_post(
    url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-direct',
    headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw',
        'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
        'user_id', 'd4c8cd57-c182-4eed-a961-b24651061676',
        'title', 'Full Flow Test',
        'body', 'This is a test of the full notification flow',
        'type', 'new_message'
    )
);

-- Check if notification was saved
SELECT * FROM notifications 
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
ORDER BY created_at DESC 
LIMIT 3;
