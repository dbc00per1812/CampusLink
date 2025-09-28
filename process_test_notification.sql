-- Process the test notification we just created

-- 1. Process all pending notifications
SELECT * FROM process_and_send_notifications();

-- 2. Check if our test notification was processed
SELECT 
    id,
    user_id,
    type,
    title,
    body,
    is_delivered,
    delivered_at,
    created_at
FROM public.notifications 
WHERE type = 'order_placed'
  AND body LIKE '%manual test%'
ORDER BY created_at DESC 
LIMIT 1;

-- 3. Check all recent notifications to see the status
SELECT 
    id,
    user_id,
    type,
    title,
    is_delivered,
    delivered_at,
    created_at
FROM public.notifications 
WHERE created_at > NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;
