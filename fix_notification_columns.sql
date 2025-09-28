-- First, let's see the actual structure of the notifications table
SELECT column_name, data_type, is_nullable
FROM information_schema.columns 
WHERE table_schema = 'public' 
  AND table_name = 'notifications'
ORDER BY ordinal_position;

-- Check recent notifications with correct column names
SELECT 
    id,
    user_id,  -- This is likely the correct column name instead of recipient_id
    notification_type,
    title,
    body,
    data,
    is_read,
    created_at,
    delivered_at,
    push_sent_at
FROM public.notifications 
ORDER BY created_at DESC 
LIMIT 10;
