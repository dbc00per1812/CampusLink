-- Test the fixed send-push-direct function
SELECT net.http_post(
    url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-direct',
    headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw',
        'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
        'user_id', 'd4c8cd57-c182-4eed-a961-b24651061676',
        'title', 'Fixed Function Test',
        'body', 'This should now save to database even if APNs fails',
        'type', 'new_message'
    )
);
