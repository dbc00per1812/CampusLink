-- Verify Darragh's token was updated
SELECT 
  u.name,
  LENGTH(unp.push_token) as token_length,
  SUBSTRING(unp.push_token, 1, 20) || '...' as token_start,
  CASE 
    WHEN LENGTH(unp.push_token) = 160 THEN '✅ Token padded successfully'
    WHEN LENGTH(unp.push_token) = 64 THEN '❌ Token not updated'
    ELSE '❓ Unexpected length'
  END as status,
  unp.updated_at,
  NOW() - unp.updated_at as time_since_update
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.id = 'd4c8cd57-c182-4eed-a961-b24651061676';
