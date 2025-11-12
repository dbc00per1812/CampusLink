-- Debug: Why does payout fail when Stripe has funds?
-- Run this to compare database wallet vs actual Stripe balance

-- 1. What does the DATABASE think you have?
SELECT 
  'DATABASE WALLET BALANCE' as source,
  user_id,
  available_cents,
  pending_cents,
  total_cents,
  (available_cents / 100.0) as available_dollars,
  updated_at
FROM wallets
WHERE user_id = auth.uid();

-- 2. What payouts have been REQUESTED but maybe stuck?
SELECT 
  'RECENT PAYOUT ATTEMPTS' as source,
  id,
  amount_cents,
  net_amount_cents,
  fee_cents,
  status,
  stripe_payout_id,
  error_message,
  created_at
FROM payouts
WHERE user_id = auth.uid()
  AND created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- 3. Check if there are PENDING payouts that reduced wallet but never completed
SELECT 
  'STUCK PENDING PAYOUTS' as source,
  id,
  amount_cents,
  status,
  created_at,
  EXTRACT(EPOCH FROM (NOW() - created_at))/60 as minutes_stuck
FROM payouts
WHERE user_id = auth.uid()
  AND status = 'pending'
ORDER BY created_at DESC;

-- 4. Check recent SALES/PAYMENTS that should have added to wallet
SELECT 
  'RECENT SALES (should be in wallet)' as source,
  o.id,
  o.seller_price_cents,
  o.payment_status,
  o.order_status,
  o.created_at,
  o.stripe_payment_intent_id
FROM orders o
WHERE o.seller_id = auth.uid()
  AND o.payment_status = 'succeeded'
  AND o.created_at > NOW() - INTERVAL '7 days'
ORDER BY o.created_at DESC;

-- 5. Calculate what SHOULD be in wallet
WITH sales AS (
  SELECT COALESCE(SUM(seller_price_cents), 0) as total_sales
  FROM orders
  WHERE seller_id = auth.uid()
    AND payment_status = 'succeeded'
    AND order_status IN ('delivered', 'completed', 'seller_confirmed')
),
payouts AS (
  SELECT COALESCE(SUM(amount_cents), 0) as total_payouts
  FROM payouts
  WHERE user_id = auth.uid()
    AND status IN ('completed', 'processing', 'pending')
)
SELECT 
  'CALCULATED BALANCE' as source,
  (SELECT total_sales FROM sales) as total_earned_cents,
  (SELECT total_payouts FROM payouts) as total_withdrawn_cents,
  (SELECT total_sales FROM sales) - (SELECT total_payouts FROM payouts) as should_have_cents,
  ((SELECT total_sales FROM sales) - (SELECT total_payouts FROM payouts)) / 100.0 as should_have_dollars;

-- 6. Show the MISMATCH
WITH wallet AS (
  SELECT available_cents FROM wallets WHERE user_id = auth.uid()
),
calculated AS (
  SELECT 
    COALESCE(SUM(o.seller_price_cents), 0) - COALESCE(SUM(p.amount_cents), 0) as expected_cents
  FROM orders o
  LEFT JOIN payouts p ON p.user_id = auth.uid() AND p.status IN ('completed', 'processing', 'pending')
  WHERE o.seller_id = auth.uid()
    AND o.payment_status = 'succeeded'
)
SELECT 
  'BALANCE MISMATCH CHECK' as check_name,
  (SELECT available_cents FROM wallet) as database_has_cents,
  (SELECT expected_cents FROM calculated) as should_have_cents,
  (SELECT available_cents FROM wallet) - (SELECT expected_cents FROM calculated) as difference_cents,
  CASE 
    WHEN (SELECT available_cents FROM wallet) != (SELECT expected_cents FROM calculated) 
    THEN '⚠️ MISMATCH DETECTED'
    ELSE '✅ Database is correct'
  END as status;

