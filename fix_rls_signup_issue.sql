-- Fix the RLS policy issue that's blocking signup
-- The trigger can't insert because RLS requires auth.uid() but trigger runs without session

-- Problem: The trigger runs when auth.users record is created, but there's no session yet
-- so auth.uid() is NULL, which blocks the RLS policy from allowing the insert

-- Solution: Make the trigger function run with SECURITY DEFINER to bypass RLS
-- Or create a special policy that allows the trigger to work

-- 1. First, let's see what's actually failing by temporarily disabling RLS
ALTER TABLE public.users DISABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notification_preferences DISABLE ROW LEVEL SECURITY;

-- 2. Test signup now - it should work with RLS disabled
-- (We'll re-enable it after we fix the policy)

-- 3. If signup works with RLS disabled, then the issue is RLS blocking the trigger
-- We need a policy that allows the trigger (running as postgres/service role) to insert

-- Re-enable RLS
ALTER TABLE public.users ENABLE ROW LEVEL SECURITY;
ALTER TABLE public.user_notification_preferences ENABLE ROW LEVEL SECURITY;

-- 4. Create a policy that allows service role to insert during signup
CREATE POLICY "Allow service role to create user profiles during signup" ON public.users
  FOR INSERT 
  TO postgres, service_role
  WITH CHECK (true);

CREATE POLICY "Allow service role to create notification preferences" ON public.user_notification_preferences
  FOR INSERT 
  TO postgres, service_role  
  WITH CHECK (true);

-- 5. Alternative: Modify the trigger function to use SECURITY DEFINER
-- This makes the function run with the privileges of the function owner (postgres)
DROP FUNCTION IF EXISTS create_user_profile_on_signup();

CREATE OR REPLACE FUNCTION create_user_profile_on_signup()
RETURNS TRIGGER AS $$
DECLARE
  user_email text;
  user_name text;
BEGIN
  -- Get user email and name from auth metadata
  user_email := NEW.email;
  user_name := COALESCE((NEW.raw_user_meta_data->>'name')::text, 'User');

  -- Create user profile in public.users
  INSERT INTO public.users (id, email, name, created_at, campus_email_verified)
  VALUES (
    NEW.id,
    user_email,
    user_name,
    now(),
    CASE WHEN user_email LIKE '%.edu' THEN true ELSE false END
  )
  ON CONFLICT (id) DO NOTHING;
  
  -- Create user notification preferences
  INSERT INTO user_notification_preferences (user_id)
  VALUES (NEW.id)
  ON CONFLICT (user_id) DO NOTHING;

  RETURN NEW;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER; -- This is the key change!

-- 6. Recreate the trigger
DROP TRIGGER IF EXISTS create_profile_on_signup ON auth.users;
CREATE TRIGGER create_profile_on_signup
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile_on_signup();

SELECT 'RLS policies fixed! Signup should work now.' as status;
