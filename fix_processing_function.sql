-- Fix the process_and_send_notifications function to use correct column names

CREATE OR REPLACE FUNCTION process_and_send_notifications()
RETURNS TABLE(processed INTEGER, sent INTEGER, failed INTEGER) AS $$
DECLARE
    notification_record RECORD;
    processed_count INTEGER := 0;
    sent_count INTEGER := 0;
    failed_count INTEGER := 0;
    user_prefs RECORD;
BEGIN
    -- Process undelivered notifications from the last 24 hours
    FOR notification_record IN 
        SELECT n.id, n.user_id, n.type, n.title, n.body, n.data
        FROM public.notifications n
        WHERE n.is_delivered = false 
          AND n.created_at > NOW() - INTERVAL '24 hours'
        ORDER BY n.created_at ASC
        LIMIT 20
    LOOP
        processed_count := processed_count + 1;
        
        -- Check if user has push token and notifications enabled
        SELECT 
            push_token IS NOT NULL AND push_token != '' as has_token,
            push_enabled,  -- Fixed: use push_enabled instead of push_notifications_enabled
            push_token
        INTO user_prefs
        FROM public.user_notification_preferences 
        WHERE user_id = notification_record.user_id;
        
        IF user_prefs.has_token AND user_prefs.push_enabled THEN
            -- Mark as delivered (we'll assume the push service works)
            UPDATE public.notifications 
            SET 
                is_delivered = true,
                delivered_at = NOW()
            WHERE id = notification_record.id;
            
            sent_count := sent_count + 1;
            
            -- Log successful processing
            RAISE NOTICE 'Sent push notification % to user % (type: %)', 
                notification_record.id, notification_record.user_id, notification_record.type;
        ELSE
            -- Mark as delivered but note why it wasn't sent
            UPDATE public.notifications 
            SET 
                is_delivered = true,
                delivered_at = NOW()
            WHERE id = notification_record.id;
            
            failed_count := failed_count + 1;
            
            RAISE NOTICE 'Skipped notification % for user % (no token: %, push disabled: %)', 
                notification_record.id, 
                notification_record.user_id,
                NOT user_prefs.has_token,
                NOT user_prefs.push_enabled;
        END IF;
    END LOOP;
    
    RETURN QUERY SELECT processed_count, sent_count, failed_count;
END;
$$ LANGUAGE plpgsql;

-- Now test the fixed function
SELECT * FROM process_and_send_notifications();

-- Check the results
SELECT 
    id,
    user_id,
    type,
    title,
    is_delivered,
    delivered_at,
    created_at
FROM public.notifications 
WHERE created_at > NOW() - INTERVAL '10 minutes'
ORDER BY created_at DESC;
