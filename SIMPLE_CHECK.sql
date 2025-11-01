-- Just check if notifications were processed
SELECT 
    COUNT(*) as total,
    COUNT(*) FILTER (WHERE processed = true) as processed,
    COUNT(*) FILTER (WHERE processed = false) as still_waiting
FROM push_notification_queue;

-- Show recent ones
SELECT 
    notification_type,
    LEFT(title, 30) as title,
    processed,
    processed_at,
    error,
    created_at
FROM push_notification_queue
ORDER BY created_at DESC
LIMIT 10;


