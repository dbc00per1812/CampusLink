-- Fix the RLS policy issue that's blocking signup - CORRECTED VERSION
-- Drop trigger first, then function, then recreate both

-- 1. Drop the trigger first (this allows us to drop the function)
DROP TRIGGER IF EXISTS create_profile_on_signup ON auth.users;

-- 2. Now we can drop the function
DROP FUNCTION IF EXISTS create_user_profile_on_signup();

-- 3. Create the corrected function with SECURITY DEFINER
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
$$ LANGUAGE plpgsql SECURITY DEFINER; -- This bypasses RLS!

-- 4. Recreate the trigger
CREATE TRIGGER create_profile_on_signup
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile_on_signup();

-- 5. Add backup policies for service role (just in case)
CREATE POLICY "Allow service role to create user profiles during signup" ON public.users
  FOR INSERT 
  TO postgres, service_role
  WITH CHECK (true);

CREATE POLICY "Allow service role to create notification preferences" ON public.user_notification_preferences
  FOR INSERT 
  TO postgres, service_role  
  WITH CHECK (true);

SELECT 'RLS policies fixed! Signup should work now.' as status;
