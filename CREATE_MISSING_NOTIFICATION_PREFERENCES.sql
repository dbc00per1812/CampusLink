-- ============================================
-- FIX: Create Missing Notification Preferences
-- ============================================
-- Some users don't have notification preferences records
-- This creates default preferences for them
-- ============================================

-- STEP 1: Check which users are missing preferences
-- ============================================
SELECT 'Users without notification preferences:' as status;
SELECT 
    u.id,
    u.name,
    u.email
FROM users u
WHERE NOT EXISTS (
    SELECT 1 
    FROM user_notification_preferences unp 
    WHERE unp.user_id = u.id
)
LIMIT 10;

-- STEP 2: Create default preferences for ALL users who don't have them
-- ============================================
SELECT 'Creating default notification preferences for missing users...' as status;

INSERT INTO user_notification_preferences (
    user_id,
    push_enabled,
    push_token,
    push_platform,
    order_notifications,
    message_notifications,
    payment_notifications,
    rating_notifications,
    marketplace_notifications,
    quiet_hours_start,
    quiet_hours_end,
    timezone,
    max_daily_notifications,
    group_similar_notifications,
    created_at,
    updated_at
)
SELECT 
    u.id,
    true,                           -- push_enabled (default to true)
    NULL,                           -- push_token (will be set when device registers)
    NULL,                           -- push_platform (will be set when device registers)
    true,                           -- order_notifications
    true,                           -- message_notifications
    true,                           -- payment_notifications
    true,                           -- rating_notifications
    false,                          -- marketplace_notifications
    '22:00:00'::time,              -- quiet_hours_start
    '08:00:00'::time,              -- quiet_hours_end
    'UTC',                          -- timezone
    10,                             -- max_daily_notifications
    true,                           -- group_similar_notifications
    NOW(),                          -- created_at
    NOW()                           -- updated_at
FROM users u
WHERE NOT EXISTS (
    SELECT 1 
    FROM user_notification_preferences unp 
    WHERE unp.user_id = u.id
);

-- STEP 3: Verify the fix
-- ============================================
SELECT 'Verification: Check specific recipient user' as status;
SELECT 
    user_id,
    push_enabled,
    CASE 
        WHEN push_token IS NOT NULL THEN 'Has Token'
        ELSE 'No Token (will be set when device registers)'
    END as token_status,
    created_at
FROM user_notification_preferences
WHERE user_id = 'f74d6ffd-4d86-4596-a19a-500080a42eeb';

-- STEP 4: Check if there are any other users without preferences
-- ============================================
SELECT 'Final check: Any users still missing preferences?' as status;
SELECT COUNT(*) as users_without_preferences
FROM users u
WHERE NOT EXISTS (
    SELECT 1 
    FROM user_notification_preferences unp 
    WHERE unp.user_id = u.id
);

-- Should return 0

-- ============================================
-- WHAT THIS DOES
-- ============================================
-- 1. Creates notification preferences for ALL users who don't have them
-- 2. Sets sensible defaults (notifications enabled, no quiet hours restriction)
-- 3. push_token will be NULL initially - that's OK! 
--    It will be set when the device registers for notifications
-- 4. Once this runs, the push_queue_trigger will work properly
-- ============================================

-- ============================================
-- WHAT TO DO NEXT
-- ============================================
-- After running this:
-- 1. The recipient user will have notification preferences ✅
-- 2. Send another test message
-- 3. The push_queue_trigger will now successfully insert into queue
-- 4. BUT: The device still needs to register its push token
-- 5. Check the app logs for "📱 Received device token"
-- 6. The app should call updatePushToken() on login
-- ============================================

