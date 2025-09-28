-- Remove all notification triggers that might be blocking order creation

-- Remove order triggers
DROP TRIGGER IF EXISTS simple_order_trigger ON orders;
DROP FUNCTION IF EXISTS simple_order_notification();

-- Remove message triggers  
DROP TRIGGER IF EXISTS simple_message_trigger ON messages;
DROP FUNCTION IF EXISTS simple_message_notification();

-- Remove any other triggers that might exist
DROP TRIGGER IF EXISTS order_notification_trigger ON orders;
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;
DROP TRIGGER IF EXISTS notify_order_placed ON orders;
DROP TRIGGER IF EXISTS notify_message_sent ON messages;

-- Remove notification functions
DROP FUNCTION IF EXISTS notify_order_placed();
DROP FUNCTION IF EXISTS notify_message_sent();
DROP FUNCTION IF EXISTS create_order_notification();
DROP FUNCTION IF EXISTS create_message_notification();

SELECT 'All notification triggers removed' as result;
