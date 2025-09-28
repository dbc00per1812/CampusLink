-- Check the actual structure of user_notification_preferences table

-- 1. Get the actual column names
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'user_notification_preferences'
ORDER BY ordinal_position;

-- 2. Simple select to see the data
SELECT *
FROM public.user_notification_preferences 
LIMIT 5;
