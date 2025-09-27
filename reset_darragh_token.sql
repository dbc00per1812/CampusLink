-- Reset Darragh's token back to the original 64 chars
-- The Edge Function now handles extraction, so we can use the real token

UPDATE user_notification_preferences
SET push_token = SUBSTRING(push_token, 1, 64),
    updated_at = NOW()
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
  AND LENGTH(push_token) = 160;

-- Verify the change
SELECT 
  u.name,
  LENGTH(unp.push_token) as token_length,
  unp.push_token,
  unp.updated_at
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name = 'Darragh';
