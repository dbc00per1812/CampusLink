-- ============================================
-- RESTORE NOTIFICATIONS - RUN THIS IMMEDIATELY
-- Disables the broken triggers so app-level notifications work again
-- ============================================

-- Drop the broken triggers I created
DROP TRIGGER IF EXISTS order_created_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_status_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_completed_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS order_cancelled_notification_trigger ON orders CASCADE;
DROP TRIGGER IF EXISTS notify_new_order_trigger ON orders CASCADE;

-- Drop the functions
DROP FUNCTION IF EXISTS notify_new_order() CASCADE;
DROP FUNCTION IF EXISTS notify_order_delivered() CASCADE;
DROP FUNCTION IF EXISTS notify_order_completed() CASCADE;
DROP FUNCTION IF EXISTS notify_order_cancelled() CASCADE;

-- ============================================
-- VERIFY CLEANUP
-- ============================================
SELECT 
    trigger_name,
    event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'orders';

-- Should return NO rows (no triggers on orders table)
-- This means app-level notifications will work again

