-- EMERGENCY: Remove ALL notification triggers that are breaking things

-- Remove all notification triggers
DROP TRIGGER IF EXISTS order_notification_trigger ON orders;
DROP TRIGGER IF EXISTS order_notification_trigger_working ON orders;
DROP TRIGGER IF EXISTS trigger_order_placed_notification ON orders;
DROP TRIGGER IF EXISTS trigger_order_status_notification ON orders;
DROP TRIGGER IF EXISTS offer_notification_trigger ON offers;
DROP TRIGGER IF EXISTS payment_notification_trigger ON payments;
DROP TRIGGER IF EXISTS rating_notification_trigger ON ratings;
DROP TRIGGER IF EXISTS conversation_notification_trigger ON conversations;
DROP TRIGGER IF EXISTS message_notification_trigger ON messages;
DROP TRIGGER IF EXISTS message_notification_trigger_safe ON messages;
DROP TRIGGER IF EXISTS notify_on_message_trigger ON messages;

-- Remove all notification functions
DROP FUNCTION IF EXISTS notify_order_changes() CASCADE;
DROP FUNCTION IF EXISTS notify_offer_changes() CASCADE;
DROP FUNCTION IF EXISTS notify_payment_changes() CASCADE;
DROP FUNCTION IF EXISTS notify_new_rating() CASCADE;
DROP FUNCTION IF EXISTS notify_listing_interest() CASCADE;
DROP FUNCTION IF EXISTS notify_on_order_placed() CASCADE;
DROP FUNCTION IF EXISTS notify_on_order_placed_working() CASCADE;
DROP FUNCTION IF EXISTS create_order_placed_notification() CASCADE;
DROP FUNCTION IF EXISTS create_order_confirmed_notification() CASCADE;
DROP FUNCTION IF EXISTS notify_on_message() CASCADE;
DROP FUNCTION IF EXISTS notify_on_message_safe() CASCADE;

-- Check what's left
SELECT 'Remaining notification triggers:' as status;
SELECT trigger_name, event_object_table
FROM information_schema.triggers 
WHERE trigger_name LIKE '%notification%'
ORDER BY event_object_table;

SELECT 'All notification triggers removed!' as result;
SELECT 'Messages should work normally now' as fix;
SELECT 'Test sending a message first' as next_step;
