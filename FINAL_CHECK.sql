-- ============================================
-- FINAL CHECK: Is everything set up correctly?
-- ============================================

-- 1. Check trigger exists
SELECT 'TRIGGER CHECK:' as check;
SELECT trigger_name, event_object_table
FROM information_schema.triggers
WHERE trigger_name = 'message_notification_trigger';
-- Should show 1 row

-- 2. Check RLS policies allow reading
SELECT 'RLS POLICY CHECK:' as check;
SELECT policyname, cmd
FROM pg_policies 
WHERE tablename = 'notifications'
AND cmd = 'SELECT';
-- Should show policies for SELECT

-- 3. Check recent notifications exist
SELECT 'RECENT NOTIFICATIONS:' as check;
SELECT 
    n.id,
    n.type,
    LEFT(n.body, 50) as preview,
    n.created_at,
    n.user_id as recipient_id,
    u.email as recipient_email,
    u.name as recipient_name
FROM notifications n
LEFT JOIN users u ON n.user_id = u.id
WHERE n.type = 'new_message'
AND n.created_at > NOW() - INTERVAL '1 hour'
ORDER BY n.created_at DESC
LIMIT 5;
-- Should show recent notifications

-- 4. Get user ID you're testing with
SELECT 'YOUR USER INFO:' as check;
SELECT id, email, name
FROM users
WHERE email LIKE '%darragh%' OR email LIKE '%buckley%'
LIMIT 3;

-- Tell me:
-- 1. Do you see notifications in result 3?
-- 2. What email/ID shows in result 4?
-- 3. Are you logged into the app with that email?


