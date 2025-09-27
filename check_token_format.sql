-- Check exact token format for both users
SELECT 
  u.name,
  unp.push_token,
  LENGTH(unp.push_token) as token_length,
  CASE 
    WHEN unp.push_token ~ '^[a-f0-9]+$' THEN '✅ Valid hex format'
    WHEN unp.push_token ~ '^[A-F0-9]+$' THEN '⚠️ Uppercase hex'
    WHEN unp.push_token ~ ' ' THEN '❌ Contains spaces'
    ELSE '❓ Unknown format'
  END as token_format,
  unp.updated_at,
  NOW() - unp.updated_at as age
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE unp.push_token IS NOT NULL
ORDER BY unp.updated_at DESC;
