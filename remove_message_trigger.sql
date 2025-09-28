-- Remove the message trigger that's breaking message sending

DROP TRIGGER IF EXISTS simple_message_trigger ON messages;
DROP FUNCTION IF EXISTS simple_message_notification() CASCADE;

SELECT 'Message trigger removed - messages should work now' as result;
