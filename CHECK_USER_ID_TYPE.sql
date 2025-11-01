-- ============================================
-- CHECK: Is there a user_id type mismatch?
-- ============================================

-- Check the column type in notifications table
SELECT 
    column_name,
    data_type,
    udt_name
FROM information_schema.columns
WHERE table_name = 'notifications'
AND column_name IN ('user_id', 'related_user_id');

-- Check actual values in recent notifications
SELECT 
    id,
    user_id,
    pg_typeof(user_id) as user_id_type,
    related_user_id,
    pg_typeof(related_user_id) as related_user_id_type,
    type,
    created_at
FROM notifications
WHERE type = 'new_message'
ORDER BY created_at DESC
LIMIT 3;

-- Check what auth.uid() returns
SELECT 
    auth.uid() as current_user_id,
    auth.uid()::text as current_user_id_as_text,
    pg_typeof(auth.uid()) as auth_uid_type;

-- Test if RLS policy would match
-- (Run this while logged in as the test user in your app)
SELECT 
    n.id,
    n.user_id,
    auth.uid() as my_auth_uid,
    (auth.uid()::text = n.user_id::text) as would_rls_match
FROM notifications n
WHERE n.type = 'new_message'
ORDER BY n.created_at DESC
LIMIT 3;


