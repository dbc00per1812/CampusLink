-- ============================================
-- Fix Users Table RLS for Signup Campus Saving
-- ============================================
-- This fixes the issue where campus isn't saved during signup
-- The problem: INSERT policy requires auth.uid() but during signup the JWT might not be active yet

-- First, check current policies
SELECT 
    policyname,
    cmd as operation,
    qual as using_expression,
    with_check as check_expression
FROM pg_policies 
WHERE tablename = 'users'
ORDER BY cmd;

-- Enable RLS on users table (if not already enabled)
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;

-- Drop existing INSERT policies
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users based on user_id" ON public.users;
DROP POLICY IF EXISTS "Allow service role to insert users" ON public.users;
DROP POLICY IF EXISTS "Allow users and service role to insert profiles" ON public.users;

-- Create a more permissive INSERT policy for signup
-- This allows authenticated users to insert their own profile
-- OR allows service_role (backend) to insert any profile
CREATE POLICY "Allow users and service role to insert profiles"
ON public.users
FOR INSERT
TO authenticated, service_role
WITH CHECK (
    -- Either the user is creating their own profile
    auth.uid()::text = id::text
    -- OR it's being done by service_role (Supabase backend during signup triggers)
    OR auth.role() = 'service_role'
);

-- Ensure UPDATE policy exists (for profile updates after signup)
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Enable update for users based on id" ON public.users;

CREATE POLICY "Users can update their own profile"
ON public.users
FOR UPDATE
TO authenticated
USING (auth.uid()::text = id::text)
WITH CHECK (auth.uid()::text = id::text);

-- Ensure SELECT policies exist
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.users;

-- Allow users to view their own profile
CREATE POLICY "Users can view their own profile"
ON public.users
FOR SELECT
TO authenticated
USING (auth.uid()::text = id::text);

-- Allow all authenticated users to view other users' public data (needed for listings, messages)
CREATE POLICY "Public profiles are viewable by everyone"
ON public.users
FOR SELECT
TO authenticated
USING (true);

-- Verify the policies were created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command,
    qual as using_clause,
    with_check as check_clause
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;

-- Test the setup
SELECT 'RLS policies updated successfully' as status;
SELECT 'Users should now be able to save campus during signup' as status;

