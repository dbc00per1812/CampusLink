-- ============================================
-- FIX: Allow users to read their own notifications
-- ============================================
-- Notifications are being created but app can't read them
-- This is an RLS (Row Level Security) issue
-- ============================================

-- Check current RLS policies
SELECT 
    policyname,
    cmd as operation,
    qual as using_expression,
    with_check as check_expression
FROM pg_policies 
WHERE tablename = 'notifications'
ORDER BY cmd;

-- Drop any overly restrictive policies
DROP POLICY IF EXISTS "Users can only read their own notifications" ON notifications;
DROP POLICY IF EXISTS "Users can view their own notifications" ON notifications;
DROP POLICY IF EXISTS "Enable read access for users based on user_id" ON notifications;

-- Create proper SELECT policy - allow users to read their own notifications
CREATE POLICY "Users can read their own notifications"
ON notifications
FOR SELECT
TO authenticated
USING (auth.uid()::text = user_id::text);

-- Also ensure users can insert (though triggers handle this)
DROP POLICY IF EXISTS "Users can create notifications" ON notifications;

CREATE POLICY "Allow all inserts for notifications"
ON notifications
FOR INSERT
TO authenticated
WITH CHECK (true);

-- Verify policies
SELECT 
    policyname,
    cmd as operation
FROM pg_policies 
WHERE tablename = 'notifications'
ORDER BY cmd;

-- Should show:
-- SELECT policy for reading own notifications
-- INSERT policy for creating notifications


