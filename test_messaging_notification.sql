-- Test messaging notifications by sending a message from Leo to John
-- This should trigger a push notification to John

-- First, find or create a conversation between Leo and John
WITH conversation AS (
  SELECT id FROM conversations
  WHERE (buyer_id = '599356cc-0f3b-45af-8b36-5e598b5bb44e' AND seller_id = '11cf906c-189d-492f-b9da-bf4bf58c371a')
     OR (seller_id = '599356cc-0f3b-45af-8b36-5e598b5bb44e' AND buyer_id = '11cf906c-189d-492f-b9da-bf4bf58c371a')
  LIMIT 1
)
-- Insert a new message from Leo to John
INSERT INTO messages (
  conversation_id,
  sender_id,
  content,
  created_at
) 
SELECT 
  COALESCE(
    (SELECT id FROM conversation),
    'fa4c2be3-3d26-4777-a8b5-b030d4d7b4af'::uuid  -- Use the test conversation ID if none exists
  ),
  '599356cc-0f3b-45af-8b36-5e598b5bb44e'::uuid,  -- Leo as sender
  'Hey John! Testing if push notifications work for messages. Did you get this? 🔔',
  NOW()
RETURNING *;

-- Check if the notification was created by the trigger
SELECT * FROM notifications
WHERE user_id = '11cf906c-189d-492f-b9da-bf4bf58c371a'
  AND type = 'new_message'
ORDER BY created_at DESC
LIMIT 1;
