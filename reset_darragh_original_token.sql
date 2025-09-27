-- Reset Darragh back to his original 64-character token
-- The issue was the Edge Function, not the token format

-- First check current state
SELECT 
  u.name,
  LENGTH(unp.push_token) as current_length,
  SUBSTRING(unp.push_token, 1, 64) as first_64_chars
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name = 'Darragh';

-- Reset to original 64-char token (extract first 64 chars if it's currently 160)
UPDATE user_notification_preferences
SET push_token = 'd6437f23f221477e9955df8edc2da6c7358ef64bb14139fdd023473fbb77ab5c',
    updated_at = NOW()
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676';

-- Verify the update
SELECT 
  u.name,
  LENGTH(unp.push_token) as new_length,
  unp.push_token,
  unp.updated_at
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name = 'Darragh';
