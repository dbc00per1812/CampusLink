-- Check current token status for all users
SELECT 
  u.id,
  u.name,
  LENGTH(unp.push_token) as token_length,
  SUBSTRING(unp.push_token, 1, 20) || '...' as token_preview,
  unp.updated_at,
  NOW() - unp.updated_at as time_since_update
FROM users u
LEFT JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE unp.push_token IS NOT NULL
ORDER BY token_length DESC, u.name;
