-- Test the SQL function with the exact parameters the Edge Function uses
SELECT insert_notification(
    'd4c8cd57-c182-4eed-a961-b24651061676'::uuid,
    'new_message',
    'Edge Function Parameters Test',
    'This is a test with exact Edge Function parameters',
    '{}'::jsonb,
    false,
    NULL
);

-- Check if it was saved
SELECT * FROM notifications 
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
ORDER BY created_at DESC 
LIMIT 3;
