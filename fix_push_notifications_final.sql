-- Let's check the exact token patterns
SELECT 
  u.name,
  LENGTH(unp.push_token) as len,
  -- First 64 chars
  SUBSTRING(unp.push_token, 1, 64) as segment1,
  -- Check if John's token has a specific pattern
  CASE 
    WHEN u.name = 'John' AND LENGTH(unp.push_token) = 160 THEN
      SUBSTRING(unp.push_token, 1, 160)
    ELSE NULL
  END as johns_full_token
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name IN ('John', 'Darragh');

-- Reset Darragh's token to match John's pattern exactly
-- First, let's see what makes John's token special
UPDATE user_notification_preferences
SET push_token = (
  SELECT push_token 
  FROM user_notification_preferences unp2
  JOIN users u2 ON u2.id = unp2.user_id
  WHERE u2.name = 'John'
),
updated_at = NOW()
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676';

-- Verify the update
SELECT 
  u.name,
  LENGTH(unp.push_token) as token_length,
  unp.push_token = (SELECT push_token FROM user_notification_preferences unp2 JOIN users u2 ON u2.id = unp2.user_id WHERE u2.name = 'John') as matches_john
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name = 'Darragh';
