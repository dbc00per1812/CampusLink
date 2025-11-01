-- Refund ALL Stuck Payouts Script
-- This returns money from failed/stuck payouts back to user wallets

-- IMPORTANT: Review the payouts first before running this!
-- Run VERIFY_MONEY_FLOW.sql first to see what will be refunded

-- ========================================
-- STEP 1: PREVIEW - See what will be refunded
-- ========================================

SELECT 
    'PREVIEW: Will refund these payouts' as action,
    p.id as payout_id,
    p.user_id,
    u.email,
    u.name,
    p.amount_cents,
    p.amount_cents::float / 100 as amount_dollars,
    w.available_cents as current_wallet_cents,
    w.available_cents::float / 100 as current_wallet_dollars,
    (w.available_cents + p.amount_cents)::float / 100 as new_wallet_dollars,
    p.status,
    p.created_at
FROM payouts p
LEFT JOIN users u ON p.user_id = u.id
LEFT JOIN wallets w ON p.user_id = w.user_id
WHERE p.status = 'pending'
AND p.stripe_payout_id IS NULL
ORDER BY p.created_at;

-- ========================================
-- STEP 2: REFUND - Uncomment to execute
-- ========================================

-- UNCOMMENT THE LINES BELOW TO ACTUALLY RUN THE REFUND

/*
BEGIN;

-- Refund all stuck payouts back to wallets
WITH stuck_payouts AS (
    SELECT id, user_id, amount_cents
    FROM payouts
    WHERE status = 'pending'
    AND stripe_payout_id IS NULL
)
UPDATE wallets w
SET available_cents = w.available_cents + sp.amount_cents,
    updated_at = NOW()
FROM stuck_payouts sp
WHERE w.user_id = sp.user_id;

-- Mark all stuck payouts as failed
UPDATE payouts
SET status = 'failed',
    updated_at = NOW()
WHERE status = 'pending'
AND stripe_payout_id IS NULL;

-- Show what was refunded
SELECT 
    'REFUNDED' as result,
    id as payout_id,
    user_id,
    amount_cents,
    amount_cents::float / 100 as amount_dollars
FROM payouts
WHERE status = 'failed'
AND updated_at > NOW() - INTERVAL '1 minute';

COMMIT;
*/

-- ========================================
-- STEP 3: VERIFY - Check balances after refund
-- ========================================

-- Run this after uncommenting and executing Step 2
SELECT 
    'AFTER REFUND' as check_type,
    w.user_id,
    u.email,
    w.available_cents::float / 100 as wallet_balance_dollars,
    COUNT(p.id) as failed_payouts_count,
    SUM(p.amount_cents)::float / 100 as total_refunded_dollars
FROM wallets w
LEFT JOIN users u ON w.user_id = u.id
LEFT JOIN payouts p ON w.user_id = p.user_id 
    AND p.status = 'failed' 
    AND p.updated_at > NOW() - INTERVAL '5 minutes'
GROUP BY w.user_id, u.email, w.available_cents
HAVING COUNT(p.id) > 0
ORDER BY w.available_cents DESC;

-- ========================================
-- IMPORTANT NOTES
-- ========================================

-- 1. This script is SAFE to run multiple times
--    - It only affects payouts with status='pending' AND stripe_payout_id IS NULL
--    - Once marked as 'failed', they won't be touched again
--
-- 2. Users will see their wallet balance increase
--    - They can request payout again (will work this time!)
--
-- 3. The failed payouts remain in the database for audit trail
--    - Status = 'failed' means "refunded to wallet"
--
-- 4. After running this:
--    - All users should request payout again
--    - This time it will actually work (Stripe API will be called)

