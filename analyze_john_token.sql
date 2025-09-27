-- Analyze John's token structure
SELECT 
  name,
  push_token,
  LENGTH(push_token) as total_length,
  SUBSTRING(push_token, 1, 64) as first_64_chars,
  SUBSTRING(push_token, 65, 64) as second_64_chars,
  SUBSTRING(push_token, 129, 32) as remaining_chars,
  CASE 
    WHEN LENGTH(push_token) = 64 THEN 'Standard token'
    WHEN LENGTH(push_token) = 128 THEN 'Possibly doubled token'
    WHEN LENGTH(push_token) = 160 THEN 'Extended token (160 chars)'
    ELSE 'Unusual length'
  END as token_type
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name = 'John';
