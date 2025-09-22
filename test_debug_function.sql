-- Test the debug function to see detailed logs
SELECT net.http_post(
    url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/debug-send-push',
    headers := jsonb_build_object(
        'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6InNlcnZpY2Vfcm9sZSIsImlhdCI6MTcyNjQ0NzQ0MCwiZXhwIjoyMDQyMDIzNDQwfQ.90F5CZxN5KM0tzAooHeSZUWay3ZQ_6arkew56UaChpw',
        'Content-Type', 'application/json'
    ),
    body := jsonb_build_object(
        'user_id', 'd4c8cd57-c182-4eed-a961-b24651061676',
        'title', 'Debug Test Notification',
        'body', 'This is a debug test notification',
        'type', 'new_message',
        'data', jsonb_build_object(
            'conversation_id', '62cb1511-869f-4d2d-b99e-dd6cb8e3d331',
            'message_id', 'debug-test-message-id',
            'sender_id', 'bff269e7-a282-4006-a53b-e4f6a3f542b0'
        )
    )
);
