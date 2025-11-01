-- ============================================
-- FIX: Remove broken push notification trigger
-- ============================================
-- There's a broken trigger trying to send push notifications
-- This is what's actually failing
-- ============================================

-- First, let's see ALL triggers on messages table
SELECT 
    trigger_name,
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'messages';

-- You'll probably see multiple triggers including one for push notifications

-- Drop the broken push notification triggers
DROP TRIGGER IF EXISTS send_push_notification_trigger ON messages CASCADE;
DROP TRIGGER IF EXISTS push_notification_trigger ON messages CASCADE;
DROP TRIGGER IF EXISTS notify_push_on_message ON messages CASCADE;

-- Drop the broken push notification function
DROP FUNCTION IF EXISTS send_push_notification_on_insert() CASCADE;
DROP FUNCTION IF EXISTS send_push_notification() CASCADE;

-- Verify only the basic notification trigger remains
SELECT 
    trigger_name,
    event_object_table
FROM information_schema.triggers
WHERE event_object_table = 'messages';

-- Should only show: message_notification_trigger

-- ============================================
-- NOW send a test message and it should work!
-- ============================================



