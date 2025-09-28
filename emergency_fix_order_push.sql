-- EMERGENCY FIX: Manually create push queue entries for recent order notifications

-- 1. First, let's manually populate push queue for recent order notifications that didn't get push entries
INSERT INTO push_notification_queue (user_id, notification_type, title, body, data)
SELECT 
  n.user_id,
  'order_placed',
  n.title,
  n.body,
  jsonb_build_object('order_id', n.order_id::text, 'type', 'order_placed')
FROM notifications n
WHERE n.type = 'order_placed' 
  AND n.created_at >= NOW() - INTERVAL '2 hours'
  AND n.user_id = '50b58786-ffe6-4b99-b7d3-a1b12e21c539'
  AND NOT EXISTS (
    SELECT 1 FROM push_notification_queue pq 
    WHERE pq.user_id = n.user_id 
    AND pq.notification_type = 'order_placed'
    AND pq.created_at >= NOW() - INTERVAL '2 hours'
  );

-- 2. Check what we just created
SELECT 'Push queue entries created:' as result;
SELECT notification_type, title, user_id, processed, created_at
FROM push_notification_queue 
WHERE notification_type = 'order_placed'
ORDER BY created_at DESC
LIMIT 5;

SELECT 'Now run the process-notification-queue edge function!' as next_step;
