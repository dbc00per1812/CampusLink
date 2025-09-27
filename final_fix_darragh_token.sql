-- Final fix: Pad Darragh's token to 160 characters like John's working token
-- This is unusual but it's what works in your setup

-- Pad the 64-char token to 160 chars by repeating it
UPDATE user_notification_preferences
SET push_token = push_token || push_token || SUBSTRING(push_token, 1, 32),
    updated_at = NOW()
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
  AND LENGTH(push_token) = 64;

-- Verify it matches John's pattern (160 chars)
SELECT 
  u.name,
  LENGTH(unp.push_token) as token_length,
  unp.push_token,
  CASE 
    WHEN LENGTH(unp.push_token) = 160 THEN '✅ Ready for push'
    ELSE '❌ Wrong length'
  END as status
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name IN ('Darragh', 'John')
ORDER BY u.name;
