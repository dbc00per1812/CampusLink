-- Check recent push notification attempts for Darragh
-- This will help us understand why the push failed

-- 1. Check recent notifications for Darragh
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  is_delivered,
  delivered_at,
  created_at,
  data
FROM notifications 
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
  AND type = 'new_message'
ORDER BY created_at DESC 
LIMIT 5;

-- 2. Check notification logs if they exist
SELECT * FROM notification_logs 
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
ORDER BY created_at DESC 
LIMIT 5;

-- 3. Check Darragh's push token details
SELECT 
  u.id,
  u.name,
  unp.push_enabled,
  unp.push_token,
  unp.push_platform,
  unp.created_at as token_created,
  unp.updated_at as token_updated,
  CASE 
    WHEN unp.updated_at < NOW() - INTERVAL '7 days' THEN 'Token might be stale'
    ELSE 'Token is recent'
  END as token_status
FROM users u
LEFT JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.id = 'd4c8cd57-c182-4eed-a961-b24651061676';
