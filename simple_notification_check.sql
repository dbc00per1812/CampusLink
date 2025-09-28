-- Simple check to see the actual notifications table structure and data

-- 1. Get the actual column names
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'notifications'
ORDER BY ordinal_position;

-- 2. Simple select with just basic columns that should exist
SELECT *
FROM public.notifications 
ORDER BY created_at DESC 
LIMIT 5;
