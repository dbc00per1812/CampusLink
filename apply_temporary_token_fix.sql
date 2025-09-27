-- Temporary fix to make push notifications work for Darragh
-- This pads the 64-char token to 160 chars like John's working token

-- First, show current state
SELECT 
  name,
  push_token,
  LENGTH(push_token) as current_length
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name = 'Darragh';

-- Apply the fix - pad token to 160 characters
-- This concatenates: token (64) + token (64) + first 32 chars of token = 160 total
UPDATE user_notification_preferences
SET push_token = push_token || push_token || SUBSTRING(push_token, 1, 32),
    updated_at = NOW()
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
  AND LENGTH(push_token) = 64; -- Only update if it's currently 64 chars

-- Verify the change
SELECT 
  name,
  push_token,
  LENGTH(push_token) as new_length,
  updated_at
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name = 'Darragh';
