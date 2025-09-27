-- Check Darragh's latest token and notification status
SELECT 
  u.id,
  u.name,
  unp.push_enabled,
  unp.push_token IS NOT NULL as has_token,
  LENGTH(unp.push_token) as token_length,
  SUBSTRING(unp.push_token, 1, 20) || '...' as token_preview,
  unp.push_platform,
  unp.created_at,
  unp.updated_at,
  NOW() - unp.updated_at as time_since_update,
  CASE 
    WHEN unp.updated_at > NOW() - INTERVAL '5 minutes' THEN '✅ Just updated!'
    WHEN unp.updated_at > NOW() - INTERVAL '1 hour' THEN '⚠️ Updated recently'
    ELSE '❌ Old token'
  END as token_status
FROM users u
LEFT JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.id = 'd4c8cd57-c182-4eed-a961-b24651061676';

-- Check latest notification attempts for Darragh
SELECT 
  id,
  type,
  title,
  body,
  data,
  is_delivered,
  delivered_at,
  created_at,
  NOW() - created_at as time_ago
FROM notifications
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676'
ORDER BY created_at DESC
LIMIT 5;
