-- Check Darragh's push token details
SELECT 
  u.id,
  u.name,
  unp.push_enabled,
  unp.push_token,
  LENGTH(unp.push_token) as token_length,
  unp.push_platform,
  unp.created_at,
  unp.updated_at,
  NOW() - unp.updated_at as time_since_update,
  CASE 
    WHEN unp.updated_at > NOW() - INTERVAL '5 minutes' THEN '✅ Just updated!'
    WHEN unp.updated_at > NOW() - INTERVAL '1 hour' THEN '⚠️ Updated recently'
    WHEN unp.updated_at > NOW() - INTERVAL '1 day' THEN '⚠️ Updated today'
    ELSE '❌ Old token - needs refresh'
  END as token_freshness
FROM users u
LEFT JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.id = 'd4c8cd57-c182-4eed-a961-b24651061676';

-- Also check if there are any recent token updates in the last few minutes
SELECT 
  user_id,
  push_token,
  updated_at,
  NOW() - updated_at as time_ago
FROM user_notification_preferences
WHERE updated_at > NOW() - INTERVAL '10 minutes'
ORDER BY updated_at DESC;
