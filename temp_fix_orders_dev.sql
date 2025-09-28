-- TEMPORARY FIX: Set fake Stripe Connect IDs for development/testing
-- This allows order creation to work without real Stripe onboarding

-- Update all users to have fake stripe_connect_id for testing
UPDATE users 
SET stripe_connect_id = 'acct_fake_' || SUBSTR(id::text, 1, 8)
WHERE stripe_connect_id IS NULL;

-- Check results
SELECT 'Updated users:' as info;
SELECT 
  name,
  SUBSTR(stripe_connect_id, 1, 15) || '...' as stripe_id_preview
FROM users
WHERE stripe_connect_id IS NOT NULL
LIMIT 5;
