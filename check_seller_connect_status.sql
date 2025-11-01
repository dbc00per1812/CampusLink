-- Script to check seller's Stripe Connect status
-- Use this to diagnose payment capability issues

-- STEP 1: Find the seller in question (replace with actual seller ID or name)
-- Get seller's user info and Connect account ID
SELECT 
  id,
  name,
  email,
  stripe_connect_id,
  created_at
FROM users
WHERE stripe_connect_id IS NOT NULL
ORDER BY created_at DESC
LIMIT 10;

-- STEP 2: If you know the seller's ID, use this to get just their info:
-- SELECT 
--   id,
--   name,
--   email,
--   stripe_connect_id,
--   created_at
-- FROM users
-- WHERE id = 'SELLER_USER_ID_HERE';

-- STEP 3: Check their listings
SELECT 
  l.id as listing_id,
  l.title,
  l.price,
  l.status,
  u.name as seller_name,
  u.stripe_connect_id,
  l.created_at
FROM listings l
JOIN users u ON l.user_id = u.id
WHERE u.stripe_connect_id IS NOT NULL
ORDER BY l.created_at DESC
LIMIT 10;

-- NOTES:
-- After getting the stripe_connect_id, you need to check in Stripe Dashboard:
-- 1. Go to: https://dashboard.stripe.com/test/connect/accounts/overview
-- 2. Search for the account ID
-- 3. Check "Capabilities" tab
-- 4. Look for "Transfers" status - should be "Active"
-- 
-- Possible Transfers statuses:
-- - inactive: Not yet requested or enabled
-- - pending: Stripe is reviewing
-- - active: Ready to receive transfers ✅
-- - disabled: Account is restricted
--
-- To fix if transfers is not active:
-- - Seller needs to complete Stripe Connect onboarding
-- - May need to verify identity
-- - May need to add bank account
-- - Check for any account restrictions in Stripe dashboard

