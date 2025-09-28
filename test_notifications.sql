-- Test notification system to see if it's working

-- 1. Check if create_notification function exists
SELECT proname, pg_get_functiondef(oid) 
FROM pg_proc 
WHERE proname = 'create_notification';

-- 2. Check if the trigger is properly attached
SELECT 
    tgname AS trigger_name,
    tgenabled AS enabled,
    pg_get_triggerdef(oid) AS definition
FROM pg_trigger 
WHERE tgrelid = 'public.orders'::regclass;

-- 3. Check recent notifications table
SELECT * FROM public.notifications 
ORDER BY created_at DESC 
LIMIT 10;

-- 4. Test the create_notification function directly
-- Replace with actual user IDs from your system
SELECT create_notification(
    '00000000-0000-0000-0000-000000000001'::uuid,  -- recipient_id (replace with real user ID)
    'test_notification',
    'Test Title',
    'Test message to verify notifications work',
    jsonb_build_object('test_key', 'test_value'),
    null,  -- order_id
    null,  -- listing_id  
    null,  -- related_listing_id
    null   -- sender_id
);

-- 5. Check if the test notification was created
SELECT * FROM public.notifications 
WHERE notification_type = 'test_notification'
ORDER BY created_at DESC 
LIMIT 1;
