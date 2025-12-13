-- ============================================================================
-- AUTO-CANCEL EXPIRED ORDERS - 5-Day Seller Deadline
-- ============================================================================
-- This sets up automatic cancellation of orders that haven't been completed
-- within 5 days. Sellers must confirm and complete orders within this window
-- or the order is automatically cancelled and the buyer is refunded.
-- 
-- Run these in Supabase SQL Editor
-- ============================================================================


-- ============================================================================
-- STEP 1: Enable Required Extensions
-- ============================================================================
-- Go to: Supabase Dashboard > Database > Extensions
-- Enable: pg_net (for HTTP calls)
-- Enable: pg_cron (for scheduled jobs)
-- ============================================================================

CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;


-- ============================================================================
-- STEP 2: Schedule the Hourly Cron Job
-- ============================================================================
-- This runs every hour to check for and cancel expired orders.
-- The edge function handles:
-- - Finding orders older than 5 days
-- - Cancelling/refunding Stripe payments
-- - Updating order status
-- - Notifying buyer and seller
-- - Restoring listing availability
-- ============================================================================

SELECT cron.schedule(
    'process-expired-orders',  -- Job name
    '0 * * * *',              -- Every hour at minute 0
    $$
    SELECT net.http_post(
        url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-orders',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw'
        ),
        body := '{}'::jsonb
    );
    $$
);


-- ============================================================================
-- VERIFICATION: Check that the cron job is scheduled
-- ============================================================================

SELECT 
    jobid,
    schedule,
    command,
    nodename,
    active
FROM cron.job 
WHERE jobname = 'process-expired-orders';


-- ============================================================================
-- MANAGEMENT COMMANDS
-- ============================================================================

-- View all cron jobs:
-- SELECT * FROM cron.job;

-- View recent job runs:
-- SELECT * FROM cron.job_run_details ORDER BY start_time DESC LIMIT 20;

-- Manually trigger the job (for testing):
-- SELECT net.http_post(
--     url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-orders',
--     headers := '{"Content-Type": "application/json", "Authorization": "Bearer <your-token>"}'::jsonb,
--     body := '{}'::jsonb
-- );

-- Disable the job:
-- SELECT cron.unschedule('process-expired-orders');

-- Change schedule (e.g., run every 30 minutes):
-- SELECT cron.schedule(
--     'process-expired-orders',
--     '*/30 * * * *',
--     $$<same SQL as above>$$
-- );


-- ============================================================================
-- ALTERNATIVE: Database-Only Approach (No Edge Function)
-- ============================================================================
-- If you prefer to handle cancellation entirely in SQL without the edge function,
-- you can use this approach. However, it won't handle Stripe refunds automatically.
-- ============================================================================

-- CREATE OR REPLACE FUNCTION cancel_expired_orders()
-- RETURNS void AS $$
-- DECLARE
--     expired_order RECORD;
--     cutoff_time TIMESTAMP := NOW() - INTERVAL '5 days';
-- BEGIN
--     FOR expired_order IN
--         SELECT id, buyer_id, seller_id, listing_id, payment_method, payment_status
--         FROM orders
--         WHERE order_status IN ('placed', 'seller_confirmed', 'in_progress')
--         AND created_at < cutoff_time
--     LOOP
--         -- Update order status
--         UPDATE orders
--         SET 
--             order_status = 'cancelled',
--             payment_status = CASE 
--                 WHEN payment_status = 'succeeded' THEN 'refunded'
--                 ELSE 'cancelled'
--             END,
--             cancelled_at = NOW(),
--             updated_at = NOW()
--         WHERE id = expired_order.id;
--         
--         -- Restore listing
--         UPDATE listings
--         SET is_sold = false, archived = false, updated_at = NOW()
--         WHERE id = expired_order.listing_id;
--         
--         -- Queue notifications
--         INSERT INTO push_notification_queue (user_id, title, body, data)
--         VALUES 
--             (expired_order.buyer_id, 'Order Auto-Cancelled', 
--              'Your order was cancelled because the seller did not complete it within 5 days.',
--              jsonb_build_object('type', 'order_cancelled', 'order_id', expired_order.id)),
--             (expired_order.seller_id, 'Order Cancelled - Deadline Missed',
--              'Your order was auto-cancelled because it was not completed within 5 days.',
--              jsonb_build_object('type', 'order_cancelled', 'order_id', expired_order.id));
--         
--         RAISE NOTICE 'Cancelled expired order: %', expired_order.id;
--     END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;
-- 
-- -- Schedule the function:
-- SELECT cron.schedule('cancel-expired-orders', '0 * * * *', 'SELECT cancel_expired_orders()');


-- ============================================================================
-- ADD ORDER DEADLINE COLUMN (Optional - for tracking)
-- ============================================================================
-- This adds a computed deadline column to help with UI display

-- ALTER TABLE orders ADD COLUMN IF NOT EXISTS deadline_at TIMESTAMP 
--     GENERATED ALWAYS AS (created_at + INTERVAL '5 days') STORED;

-- Or as a view:
-- CREATE OR REPLACE VIEW orders_with_deadline AS
-- SELECT 
--     *,
--     created_at + INTERVAL '5 days' AS deadline_at,
--     CASE 
--         WHEN order_status IN ('completed', 'cancelled', 'refunded') THEN NULL
--         ELSE EXTRACT(EPOCH FROM (created_at + INTERVAL '5 days' - NOW())) / 3600
--     END AS hours_remaining
-- FROM orders;
