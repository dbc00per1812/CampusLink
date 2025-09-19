-- Quick test to verify messaging setup in database
-- Run this in Supabase SQL Editor to check current state

-- 1. Check if send_message function exists
SELECT 
    routine_name, 
    routine_type,
    specific_name
FROM information_schema.routines 
WHERE routine_schema = 'public' 
    AND routine_name = 'send_message';

-- 2. Check RLS status on messages table
SELECT 
    schemaname, 
    tablename, 
    rowsecurity as rls_enabled
FROM pg_tables 
WHERE schemaname = 'public' 
    AND tablename = 'messages';

-- 3. Check existing RLS policies on messages
SELECT 
    schemaname,
    tablename,
    policyname,
    permissive,
    roles,
    cmd,
    qual,
    with_check
FROM pg_policies 
WHERE schemaname = 'public' 
    AND tablename = 'messages';

-- 4. Check if read_at column exists
SELECT column_name, data_type 
FROM information_schema.columns 
WHERE table_schema = 'public' 
    AND table_name = 'messages' 
    AND column_name = 'read_at';

-- 5. Test basic conversation query (replace with actual conversation ID)
-- SELECT id, buyer_id, seller_id FROM public.conversations LIMIT 1;
