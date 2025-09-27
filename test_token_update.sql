-- Test: Try using just the first 64 characters of John's token for Darragh
-- This is just for testing - DO NOT use in production!

-- First, let's backup current tokens
SELECT 
  u.name,
  unp.push_token,
  LENGTH(unp.push_token) as len
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name IN ('Darragh', 'John');

-- Option 1: Try doubling Darragh's token to make it 128 chars
-- UPDATE user_notification_preferences
-- SET push_token = push_token || push_token,
--     updated_at = NOW()
-- WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676';

-- Option 2: Try adding padding to make it 160 chars
-- UPDATE user_notification_preferences  
-- SET push_token = push_token || push_token || SUBSTRING(push_token, 1, 32),
--     updated_at = NOW()
-- WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676';

-- Check other users with working push
SELECT 
  u.name,
  unp.push_enabled,
  LENGTH(unp.push_token) as token_length,
  unp.updated_at,
  n.created_at as last_notification,
  n.is_delivered
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
LEFT JOIN LATERAL (
  SELECT created_at, is_delivered 
  FROM notifications 
  WHERE user_id = u.id 
  ORDER BY created_at DESC 
  LIMIT 1
) n ON true
WHERE unp.push_token IS NOT NULL
ORDER BY token_length DESC;
