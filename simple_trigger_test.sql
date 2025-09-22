-- Simple test to see if trigger is working at all
DROP TRIGGER IF EXISTS trigger_notify_new_message ON public.messages;
DROP FUNCTION IF EXISTS notify_new_message() CASCADE;

-- Create the simplest possible trigger
CREATE OR REPLACE FUNCTION notify_new_message()
RETURNS TRIGGER AS $$
BEGIN
    -- Just log that we got here
    RAISE NOTICE 'MESSAGE TRIGGER FIRED! Message ID: %, Content: %', NEW.id, NEW.content;
    
    -- Try to insert a simple notification
    INSERT INTO notifications (
        user_id,
        type,
        title,
        body,
        created_at
    ) VALUES (
        '00000000-0000-0000-0000-000000000000'::uuid,  -- dummy user
        'test',
        'Test Notification',
        'Trigger fired for message: ' || NEW.content,
        NOW()
    );
    
    RETURN NEW;
EXCEPTION
    WHEN OTHERS THEN
        RAISE NOTICE 'TRIGGER ERROR: %', SQLERRM;
        RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create the trigger
CREATE TRIGGER trigger_notify_new_message
    AFTER INSERT ON public.messages
    FOR EACH ROW
    EXECUTE FUNCTION notify_new_message();
