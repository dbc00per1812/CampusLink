-- Check if recipient has push token registered
-- This will tell us if the recipient device has registered for notifications

SELECT 
    user_id,
    push_enabled,
    CASE 
        WHEN push_token IS NOT NULL THEN 'Has Token (' || LEFT(push_token, 30) || '...)'
        ELSE 'No Token ❌'
    END as token_status,
    push_platform,
    updated_at
FROM user_notification_preferences
WHERE user_id = 'f74d6ffd-4d86-4596-a19a-500080a42eeb';

-- Also check if this user even has a preferences record
SELECT 
    'User exists in users table?' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM users WHERE id = 'f74d6ffd-4d86-4596-a19a-500080a42eeb') 
        THEN 'Yes ✅'
        ELSE 'No ❌'
    END as result;

SELECT 
    'User has notification preferences record?' as check_type,
    CASE 
        WHEN EXISTS (SELECT 1 FROM user_notification_preferences WHERE user_id = 'f74d6ffd-4d86-4596-a19a-500080a42eeb') 
        THEN 'Yes ✅'
        ELSE 'No ❌ - Need to create default preferences'
    END as result;

