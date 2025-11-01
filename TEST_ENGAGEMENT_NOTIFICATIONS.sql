-- ============================================
-- TEST ENGAGEMENT NOTIFICATIONS
-- ============================================
-- Comprehensive testing suite for all engagement notifications
-- Run these queries after deploying DEPLOY_ENGAGEMENT_NOTIFICATIONS.sql
-- ============================================

-- ============================================
-- SECTION 1: VERIFICATION QUERIES
-- ============================================

-- Query 1: Verify CHECK constraint updated
SELECT 
    constraint_name,
    check_clause
FROM information_schema.check_constraints
WHERE constraint_name = 'notifications_type_check'
AND constraint_schema = 'public';

-- Expected: Should see all old types + 'idle_listing_reminder', 'message_reminder', 'first_sale_milestone'

-- Query 2: Verify triggers exist
SELECT 
    trigger_name,
    event_object_table,
    action_timing,
    event_manipulation,
    action_statement
FROM information_schema.triggers
WHERE trigger_name IN ('first_sale_milestone_trigger', 'payout_success_trigger')
AND trigger_schema = 'public'
ORDER BY trigger_name;

-- Expected: 2 triggers (one on orders, one on payouts)

-- Query 3: Verify functions exist
SELECT 
    routine_name,
    routine_type,
    data_type
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'notify_first_sale_milestone',
    'notify_payout_success',
    'send_idle_listing_reminders',
    'send_rating_reminders',
    'send_message_reminders',
    'send_campus_activity_digest'
)
ORDER BY routine_name;

-- Expected: 6 functions (2 trigger functions, 4 scheduled functions)

-- Query 4: Verify cron jobs scheduled
SELECT 
    jobid,
    jobname,
    schedule,
    active,
    command
FROM cron.job
WHERE jobname IN (
    'send-idle-listing-reminders',
    'send-rating-reminders',
    'send-message-reminders',
    'send-campus-activity-digest'
)
ORDER BY jobname;

-- Expected: 4 active cron jobs with correct schedules

-- Query 5: Check for conflicts with existing triggers
SELECT 
    event_object_table,
    COUNT(*) as trigger_count,
    array_agg(trigger_name ORDER BY trigger_name) as triggers
FROM information_schema.triggers
WHERE trigger_schema = 'public'
AND event_object_table IN ('orders', 'payouts', 'messages', 'offers')
GROUP BY event_object_table
ORDER BY event_object_table;

-- Expected: Multiple triggers per table is OK - they fire in alphabetical order

-- ============================================
-- SECTION 2: DATA ANALYSIS QUERIES
-- ============================================

-- Query 6: Find listings eligible for idle reminders
SELECT 
    l.id,
    l.user_id,
    l.title,
    l.created_at,
    l.status,
    COALESCE(MAX(o.created_at), l.created_at) as last_activity,
    EXTRACT(DAY FROM NOW() - COALESCE(MAX(o.created_at), l.created_at)) as days_idle
FROM listings l
LEFT JOIN orders o ON o.listing_id = l.id
WHERE l.is_sold = false
AND l.archived = false
AND l.status = 'active'
AND l.created_at < NOW() - INTERVAL '7 days'
GROUP BY l.id, l.user_id, l.title, l.created_at, l.status
HAVING COALESCE(MAX(o.created_at), l.created_at) < NOW() - INTERVAL '7 days'
ORDER BY days_idle DESC
LIMIT 10;

-- Shows listings that will receive idle reminders

-- Query 7: Find orders eligible for rating reminders
SELECT 
    o.id,
    o.buyer_id,
    o.seller_id,
    o.completed_at,
    EXTRACT(DAY FROM NOW() - o.completed_at)::INTEGER as days_since_completion,
    EXISTS(SELECT 1 FROM ratings WHERE order_id = o.id AND rating_type = 'buyer_to_seller') as buyer_rated,
    EXISTS(SELECT 1 FROM ratings WHERE order_id = o.id AND rating_type = 'seller_to_buyer') as seller_rated
FROM orders o
WHERE o.order_status = 'completed'
AND o.completed_at IS NOT NULL
AND o.completed_at < NOW() - INTERVAL '1 day'
AND o.completed_at > NOW() - INTERVAL '14 days'
ORDER BY o.completed_at DESC
LIMIT 10;

-- Shows orders needing ratings

-- Query 8: Find messages eligible for reminders
SELECT 
    m.id,
    m.sender_id,
    m.created_at,
    m.read_at,
    EXTRACT(HOUR FROM NOW() - m.created_at) as hours_unread,
    c.buyer_id,
    c.seller_id,
    l.title as listing_title
FROM messages m
JOIN conversations c ON c.id = m.conversation_id
LEFT JOIN listings l ON l.id = c.listing_id
WHERE m.read_at IS NULL
AND m.created_at < NOW() - INTERVAL '24 hours'
AND m.created_at > NOW() - INTERVAL '14 days'
ORDER BY m.created_at
LIMIT 10;

-- Shows unread messages that will trigger reminders

-- Query 9: Count new listings by campus (for digest)
SELECT 
    u.campus,
    COUNT(*) as new_listings_24h
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE l.created_at > NOW() - INTERVAL '24 hours'
AND l.status = 'active'
AND l.archived = false
AND u.campus IS NOT NULL
GROUP BY u.campus
ORDER BY new_listings_24h DESC;

-- Shows campus activity levels

-- Query 10: Find users eligible for first sale milestone
SELECT 
    u.id as seller_id,
    u.name as seller_name,
    COUNT(o.id) as completed_orders
FROM users u
JOIN orders o ON o.seller_id = u.id
WHERE o.order_status = 'completed'
GROUP BY u.id, u.name
HAVING COUNT(o.id) = 1
ORDER BY MAX(o.completed_at) DESC
LIMIT 10;

-- Shows sellers who just completed their first sale

-- ============================================
-- SECTION 3: MANUAL TEST SCENARIOS
-- ============================================

-- TEST 1: First Sale Milestone
-- ================================
-- Setup: Find a test order or create one
-- Action: Update order status to 'completed' (if seller has 0 completed orders)
/*
UPDATE orders
SET order_status = 'completed',
    completed_at = NOW()
WHERE id = 'YOUR_TEST_ORDER_ID'
AND seller_id IN (
    SELECT id FROM users 
    WHERE id NOT IN (SELECT seller_id FROM orders WHERE order_status = 'completed')
    LIMIT 1
);
*/
-- Expected: Notification created with type 'first_sale_milestone'
-- Verify:
-- SELECT * FROM notifications WHERE type = 'first_sale_milestone' ORDER BY created_at DESC LIMIT 1;

-- TEST 2: Payout Success
-- ================================
-- Setup: Find a test payout or create one
-- Action: Update payout status to 'paid'
/*
UPDATE payouts
SET status = 'paid',
    paid_at = NOW()
WHERE id = 'YOUR_TEST_PAYOUT_ID';
*/
-- Expected: Notification created with type 'payout_completed'
-- Verify:
-- SELECT * FROM notifications WHERE type = 'payout_completed' ORDER BY created_at DESC LIMIT 1;

-- TEST 3: Idle Listing Reminder
-- ================================
-- Action: Manually call the function
/*
SELECT send_idle_listing_reminders();
*/
-- Expected: Notifications created for idle listings
-- Verify:
-- SELECT * FROM notifications WHERE type = 'idle_listing_reminder' ORDER BY created_at DESC LIMIT 5;

-- TEST 4: Rating Reminders
-- ================================
-- Action: Manually call the function
/*
SELECT send_rating_reminders();
*/
-- Expected: Notifications created for orders without ratings
-- Verify:
-- SELECT * FROM notifications WHERE type = 'rating_reminder' ORDER BY created_at DESC LIMIT 5;

-- TEST 5: Message Reminders
-- ================================
-- Action: Manually call the function
/*
SELECT send_message_reminders();
*/
-- Expected: Notifications created for unread messages > 24h old
-- Verify:
-- SELECT * FROM notifications WHERE type = 'message_reminder' ORDER BY created_at DESC LIMIT 5;

-- TEST 6: Campus Activity Digest
-- ================================
-- Action: Manually call the function
/*
SELECT send_campus_activity_digest();
*/
-- Expected: Notifications created for users on campuses with 3+ new listings
-- Verify:
-- SELECT * FROM notifications WHERE type = 'marketplace_activity' 
-- AND body LIKE '%new items posted on your campus%' 
-- ORDER BY created_at DESC LIMIT 5;

-- ============================================
-- SECTION 4: MONITORING QUERIES
-- ============================================

-- Query 11: Count notifications by type (last 24 hours)
SELECT 
    type,
    COUNT(*) as notification_count,
    COUNT(DISTINCT user_id) as unique_recipients
FROM notifications
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY type
ORDER BY notification_count DESC;

-- Query 12: Recent engagement notifications
SELECT 
    id,
    user_id,
    type,
    title,
    LEFT(body, 60) as body_preview,
    is_read,
    created_at
FROM notifications
WHERE type IN (
    'idle_listing_reminder',
    'rating_reminder',
    'message_reminder',
    'marketplace_activity',
    'first_sale_milestone',
    'payout_completed'
)
ORDER BY created_at DESC
LIMIT 20;

-- Query 13: Notification read rates by type
SELECT 
    type,
    COUNT(*) as total_sent,
    SUM(CASE WHEN is_read THEN 1 ELSE 0 END) as read_count,
    ROUND(100.0 * SUM(CASE WHEN is_read THEN 1 ELSE 0 END) / COUNT(*), 2) as read_rate_percent
FROM notifications
WHERE type IN (
    'idle_listing_reminder',
    'rating_reminder',
    'message_reminder',
    'marketplace_activity',
    'first_sale_milestone',
    'payout_completed'
)
GROUP BY type
ORDER BY read_rate_percent DESC;

-- Query 14: Cron job execution history
SELECT 
    jobid,
    jobname,
    runid,
    job_pid,
    database,
    username,
    command,
    status,
    return_message,
    start_time,
    end_time
FROM cron.job_run_details
WHERE jobname IN (
    'send-idle-listing-reminders',
    'send-rating-reminders',
    'send-message-reminders',
    'send-campus-activity-digest'
)
ORDER BY start_time DESC
LIMIT 20;

-- Query 15: Check for any errors in notification creation
SELECT 
    type,
    COUNT(*) as count,
    array_agg(DISTINCT user_id) as affected_users
FROM notifications
WHERE created_at > NOW() - INTERVAL '24 hours'
AND (
    title IS NULL 
    OR body IS NULL 
    OR user_id IS NULL
)
GROUP BY type;

-- Expected: Zero results (no malformed notifications)

-- ============================================
-- SECTION 5: PERFORMANCE CHECKS
-- ============================================

-- Query 16: Check notification table size growth
SELECT 
    COUNT(*) as total_notifications,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '1 day') as last_24h,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '7 days') as last_7d,
    COUNT(*) FILTER (WHERE created_at > NOW() - INTERVAL '30 days') as last_30d
FROM notifications;

-- Query 17: Average notification processing time (if timing available)
SELECT 
    type,
    COUNT(*) as count,
    AVG(EXTRACT(EPOCH FROM (delivered_at - created_at))) as avg_delivery_seconds
FROM notifications
WHERE delivered_at IS NOT NULL
AND created_at > NOW() - INTERVAL '7 days'
AND type IN (
    'idle_listing_reminder',
    'rating_reminder',
    'message_reminder',
    'marketplace_activity',
    'first_sale_milestone',
    'payout_completed'
)
GROUP BY type
ORDER BY avg_delivery_seconds;

-- Query 18: Check for duplicate notifications
SELECT 
    user_id,
    type,
    order_id,
    listing_id,
    message_id,
    COUNT(*) as duplicate_count
FROM notifications
WHERE created_at > NOW() - INTERVAL '24 hours'
AND type IN (
    'idle_listing_reminder',
    'rating_reminder',
    'message_reminder',
    'marketplace_activity',
    'first_sale_milestone',
    'payout_completed'
)
GROUP BY user_id, type, order_id, listing_id, message_id
HAVING COUNT(*) > 1
ORDER BY duplicate_count DESC;

-- Expected: Minimal/no duplicates (some are OK for recurring reminders)

-- ============================================
-- SECTION 6: ROLLBACK QUERIES (IF NEEDED)
-- ============================================

-- ROLLBACK: Drop all engagement notification components
/*
-- Unschedule cron jobs
SELECT cron.unschedule('send-idle-listing-reminders');
SELECT cron.unschedule('send-rating-reminders');
SELECT cron.unschedule('send-message-reminders');
SELECT cron.unschedule('send-campus-activity-digest');

-- Drop triggers
DROP TRIGGER IF EXISTS first_sale_milestone_trigger ON orders;
DROP TRIGGER IF EXISTS payout_success_trigger ON payouts;

-- Drop functions
DROP FUNCTION IF EXISTS notify_first_sale_milestone();
DROP FUNCTION IF EXISTS notify_payout_success();
DROP FUNCTION IF EXISTS send_idle_listing_reminders();
DROP FUNCTION IF EXISTS send_rating_reminders();
DROP FUNCTION IF EXISTS send_message_reminders();
DROP FUNCTION IF EXISTS send_campus_activity_digest();

-- Revert CHECK constraint (remove new types)
ALTER TABLE notifications DROP CONSTRAINT IF EXISTS notifications_type_check;
ALTER TABLE notifications ADD CONSTRAINT notifications_type_check 
CHECK (type = ANY (ARRAY[
    'order_placed'::text, 'order_confirmed'::text, 'order_in_progress'::text, 
    'order_completed'::text, 'order_cancelled'::text, 'payment_succeeded'::text, 
    'payment_failed'::text, 'new_message'::text, 'rating_received'::text, 
    'rating_reminder'::text, 'payout_completed'::text, 'listing_interest'::text, 
    'marketplace_activity'::text
]));
*/

-- ============================================
-- DEPLOYMENT CHECKLIST
-- ============================================

/*
Day 1: Deploy & Verify
[ ] Run DEPLOY_ENGAGEMENT_NOTIFICATIONS.sql
[ ] Verify all triggers created (Query 2)
[ ] Verify all functions created (Query 3)
[ ] Verify cron jobs scheduled (Query 4)
[ ] Run manual tests (Section 3)
[ ] Check recent notifications (Query 12)

Day 2-7: Monitor
[ ] Check notification counts daily (Query 11)
[ ] Monitor read rates (Query 13)
[ ] Check cron execution history (Query 14)
[ ] Look for errors (Query 15)
[ ] Check for duplicates (Query 18)

Week 2+: Optimize
[ ] Analyze read rates by type
[ ] Adjust notification frequency if needed
[ ] Tune cron schedules based on user activity
[ ] Add A/B testing for notification copy
*/

-- ============================================
-- SUCCESS CRITERIA
-- ============================================

/*
✅ All 6 functions created
✅ 2 real-time triggers working
✅ 4 cron jobs running on schedule
✅ Notifications being created with correct data
✅ No errors in cron execution
✅ Read rates above 30% for engagement notifications
✅ No performance impact on existing notifications
✅ Zero duplicate notifications (except intentional reminders)
*/

