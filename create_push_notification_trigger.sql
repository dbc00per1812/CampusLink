-- Create a trigger to automatically send push notifications when notifications are inserted

-- 1. Create a function to send push notifications via Edge Function
CREATE OR REPLACE FUNCTION send_push_notification_on_insert()
RETURNS TRIGGER AS $$
BEGIN
    -- Call the process-push-queue edge function to handle the new notification
    -- This will be done asynchronously via HTTP request
    PERFORM net.http_post(
        url := current_setting('app.supabase_url') || '/functions/v1/process-push-queue',
        headers := jsonb_build_object(
            'Authorization', 'Bearer ' || current_setting('app.supabase_service_role_key'),
            'Content-Type', 'application/json'
        ),
        body := jsonb_build_object(
            'notification_id', NEW.id,
            'user_id', NEW.user_id,
            'type', NEW.type,
            'title', NEW.title,
            'body', NEW.body,
            'data', NEW.data
        )
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Log the error but don't fail the notification insert
        RAISE WARNING 'Failed to trigger push notification: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- 2. Create the trigger on notifications table
DROP TRIGGER IF EXISTS send_push_on_notification_insert ON public.notifications;
CREATE TRIGGER send_push_on_notification_insert
    AFTER INSERT ON public.notifications
    FOR EACH ROW
    EXECUTE FUNCTION send_push_notification_on_insert();

-- 3. Alternative simpler approach: Create a function that can be called manually
-- This bypasses the HTTP trigger complexity
CREATE OR REPLACE FUNCTION process_pending_notifications()
RETURNS TABLE(processed_count INTEGER, success_count INTEGER) AS $$
DECLARE
    notification_record RECORD;
    processed INTEGER := 0;
    successful INTEGER := 0;
    push_result JSONB;
BEGIN
    -- Get all undelivered notifications from the last hour
    FOR notification_record IN 
        SELECT id, user_id, type, title, body, data
        FROM public.notifications 
        WHERE is_delivered = false 
          AND created_at > NOW() - INTERVAL '1 hour'
        ORDER BY created_at ASC
        LIMIT 50
    LOOP
        processed := processed + 1;
        
        -- Here you would call your push notification service
        -- For now, just mark as delivered (you can integrate with your Edge Function later)
        UPDATE public.notifications 
        SET 
            is_delivered = true,
            delivered_at = NOW()
        WHERE id = notification_record.id;
        
        successful := successful + 1;
    END LOOP;
    
    RETURN QUERY SELECT processed, successful;
END;
$$ LANGUAGE plpgsql;

-- Grant execute permission
GRANT EXECUTE ON FUNCTION process_pending_notifications() TO authenticated;
GRANT EXECUTE ON FUNCTION send_push_notification_on_insert() TO authenticated;
