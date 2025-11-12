-- Check status of the $4.25 payout that was just requested

-- 1. Get the most recent payout details
SELECT 
  '=== RECENT PAYOUT DETAILS ===' as section;

SELECT 
  id,
  amount_cents,
  fee_cents,
  net_amount_cents,
  status,
  stripe_payout_id,
  stripe_transfer_id,
  error_message,
  payout_type,
  payout_method,
  created_at,
  updated_at,
  EXTRACT(EPOCH FROM (NOW() - created_at))/60 as minutes_ago
FROM payouts
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 1;

-- 2. Check if it actually created a Stripe payout
SELECT 
  '=== STRIPE PAYOUT STATUS ===' as section;

SELECT 
  CASE 
    WHEN stripe_payout_id IS NOT NULL 
    THEN '✅ Payout created in Stripe: ' || stripe_payout_id
    ELSE '❌ No Stripe payout ID - never reached Stripe or failed immediately'
  END as stripe_status,
  CASE
    WHEN status = 'pending' THEN '⏳ Still pending'
    WHEN status = 'processing' THEN '🔄 Processing in Stripe'
    WHEN status = 'completed' THEN '✅ Money sent!'
    WHEN status = 'failed' THEN '❌ Failed: ' || COALESCE(error_message, 'Unknown error')
    ELSE '❓ Unknown status: ' || status
  END as current_status
FROM payouts
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 1;

-- 3. Check what should have happened vs what did happen
SELECT 
  '=== VALIDATION ===' as section;

SELECT 
  amount_cents as requested_cents,
  (amount_cents / 100.0) as requested_dollars,
  '2.56' as stripe_total_balance_dollars,
  '0.56' as stripe_available_for_standard_dollars,
  CASE 
    WHEN amount_cents <= 56 THEN '✅ Within standard payout limit'
    WHEN amount_cents <= 256 THEN '⚠️ Needs instant payout (total balance) or wait for pending to clear'
    ELSE '❌ More than exists in Stripe!'
  END as validation_result,
  CASE
    WHEN amount_cents > 256 THEN 'SHOULD FAIL - requesting more than exists'
    WHEN amount_cents > 56 AND amount_cents <= 256 THEN 'MIGHT FAIL - requesting more than available for standard ($0.56)'
    ELSE 'SHOULD SUCCEED - within available limit'
  END as expected_outcome
FROM payouts
WHERE user_id = auth.uid()
ORDER BY created_at DESC
LIMIT 1;

-- 4. Show all payouts from today to see if there are duplicates or stuck ones
SELECT 
  '=== ALL PAYOUTS TODAY ===' as section;

SELECT 
  id,
  amount_cents / 100.0 as amount_dollars,
  status,
  stripe_payout_id,
  error_message,
  created_at
FROM payouts
WHERE user_id = auth.uid()
  AND created_at > CURRENT_DATE
ORDER BY created_at DESC;

-- 5. Check if we need to refund the database wallet
SELECT 
  '=== WALLET CHECK ===' as section;

WITH payout_check AS (
  SELECT 
    status,
    amount_cents
  FROM payouts
  WHERE user_id = auth.uid()
  ORDER BY created_at DESC
  LIMIT 1
)
SELECT 
  w.available_cents as current_wallet_cents,
  (w.available_cents / 100.0) as current_wallet_dollars,
  p.status as payout_status,
  p.amount_cents as payout_amount_cents,
  CASE 
    WHEN p.status = 'failed' THEN 'Need to refund ' || (p.amount_cents / 100.0) || ' dollars back to wallet'
    WHEN p.status = 'pending' AND p.amount_cents > 256 THEN 'Payout will likely fail - may need refund soon'
    ELSE 'No refund needed yet'
  END as action_needed
FROM wallets w
CROSS JOIN payout_check p
WHERE w.user_id = auth.uid();

