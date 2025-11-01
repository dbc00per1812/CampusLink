-- ============================================
-- EMERGENCY: DISABLE ORDER NOTIFICATION TRIGGERS
-- Run this IMMEDIATELY to restore your app functionality
-- ============================================

-- Disable all the triggers I created
ALTER TABLE orders DISABLE TRIGGER IF EXISTS order_created_notification_trigger;
ALTER TABLE orders DISABLE TRIGGER IF EXISTS order_status_notification_trigger;
ALTER TABLE orders DISABLE TRIGGER IF EXISTS order_completed_notification_trigger;
ALTER TABLE orders DISABLE TRIGGER IF EXISTS order_cancelled_notification_trigger;

-- Verify they're disabled
SELECT 
    trigger_name,
    event_object_table,
    tgenabled
FROM information_schema.triggers
WHERE event_object_table = 'orders';

-- tgenabled values:
-- 'O' = enabled
-- 'D' = disabled
-- Should show all as 'D' after running this

