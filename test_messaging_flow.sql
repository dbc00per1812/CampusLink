-- Test Messaging Flow SQL
-- Run this in Supabase SQL Editor to test the complete flow

-- 1. First check if the trigger and functions exist
SELECT * FROM get_messaging_notification_status();

-- 2. Send a test message (this should trigger the notification)
SELECT test_complete_messaging_flow(
  'fa4c2be3-3d26-4777-a8b5-b030d4d7b4af'::uuid,  -- conversation_id
  'd4c8cd57-c182-4eed-a961-b24651061676'::uuid,   -- sender_id (Darragh)
  'Test message - should create notification for Leo!'
);

-- 3. Check if notification was created
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  is_delivered,
  created_at,
  message_id
FROM notifications 
WHERE type = 'new_message'
ORDER BY created_at DESC 
LIMIT 5;

-- 4. Check the trigger debug log
SELECT * FROM trigger_debug_log 
ORDER BY created_at DESC 
LIMIT 5;

-- 5. Check pending push notifications
SELECT * FROM pending_push_notifications;

-- 6. If pending_push_notifications view doesn't exist, let's check manually
SELECT 
  n.id as notification_id,
  n.user_id,
  n.type,
  n.title,
  n.body,
  n.data,
  n.created_at,
  unp.push_token,
  unp.push_enabled
FROM notifications n
JOIN user_notification_preferences unp ON unp.user_id = n.user_id
WHERE n.is_delivered = false
  AND n.type = 'new_message'
  AND unp.push_enabled = true
  AND unp.push_token IS NOT NULL
  AND n.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY n.created_at ASC;

-- 7. Get Leo's user ID to check his notifications
SELECT 
  n.*,
  u.name as recipient_name
FROM notifications n
JOIN users u ON u.id = n.user_id
WHERE n.type = 'new_message'
  AND u.name = 'Leo'
ORDER BY n.created_at DESC
LIMIT 5;

-- 8. Manually send push for testing (get notification_id from above)
-- Then you can test with:
-- curl -X POST "https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-direct" \
--   -H "Authorization: Bearer YOUR_ANON_KEY" \
--   -H "Content-Type: application/json" \
--   -d '{
--     "user_id": "599356cc-0f3b-45af-8b36-5e598b5bb44e",
--     "title": "Darragh",
--     "body": "Test message - should create notification for Leo!",
--     "type": "new_message"
--   }'
