-- Simple messaging notification trigger
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER 
SECURITY DEFINER
AS $$
DECLARE
    recipient_id uuid;
    sender_name text;
    conversation_data record;
    has_push_token boolean;
BEGIN
    -- Get conversation data
    SELECT * INTO conversation_data
    FROM conversations
    WHERE id = NEW.conversation_id;
    
    -- Determine recipient
    IF NEW.sender_id = conversation_data.buyer_id THEN
        recipient_id := conversation_data.seller_id;
    ELSE
        recipient_id := conversation_data.buyer_id;
    END IF;
    
    -- Get sender name
    SELECT name INTO sender_name
    FROM users
    WHERE id = NEW.sender_id;
    
    -- Check if recipient has push token
    SELECT push_token IS NOT NULL AND push_enabled = true INTO has_push_token
    FROM user_notification_preferences
    WHERE user_id = recipient_id;
    
    -- Only send push notification if user has token and notifications enabled
    IF has_push_token THEN
        -- Call the same push function that works in your test view
        PERFORM net.http_post(
            url := current_setting('app.settings.supabase_url') || '/functions/v1/send-push-direct',
            headers := jsonb_build_object(
                'Authorization', 'Bearer ' || current_setting('app.settings.supabase_service_role_key'),
                'Content-Type', 'application/json'
            ),
            body := jsonb_build_object(
                'user_id', recipient_id,
                'title', 'New Message',
                'body', COALESCE(sender_name, 'Someone') || ': ' || LEFT(NEW.content, 50),
                'type', 'new_message',
                'data', jsonb_build_object(
                    'conversation_id', NEW.conversation_id,
                    'message_id', NEW.id,
                    'sender_id', NEW.sender_id
                )
            )
        );
    END IF;
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        -- Just return NEW to not break messaging
        RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_notify_new_message
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();
