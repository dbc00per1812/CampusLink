-- DISABLE THE FAILING SIGNUP TRIGGER
-- The trigger is causing auth.signUp to fail with 500 error
-- We'll rely on manual profile creation in the app instead

-- 1. Remove the failing trigger completely
DROP TRIGGER IF EXISTS create_profile_on_signup ON auth.users;

-- 2. Remove the function as well (optional, but clean)
DROP FUNCTION IF EXISTS create_user_profile_on_signup();

-- 3. Also remove any other user-related triggers that might be interfering
DROP TRIGGER IF EXISTS trigger_create_user_preferences ON auth.users;

-- 4. Success message
SELECT 'Signup trigger disabled! App will now handle profile creation manually.' as status;
