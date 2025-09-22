-- Test direct SQL insert to notifications table
INSERT INTO notifications (
    user_id,
    type,
    title,
    body,
    data,
    is_delivered,
    delivered_at
) VALUES (
    'd4c8cd57-c182-4eed-a961-b24651061676'::uuid,
    'new_message',
    'Direct SQL Test',
    'Testing direct SQL insert',
    '{}'::jsonb,
    false,
    null
) RETURNING *;
