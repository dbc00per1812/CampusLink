-- Check your Stripe Connect account status
-- This will tell us if you're in escrow mode or destination charges mode

-- Your Connect account details
SELECT 
  id,
  email,
  stripe_connect_id,
  stripe_payouts_enabled,
  stripe_details_submitted,
  stripe_charges_enabled,
  created_at
FROM users
WHERE id = auth.uid();

-- Recent payments - check if they used destination charges
SELECT 
  'Recent payments to see if destination charges were used:' as note;

SELECT 
  id,
  listing_id,
  buyer_id,
  seller_id,
  payment_status,
  stripe_payment_intent_id,
  created_at
FROM orders
WHERE seller_id = auth.uid()
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC
LIMIT 5;

-- Check create_payment_intent logs in Supabase Dashboard
SELECT 'Go to Supabase → Edge Functions → create_payment_intent → Logs' as next_step,
       'Look for "Using DESTINATION CHARGES" or "Using ESCROW MODE"' as what_to_find;

