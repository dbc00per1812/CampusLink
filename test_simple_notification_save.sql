-- Test saving a notification directly to the database
-- This will help us see if there are any other constraints

INSERT INTO notifications (
    user_id,
    type,
    title,
    body,
    data,
    is_delivered,
    delivered_at
) VALUES (
    'd4c8cd57-c182-4eed-a961-b24651061676',
    'new_message',
    'Direct Database Test',
    'This is a direct database test notification',
    '{}',
    true,
    NOW()
);

-- Check if it was saved
SELECT * FROM notifications 
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
ORDER BY created_at DESC 
LIMIT 5;
