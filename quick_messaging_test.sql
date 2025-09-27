-- Quick Messaging Test
-- This tests if messages trigger notifications

-- 1. Find a conversation where both users have push tokens
SELECT 
  c.id as conversation_id,
  c.buyer_id,
  c.seller_id,
  b.name as buyer_name,
  s.name as seller_name,
  bpref.push_token IS NOT NULL as buyer_has_token,
  spref.push_token IS NOT NULL as seller_has_token
FROM conversations c
JOIN users b ON b.id = c.buyer_id
JOIN users s ON s.id = c.seller_id
LEFT JOIN user_notification_preferences bpref ON bpref.user_id = c.buyer_id
LEFT JOIN user_notification_preferences spref ON spref.user_id = c.seller_id
WHERE (bpref.push_token IS NOT NULL OR spref.push_token IS NOT NULL)
LIMIT 5;

-- 2. Insert a test message (use IDs from above)
-- This simulates what happens when your app sends a message
INSERT INTO messages (conversation_id, sender_id, content)
VALUES (
  'fa4c2be3-3d26-4777-a8b5-b030d4d7b4af'::uuid,  -- conversation_id
  'd4c8cd57-c182-4eed-a961-b24651061676'::uuid,   -- sender_id (Darragh)
  'Test message at ' || NOW()::text
)
RETURNING id, content, created_at;

-- 3. Check if notification was created
SELECT 
  n.id,
  n.user_id,
  n.title,
  n.body,
  n.is_delivered,
  n.message_id,
  u.name as recipient_name
FROM notifications n
JOIN users u ON u.id = n.user_id
WHERE n.type = 'new_message'
  AND n.created_at > NOW() - INTERVAL '1 minute'
ORDER BY n.created_at DESC;

-- 4. If notifications exist, manually trigger push for them
-- Get the user_id from above and run:
-- curl -X POST "https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-direct" \
--   -H "Authorization: Bearer YOUR_ANON_KEY" \
--   -H "Content-Type: application/json" \
--   -d '{"user_id": "USER_ID_HERE", "title": "TITLE", "body": "BODY", "type": "new_message"}'
