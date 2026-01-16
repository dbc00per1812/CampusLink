-- ============================================================================
-- CHECK EXPIRED LISTINGS - Diagnostic Queries
-- ============================================================================
-- Use these queries to check the current state of listing expiry
-- ============================================================================

-- ============================================================================
-- 1. Find ALL listings with expires_at set
-- ============================================================================
SELECT 
    id,
    title,
    category,
    intent,
    expires_at,
    archived,
    is_sold,
    created_at,
    CASE 
        WHEN expires_at IS NULL THEN 'No expiry'
        WHEN expires_at < NOW() THEN 'EXPIRED ⏰'
        ELSE 'Active ✓'
    END as status,
    CASE 
        WHEN expires_at IS NOT NULL THEN 
            EXTRACT(EPOCH FROM (expires_at - NOW())) / 3600
        ELSE NULL
    END as hours_until_expiry
FROM listings 
WHERE expires_at IS NOT NULL
ORDER BY expires_at ASC;


-- ============================================================================
-- 2. Count listings by expiry status
-- ============================================================================
SELECT 
    CASE 
        WHEN expires_at IS NULL THEN 'No expiry'
        WHEN expires_at < NOW() AND archived = true THEN 'Expired & Archived ✓'
        WHEN expires_at < NOW() AND archived = false THEN 'Expired but NOT archived ❌'
        ELSE 'Active'
    END as status,
    COUNT(*) as count
FROM listings 
GROUP BY 
    CASE 
        WHEN expires_at IS NULL THEN 'No expiry'
        WHEN expires_at < NOW() AND archived = true THEN 'Expired & Archived ✓'
        WHEN expires_at < NOW() AND archived = false THEN 'Expired but NOT archived ❌'
        ELSE 'Active'
    END
ORDER BY count DESC;


-- ============================================================================
-- 3. Find EXPIRED listings that should be archived
-- ============================================================================
-- These are the listings that the edge function will archive
SELECT 
    id,
    title,
    category,
    intent,
    expires_at,
    archived,
    is_sold,
    created_at,
    EXTRACT(EPOCH FROM (NOW() - expires_at)) / 3600 as hours_overdue
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false
  AND is_sold = false
ORDER BY expires_at ASC;


-- ============================================================================
-- 4. Count expired listings by category
-- ============================================================================
SELECT 
    category,
    intent,
    COUNT(*) as expired_count
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false
  AND is_sold = false
GROUP BY category, intent
ORDER BY expired_count DESC;


-- ============================================================================
-- 5. Find upcoming expiries (next 7 days)
-- ============================================================================
SELECT 
    id,
    title,
    category,
    intent,
    expires_at,
    EXTRACT(EPOCH FROM (expires_at - NOW())) / 3600 as hours_remaining,
    EXTRACT(EPOCH FROM (expires_at - NOW())) / 86400 as days_remaining
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at > NOW()
  AND expires_at < NOW() + INTERVAL '7 days'
  AND archived = false
  AND is_sold = false
ORDER BY expires_at ASC;


-- ============================================================================
-- 6. Test: Create an expired ticket for testing
-- ============================================================================
-- UNCOMMENT TO CREATE TEST DATA:

-- INSERT INTO listings (
--     user_id,
--     title,
--     description,
--     category,
--     price_cents,
--     listing_type,
--     intent,
--     expires_at,
--     archived,
--     is_sold,
--     status
-- ) VALUES (
--     (SELECT id FROM users LIMIT 1),  -- Use first available user
--     'TEST: Expired Concert Ticket',
--     'This is a test ticket that should be auto-archived',
--     'Tickets',
--     2500,
--     'product',
--     'offer',
--     NOW() - INTERVAL '2 hours',  -- Expired 2 hours ago
--     false,
--     false,
--     'active'
-- );

-- INSERT INTO listings (
--     user_id,
--     title,
--     description,
--     category,
--     price_cents,
--     listing_type,
--     intent,
--     expires_at,
--     archived,
--     is_sold,
--     status
-- ) VALUES (
--     (SELECT id FROM users LIMIT 1),
--     'TEST: Expired Seek Post',
--     'This is a test seek post that should be auto-archived',
--     'Books',
--     1000,
--     'product',
--     'seek',
--     NOW() - INTERVAL '1 day',  -- Expired 1 day ago
--     false,
--     false,
--     'active'
-- );


-- ============================================================================
-- 7. Manually archive ALL expired listings
-- ============================================================================
-- UNCOMMENT TO MANUALLY ARCHIVE:

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
-- 8. Check if cron job is set up
-- ============================================================================
SELECT 
    jobid,
    jobname,
    schedule,
    active,
    nodename
FROM cron.job 
WHERE jobname = 'process-expired-listings';


-- ============================================================================
-- 9. Check recent cron job runs
-- ============================================================================
SELECT 
    runid,
    jobid,
    status,
    start_time,
    end_time,
    EXTRACT(EPOCH FROM (end_time - start_time)) as duration_seconds
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'process-expired-listings')
ORDER BY start_time DESC 
LIMIT 10;

