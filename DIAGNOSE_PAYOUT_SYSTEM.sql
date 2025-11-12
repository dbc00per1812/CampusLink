-- PAYOUT SYSTEM DIAGNOSTIC SCRIPT
-- Run this to understand what happened with the failed payout
-- Date: November 12, 2025

-- ========================================
-- SECTION 1: Recent Payout Attempts
-- ========================================

SELECT 
  '=== RECENT PAYOUT ATTEMPTS ===' as section;

SELECT 
  id,
  user_id,
  seller_id,
  amount_cents,
  fee_cents,
  net_amount_cents,
  status,
  payout_type,
  payout_method,
  stripe_payout_id,
  stripe_transfer_id,
  error_message,
  created_at,
  updated_at
FROM payouts
WHERE created_at > NOW() - INTERVAL '24 hours'
ORDER BY created_at DESC;

-- ========================================
-- SECTION 2: Pending/Failed Payouts
-- ========================================

SELECT 
  '=== STUCK PAYOUTS (PENDING/FAILED) ===' as section;

SELECT 
  id,
  user_id,
  amount_cents,
  status,
  error_message,
  created_at,
  EXTRACT(EPOCH FROM (NOW() - created_at))/60 as minutes_ago
FROM payouts
WHERE status IN ('pending', 'failed')
  AND created_at > NOW() - INTERVAL '7 days'
ORDER BY created_at DESC;

-- ========================================
-- SECTION 3: User Wallet Status
-- ========================================

SELECT 
  '=== CURRENT USER WALLET ===' as section;

-- You'll need to replace 'YOUR_USER_ID' with actual user ID
-- Get it from: SELECT auth.uid();

SELECT 
  w.user_id,
  u.email,
  w.available_cents,
  w.pending_cents,
  w.total_cents,
  w.updated_at,
  (w.available_cents / 100.0) as available_dollars
FROM wallets w
JOIN users u ON u.id = w.user_id
WHERE w.user_id = (SELECT auth.uid())
LIMIT 1;

-- ========================================
-- SECTION 4: User's Stripe Connect Status
-- ========================================

SELECT 
  '=== STRIPE CONNECT STATUS ===' as section;

SELECT 
  id,
  email,
  stripe_connect_id,
  stripe_payouts_enabled,
  stripe_details_submitted,
  created_at
FROM users
WHERE id = (SELECT auth.uid())
LIMIT 1;

-- ========================================
-- SECTION 5: All Payout History for User
-- ========================================

SELECT 
  '=== FULL PAYOUT HISTORY ===' as section;

SELECT 
  id,
  amount_cents,
  fee_cents,
  net_amount_cents,
  status,
  payout_type,
  payout_method,
  stripe_payout_id,
  error_message,
  created_at,
  CASE 
    WHEN status = 'completed' THEN '✅'
    WHEN status = 'pending' THEN '⏳'
    WHEN status = 'failed' THEN '❌'
    WHEN status = 'processing' THEN '🔄'
    ELSE '❓'
  END as status_icon
FROM payouts
WHERE user_id = (SELECT auth.uid())
ORDER BY created_at DESC
LIMIT 10;

-- ========================================
-- SECTION 6: Wallet Transaction History
-- ========================================

SELECT 
  '=== WALLET TRANSACTION HISTORY ===' as section;

-- Check for any recent wallet updates
SELECT 
  user_id,
  available_cents,
  total_cents,
  updated_at,
  LAG(available_cents) OVER (ORDER BY updated_at) as previous_balance,
  available_cents - LAG(available_cents) OVER (ORDER BY updated_at) as change_cents
FROM wallets
WHERE user_id = (SELECT auth.uid())
ORDER BY updated_at DESC
LIMIT 10;

-- ========================================
-- SECTION 7: System-Wide Payout Statistics
-- ========================================

SELECT 
  '=== SYSTEM-WIDE PAYOUT STATS ===' as section;

SELECT 
  status,
  COUNT(*) as count,
  SUM(amount_cents) as total_amount_cents,
  SUM(amount_cents) / 100.0 as total_dollars,
  AVG(amount_cents) / 100.0 as avg_dollars,
  MIN(created_at) as oldest,
  MAX(created_at) as newest
FROM payouts
WHERE created_at > NOW() - INTERVAL '30 days'
GROUP BY status
ORDER BY count DESC;

-- ========================================
-- SECTION 8: Check for Data Inconsistencies
-- ========================================

SELECT 
  '=== DATA INCONSISTENCIES ===' as section;

-- Payouts without Stripe IDs but marked as processing/completed
SELECT 
  'Payouts missing Stripe ID' as issue,
  COUNT(*) as count
FROM payouts
WHERE status IN ('processing', 'completed')
  AND stripe_payout_id IS NULL;

-- Payouts that deducted wallet but never processed
SELECT 
  'Pending payouts > 1 hour old' as issue,
  COUNT(*) as count
FROM payouts
WHERE status = 'pending'
  AND created_at < NOW() - INTERVAL '1 hour';

-- Users with negative balances (should never happen)
SELECT 
  'Wallets with negative balance' as issue,
  COUNT(*) as count
FROM wallets
WHERE available_cents < 0;

-- ========================================
-- SECTION 9: Recent Stripe Webhook Events
-- ========================================

SELECT 
  '=== CHECKING FOR WEBHOOK LOGS ===' as section;

-- Note: You'll need to check Supabase Edge Function logs
-- This is just a reminder to check:
SELECT 
  'Check Supabase Dashboard → Edge Functions → stripe-webhook → Logs' as action,
  'Look for payout.* events in the last hour' as what_to_find;

-- ========================================
-- SECTION 10: Recommended Actions
-- ========================================

SELECT 
  '=== RECOMMENDED ACTIONS ===' as section;

SELECT 
  CASE 
    WHEN EXISTS (
      SELECT 1 FROM payouts 
      WHERE status = 'pending' 
      AND created_at > NOW() - INTERVAL '1 hour'
      AND user_id = (SELECT auth.uid())
    ) 
    THEN '⚠️ You have a pending payout from the last hour - wallet may need refund'
    
    WHEN EXISTS (
      SELECT 1 FROM users 
      WHERE id = (SELECT auth.uid())
      AND stripe_connect_id IS NULL
    )
    THEN '❌ Your Stripe Connect account is not set up - complete onboarding first'
    
    WHEN EXISTS (
      SELECT 1 FROM users 
      WHERE id = (SELECT auth.uid())
      AND stripe_payouts_enabled = false
    )
    THEN '⚠️ Your Stripe account is not enabled for payouts - complete verification'
    
    WHEN EXISTS (
      SELECT 1 FROM wallets 
      WHERE user_id = (SELECT auth.uid())
      AND available_cents < 50
    )
    THEN 'ℹ️ Wallet balance is less than $0.50 - minimum payout amount'
    
    ELSE '✅ No obvious issues detected - check edge function logs'
  END as diagnostic_result;

-- ========================================
-- SECTION 11: Payment Intent Investigation
-- ========================================

SELECT 
  '=== PAYMENT INTENT INVESTIGATION ===' as section;

-- Check if the payment intent from error exists in orders
SELECT 
  'Searching for payment_intent: pi_3SSWh6PwXrdA7iH0ijuREfiL' as note;

SELECT 
  id,
  listing_id,
  buyer_id,
  seller_id,
  payment_status,
  stripe_payment_intent_id,
  created_at
FROM orders
WHERE stripe_payment_intent_id = 'pi_3SSWh6PwXrdA7iH0ijuREfiL'
LIMIT 1;

-- If found, this is a payment NOT a payout
-- If not found, the payment intent doesn't exist in our system

-- ========================================
-- END OF DIAGNOSTIC
-- ========================================

SELECT 
  '=== DIAGNOSTIC COMPLETE ===' as section,
  NOW() as run_at;

