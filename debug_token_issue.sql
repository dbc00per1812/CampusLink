-- Compare the exact tokens to find the pattern
SELECT 
  u.name,
  unp.push_token,
  LENGTH(unp.push_token) as len,
  -- Check if it's the same 64-char pattern repeated
  CASE 
    WHEN LENGTH(unp.push_token) = 160 THEN
      CASE
        WHEN SUBSTRING(unp.push_token, 1, 64) = SUBSTRING(unp.push_token, 65, 64) THEN
          '❌ First 64 = Second 64 (duplicated)'
        ELSE
          '✅ Different segments'
      END
    ELSE 'N/A'
  END as pattern_check,
  -- Extract the first 64 chars (the real token)
  SUBSTRING(unp.push_token, 1, 64) as first_64_chars
FROM users u
JOIN user_notification_preferences unp ON unp.user_id = u.id
WHERE u.name IN ('John', 'Darragh')
ORDER BY u.name;
