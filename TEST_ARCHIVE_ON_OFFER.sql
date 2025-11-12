-- ============================================
-- Test Archive Listing on Offer Accept
-- ============================================
-- This script helps you test the new trigger

-- ============================================
-- STEP 1: Verify Trigger is Installed
-- ============================================

SELECT 
    trigger_name,
    event_manipulation,
    event_object_table,
    action_timing
FROM information_schema.triggers
WHERE trigger_name = 'archive_listing_after_offer_accept';

-- Expected result: 1 row showing the trigger exists

-- ============================================
-- STEP 2: Find Test Data
-- ============================================

-- Find an active listing
SELECT 
    id,
    title,
    archived,
    is_sold,
    quantity_available,
    intent,
    listing_type
FROM listings
WHERE archived = false 
  AND is_sold = false
ORDER BY created_at DESC
LIMIT 5;

-- Find pending offers on active listings
SELECT 
    o.id as offer_id,
    o.status,
    o.listing_type,
    o.seek_listing_id,
    o.offer_listing_id,
    l.title as listing_title,
    l.archived as listing_archived
FROM offers o
LEFT JOIN listings l ON l.id = COALESCE(o.offer_listing_id, o.seek_listing_id)
WHERE o.status = 'pending'
ORDER BY o.created_at DESC
LIMIT 5;

-- ============================================
-- STEP 3: Test - Accept an Offer
-- ============================================

-- BEFORE accepting, check listing status
-- Replace YOUR_LISTING_ID with actual listing ID from the offer
SELECT 
    id,
    title,
    archived,
    is_sold,
    quantity_available
FROM listings
WHERE id = 'YOUR_LISTING_ID';

-- Accept the offer
-- Replace YOUR_OFFER_ID with actual offer ID
UPDATE offers 
SET 
    status = 'accepted',
    updated_at = NOW()
WHERE id = 'YOUR_OFFER_ID';

-- AFTER accepting, check listing status again
-- It should now be archived = true, is_sold = true, quantity_available = 0
SELECT 
    id,
    title,
    archived,
    is_sold,
    quantity_available
FROM listings
WHERE id = 'YOUR_LISTING_ID';

-- ============================================
-- STEP 4: Verify in Logs
-- ============================================

-- Check Supabase logs for trigger output
-- You should see messages like:
-- 🎯 Offer accepted! Offer ID: xxx
-- 📦 Current listing state: ...
-- ✅ Listing xxx archived (offer accepted)

-- ============================================
-- STEP 5: Test Cleanup (Optional)
-- ============================================

-- If you want to reset the test data:
-- 1. Set offer back to pending
UPDATE offers 
SET 
    status = 'pending',
    updated_at = NOW()
WHERE id = 'YOUR_OFFER_ID';

-- 2. Unarchive the listing
UPDATE listings
SET 
    archived = false,
    is_sold = false,
    quantity_available = 1
WHERE id = 'YOUR_LISTING_ID';

-- ============================================
-- VERIFICATION CHECKLIST
-- ============================================

-- ✅ Trigger exists in database
-- ✅ Found active listings and pending offers
-- ✅ Accepted offer → listing archived immediately
-- ✅ archived = true, is_sold = true, quantity_available = 0
-- ✅ Logs show trigger fired successfully

-- ============================================
-- QUICK CHECK: All Active Listings
-- ============================================

-- See all currently active (not archived) listings
SELECT 
    COUNT(*) as active_listings_count
FROM listings
WHERE archived = false;

-- See all archived listings
SELECT 
    COUNT(*) as archived_listings_count
FROM listings
WHERE archived = true;

-- ============================================
-- PRODUCTION VALIDATION
-- ============================================

-- After deploying, monitor these metrics:

-- 1. Listings that should be archived (have accepted offers)
SELECT 
    l.id as listing_id,
    l.title,
    l.archived,
    o.id as offer_id,
    o.status as offer_status
FROM listings l
INNER JOIN offers o ON (
    o.seek_listing_id = l.id OR 
    o.offer_listing_id = l.id
)
WHERE o.status = 'accepted'
  AND l.archived = false;

-- Expected result: 0 rows (all listings with accepted offers should be archived)

-- 2. Check for any issues
SELECT 
    l.id,
    l.title,
    l.archived,
    l.is_sold,
    COUNT(o.id) as accepted_offers_count
FROM listings l
LEFT JOIN offers o ON (
    o.seek_listing_id = l.id OR 
    o.offer_listing_id = l.id
) AND o.status = 'accepted'
GROUP BY l.id, l.title, l.archived, l.is_sold
HAVING COUNT(o.id) > 0 AND l.archived = false;

-- Expected result: 0 rows (no listings with accepted offers that aren't archived)

