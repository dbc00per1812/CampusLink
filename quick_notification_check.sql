-- Quick Notification System Check
-- Run this to see what's missing

-- 1. Check if notification triggers exist (FIXED - correct columns)
SELECT 
  n.nspname as schema_name,
  c.relname as table_name,
  t.tgname as trigger_name
FROM pg_trigger t
JOIN pg_class c ON t.tgrelid = c.oid
JOIN pg_namespace n ON c.relnamespace = n.oid
WHERE t.tgname LIKE '%notification%'
ORDER BY c.relname, t.tgname;

-- 2. Check if notification tables exist
SELECT table_name 
FROM information_schema.tables 
WHERE table_schema = 'public' 
AND table_name IN ('notifications', 'user_notification_preferences', 'push_notification_queue')
ORDER BY table_name;

-- 3. Check if notification functions exist
SELECT proname as function_name
FROM pg_proc 
WHERE proname LIKE '%notification%'
ORDER BY proname;

-- 4. Check recent orders (to test triggers)
SELECT id, buyer_id, seller_id, order_status, created_at 
FROM orders 
ORDER BY created_at DESC 
LIMIT 3;

-- 5. Check if ANY notifications exist
SELECT COUNT(*) as notification_count FROM notifications;

-- If notification_count is 0, triggers aren't working
-- If tables don't exist, run setup_notifications_complete.sql first
-- If triggers don't exist, run create_order_notifications.sql and create_offer_notifications.sql
