-- ============================================================================
-- AUTO-ARCHIVE EXPIRED LISTINGS - Tickets & Seek Posts
-- ============================================================================
-- This sets up automatic archiving of listings that have passed their
-- expires_at date. This includes:
-- - Tickets: expire at event date
-- - Seek posts: expire after 7 days (or custom date)
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
-- STEP 2: Schedule the Cron Job (Every 30 Minutes)
-- ============================================================================
-- This runs every 30 minutes to check for and archive expired listings.
-- The edge function handles:
-- - Finding listings where expires_at < NOW()
-- - Setting archived = true
-- - Notifying the listing owner
-- ============================================================================

SELECT cron.schedule(
    'process-expired-listings',  -- Job name
    '*/30 * * * *',              -- Every 30 minutes
    $$
    SELECT net.http_post(
        url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings',
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
WHERE jobname = 'process-expired-listings';


-- ============================================================================
-- TESTING: Find expired listings that should be archived
-- ============================================================================

-- Check if there are any expired listings
SELECT 
    id, 
    title, 
    category, 
    intent,
    expires_at, 
    archived,
    is_sold,
    created_at,
    (expires_at < NOW()) as is_expired
FROM listings 
WHERE expires_at IS NOT NULL
  AND archived = false
  AND is_sold = false
ORDER BY expires_at ASC
LIMIT 20;

-- Count expired listings by category
SELECT 
    category,
    intent,
    COUNT(*) as count
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false
  AND is_sold = false
GROUP BY category, intent;


-- ============================================================================
-- MANAGEMENT COMMANDS
-- ============================================================================

-- View all cron jobs:
-- SELECT * FROM cron.job;

-- View recent job runs:
-- SELECT * FROM cron.job_run_details 
-- WHERE jobname = 'process-expired-listings'
-- ORDER BY start_time DESC 
-- LIMIT 20;

-- Manually trigger the job (for testing):
-- SELECT net.http_post(
--     url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings',
--     headers := '{"Content-Type": "application/json", "Authorization": "Bearer <your-anon-key>"}'::jsonb,
--     body := '{}'::jsonb
-- );

-- Disable the job:
-- SELECT cron.unschedule('process-expired-listings');

-- Change schedule (e.g., run every hour):
-- SELECT cron.unschedule('process-expired-listings');
-- SELECT cron.schedule(
--     'process-expired-listings',
--     '0 * * * *',
--     $$<same SQL as above>$$
-- );


-- ============================================================================
-- MANUAL ARCHIVING (for testing or one-time cleanup)
-- ============================================================================

-- Manually archive all expired listings
-- UNCOMMENT TO RUN:

-- UPDATE listings 
-- SET 
--     archived = true,
--     updated_at = NOW()
-- WHERE expires_at IS NOT NULL
--   AND expires_at < NOW()
--   AND archived = false
--   AND is_sold = false
-- RETURNING id, title, category, expires_at;


-- ============================================================================
-- ALTERNATIVE: Database-Only Approach (No Edge Function)
-- ============================================================================
-- If you prefer to handle archiving entirely in SQL without the edge function,
-- you can use this approach. However, it won't send push notifications.
-- ============================================================================

-- CREATE OR REPLACE FUNCTION archive_expired_listings()
-- RETURNS void AS $$
-- DECLARE
--     expired_listing RECORD;
-- BEGIN
--     FOR expired_listing IN
--         SELECT id, title, category, user_id, expires_at
--         FROM listings
--         WHERE expires_at IS NOT NULL
--         AND expires_at < NOW()
--         AND archived = false
--         AND is_sold = false
--     LOOP
--         -- Archive the listing
--         UPDATE listings
--         SET 
--             archived = true,
--             updated_at = NOW()
--         WHERE id = expired_listing.id;
--         
--         -- Queue notification
--         INSERT INTO push_notification_queue (user_id, title, body, data)
--         VALUES (
--             expired_listing.user_id,
--             'Listing Expired',
--             'Your ' || expired_listing.category || ' "' || expired_listing.title || '" has expired and been archived.',
--             jsonb_build_object(
--                 'type', 'listing_expired',
--                 'listing_id', expired_listing.id,
--                 'category', expired_listing.category
--             )
--         );
--         
--         RAISE NOTICE 'Archived expired listing: % (expired at: %)', 
--             expired_listing.title, expired_listing.expires_at;
--     END LOOP;
-- END;
-- $$ LANGUAGE plpgsql;
-- 
-- -- Schedule the function:
-- SELECT cron.schedule('archive-expired-listings', '*/30 * * * *', 'SELECT archive_expired_listings()');

