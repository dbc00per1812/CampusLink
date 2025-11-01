-- ============================================
-- Fix Users Table RLS Policies for Campus Updates
-- ============================================
-- This script adds RLS policies to allow users to update their own campus field
-- Run this in Supabase SQL Editor

-- First, check what policies currently exist
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

-- Drop existing UPDATE policy if it exists
DROP POLICY IF EXISTS "Users can update their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can update own profile" ON public.users;
DROP POLICY IF EXISTS "Enable update for users based on id" ON public.users;

-- Create UPDATE policy - allow users to update their own profile
CREATE POLICY "Users can update their own profile"
ON public.users
FOR UPDATE
TO authenticated
USING (auth.uid()::text = id::text)
WITH CHECK (auth.uid()::text = id::text);

-- Also ensure users can SELECT (read) their own data
DROP POLICY IF EXISTS "Users can view their own profile" ON public.users;
DROP POLICY IF EXISTS "Users can read own profile" ON public.users;
DROP POLICY IF EXISTS "Enable read access for users based on id" ON public.users;

CREATE POLICY "Users can view their own profile"
ON public.users
FOR SELECT
TO authenticated
USING (auth.uid()::text = id::text);

-- Allow users to view other users' public profile data (needed for listings, messages, etc.)
DROP POLICY IF EXISTS "Users can view other profiles" ON public.users;
DROP POLICY IF EXISTS "Public profiles are viewable by everyone" ON public.users;

CREATE POLICY "Public profiles are viewable by everyone"
ON public.users
FOR SELECT
TO authenticated
USING (true);

-- Allow INSERT during signup (service_role or authenticated users creating their own profile)
DROP POLICY IF EXISTS "Users can insert their own profile" ON public.users;
DROP POLICY IF EXISTS "Enable insert for authenticated users based on user_id" ON public.users;

CREATE POLICY "Users can insert their own profile"
ON public.users
FOR INSERT
TO authenticated
WITH CHECK (auth.uid()::text = id::text);

-- Verify the policies were created
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd as command
FROM pg_policies
WHERE tablename = 'users'
ORDER BY cmd, policyname;

-- Test query to verify you can now update your campus
-- Replace 'your-user-id' with your actual user ID
-- UPDATE users SET campus = 'Purdue University' WHERE id = 'your-user-id';

