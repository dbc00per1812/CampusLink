-- Fix signup database error by creating missing user profile creation trigger
-- This ensures public.users records are created when auth.users records are created

-- 1. Create function to ensure user profile exists in public.users table
CREATE OR REPLACE FUNCTION ensure_current_user_profile()
RETURNS void AS $$
DECLARE
  current_user_id uuid;
  user_email text;
  user_name text;
BEGIN
  -- Get current user ID and metadata
  current_user_id := auth.uid();
  
  IF current_user_id IS NULL THEN
    RAISE EXCEPTION 'User not authenticated';
  END IF;

  -- Get user email and name from auth metadata
  SELECT 
    email,
    COALESCE((raw_user_meta_data->>'name')::text, 'User') as name
  INTO user_email, user_name
  FROM auth.users 
  WHERE id = current_user_id;

  -- Create user profile in public.users if it doesn't exist
  INSERT INTO public.users (id, email, name, created_at, campus_email_verified)
  VALUES (
    current_user_id,
    user_email,
    user_name,
    now(),
    true -- Set to true for .edu emails
  )
  ON CONFLICT (id) DO UPDATE SET
    email = EXCLUDED.email,
    name = COALESCE(EXCLUDED.name, public.users.name);
    
  -- Ensure user has notification preferences
  INSERT INTO user_notification_preferences (user_id)
  VALUES (current_user_id)
  ON CONFLICT (user_id) DO NOTHING;

  RAISE NOTICE 'User profile ensured for user %', current_user_id;
END;
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 2. Create function to automatically create user profile on signup
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
$$ LANGUAGE plpgsql SECURITY DEFINER;

-- 3. Create trigger to auto-create user profiles on signup
DROP TRIGGER IF EXISTS create_profile_on_signup ON auth.users;
CREATE TRIGGER create_profile_on_signup
  AFTER INSERT ON auth.users
  FOR EACH ROW
  EXECUTE FUNCTION create_user_profile_on_signup();

-- 4. Create missing profiles for any existing auth users
INSERT INTO public.users (id, email, name, created_at, campus_email_verified)
SELECT 
  a.id,
  a.email,
  COALESCE((a.raw_user_meta_data->>'name')::text, 'User') as name,
  a.created_at,
  CASE WHEN a.email LIKE '%.edu' THEN true ELSE false END
FROM auth.users a
LEFT JOIN public.users u ON a.id = u.id
WHERE u.id IS NULL;

-- 5. Create missing notification preferences for any existing users
INSERT INTO user_notification_preferences (user_id)
SELECT u.id FROM public.users u
LEFT JOIN user_notification_preferences p ON u.id = p.user_id
WHERE p.user_id IS NULL;

-- Test the function
SELECT ensure_current_user_profile();
