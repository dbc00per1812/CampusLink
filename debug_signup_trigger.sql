-- Debug signup trigger to see what's actually happening during signup
-- Run this to investigate why signup is still failing

-- 1. Check if the trigger exists and is enabled
SELECT 
  trigger_name,
  event_manipulation,
  event_object_table,
  action_timing,
  action_statement
FROM information_schema.triggers 
WHERE trigger_name = 'create_profile_on_signup';

-- 2. Check if the function exists
SELECT 
  proname as function_name,
  prosrc as function_body
FROM pg_proc 
WHERE proname = 'create_user_profile_on_signup';

-- 3. Check RLS policies on public.users table that might be blocking inserts
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
WHERE tablename = 'users' AND schemaname = 'public';

-- 4. Check if public.users table allows inserts from service_role
SELECT 
  table_schema,
  table_name,
  privilege_type,
  grantee
FROM information_schema.table_privileges 
WHERE table_name = 'users' AND table_schema = 'public';

-- 5. Test creating a user manually to see what fails
-- (This will fail if user doesn't exist, but shows us the exact error)
DO $$
DECLARE
  test_user_id uuid := gen_random_uuid();
  test_email text := 'test@example.edu';
  test_name text := 'Test User';
BEGIN
  BEGIN
    INSERT INTO public.users (id, email, name, created_at, campus_email_verified)
    VALUES (
      test_user_id,
      test_email,
      test_name,
      now(),
      true
    );
    RAISE NOTICE 'SUCCESS: Manual user insert worked';
    
    -- Clean up test data
    DELETE FROM public.users WHERE id = test_user_id;
    
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR inserting into public.users: %', SQLERRM;
  END;
END $$;

-- 6. Check if notification preferences table allows inserts
DO $$
DECLARE
  test_user_id uuid := gen_random_uuid();
BEGIN
  BEGIN
    INSERT INTO user_notification_preferences (user_id)
    VALUES (test_user_id);
    RAISE NOTICE 'SUCCESS: Manual notification preferences insert worked';
    
    -- Clean up test data
    DELETE FROM user_notification_preferences WHERE user_id = test_user_id;
    
  EXCEPTION WHEN OTHERS THEN
    RAISE NOTICE 'ERROR inserting into user_notification_preferences: %', SQLERRM;
  END;
END $$;
