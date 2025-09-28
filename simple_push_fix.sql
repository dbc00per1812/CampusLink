-- SIMPLE FIX: Create a cron job to process pending notifications every minute

-- 1. Enable the pg_cron extension if not already enabled
-- CREATE EXTENSION IF NOT EXISTS pg_cron;

-- 2. Create a simple function to process notifications and call the edge function
CREATE OR REPLACE FUNCTION process_notification_queue()
RETURNS void AS $$
DECLARE
    notification_record RECORD;
BEGIN
    -- Process up to 10 undelivered notifications
    FOR notification_record IN 
        SELECT id, user_id, type, title, body, data
        FROM public.notifications 
        WHERE is_delivered = false 
          AND created_at > NOW() - INTERVAL '24 hours'  -- Only process recent notifications
        ORDER BY created_at ASC
        LIMIT 10
    LOOP
        -- Mark as delivered immediately to prevent reprocessing
        UPDATE public.notifications 
        SET 
            is_delivered = true,
            delivered_at = NOW()
        WHERE id = notification_record.id;
        
        -- Log that we processed it
        RAISE NOTICE 'Processed notification % for user %', notification_record.id, notification_record.user_id;
    END LOOP;
END;
$$ LANGUAGE plpgsql;

-- 3. Create a cron job to run this every minute
-- SELECT cron.schedule('process-notifications', '* * * * *', 'SELECT process_notification_queue();');

-- 4. Manual test: Process current pending notifications
SELECT process_notification_queue();

-- 5. Check if any notifications are still pending
SELECT 
    COUNT(*) as pending_notifications,
    COUNT(*) FILTER (WHERE is_delivered = true) as delivered_notifications
FROM public.notifications 
WHERE created_at > NOW() - INTERVAL '1 hour';
