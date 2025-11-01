-- Complete Money Flow Verification Script
-- Run this to verify end-to-end money flow is working

-- ========================================
-- PART 1: Find Stuck Money (Pre-Fix Issues)
-- ========================================

-- Find all stuck payouts (money in limbo)
SELECT 
    'STUCK PAYOUTS' as check_type,
    p.id as payout_id,
    p.user_id,
    u.email,
    u.name,
    p.amount_cents,
    p.amount_cents::float / 100 as amount_dollars,
    p.status,
    p.payout_method,
    p.stripe_payout_id,
    p.created_at
FROM payouts p
LEFT JOIN users u ON p.user_id = u.id
WHERE p.status = 'pending'
AND p.stripe_payout_id IS NULL  -- No Stripe payout was created
ORDER BY p.created_at DESC;

-- Count total stuck money
SELECT 
    'TOTAL STUCK MONEY' as summary,
    COUNT(*) as stuck_payouts,
    SUM(amount_cents) as total_stuck_cents,
    SUM(amount_cents)::float / 100 as total_stuck_dollars
FROM payouts
WHERE status = 'pending'
AND stripe_payout_id IS NULL;

-- ========================================
-- PART 2: Wallet Balance Check
-- ========================================

-- Check all wallet balances
SELECT 
    'WALLET BALANCES' as check_type,
    w.user_id,
    u.email,
    u.name,
    w.available_cents,
    w.available_cents::float / 100 as available_dollars,
    w.escrow_cents,
    w.escrow_cents::float / 100 as escrow_dollars,
    w.updated_at
FROM wallets w
LEFT JOIN users u ON w.user_id = u.id
ORDER BY w.available_cents DESC;

-- ========================================
-- PART 3: Recent Transaction History
-- ========================================

-- Check recent orders (money flow into system)
SELECT 
    'RECENT ORDERS' as check_type,
    o.id as order_id,
    o.buyer_id,
    buyer.email as buyer_email,
    o.seller_id,
    seller.email as seller_email,
    o.price_cents,
    o.price_cents::float / 100 as price_dollars,
    o.buyer_price_cents::float / 100 as buyer_paid_dollars,
    o.payment_method,
    o.order_status,
    o.payment_status,
    o.created_at,
    o.completed_at
FROM orders o
LEFT JOIN users buyer ON o.buyer_id = buyer.id
LEFT JOIN users seller ON o.seller_id = seller.id
ORDER BY o.created_at DESC
LIMIT 20;

-- ========================================
-- PART 4: Payout History (money flow out)
-- ========================================

-- Check all payouts (successful and failed)
SELECT 
    'ALL PAYOUTS' as check_type,
    p.id as payout_id,
    p.user_id,
    u.email,
    p.amount_cents,
    p.amount_cents::float / 100 as amount_dollars,
    p.net_amount_cents::float / 100 as net_dollars,
    p.fee_cents::float / 100 as fee_dollars,
    p.status,
    p.payout_type,
    p.payout_method,
    p.stripe_payout_id,
    CASE 
        WHEN p.stripe_payout_id IS NOT NULL THEN 'SUCCESS - Stripe called'
        WHEN p.status = 'pending' THEN 'STUCK - No Stripe call'
        ELSE 'UNKNOWN'
    END as verification,
    p.created_at
FROM payouts p
LEFT JOIN users u ON p.user_id = u.id
ORDER BY p.created_at DESC
LIMIT 20;

-- ========================================
-- PART 5: Money Flow Summary
-- ========================================

-- Total money IN (from completed orders)
SELECT 
    'MONEY IN (Orders)' as flow_type,
    COUNT(*) as count,
    SUM(price_cents) as total_cents,
    SUM(price_cents)::float / 100 as total_dollars
FROM orders
WHERE order_status = 'completed'
AND payment_status IN ('succeeded', 'released');

-- Total money OUT (from successful payouts)
SELECT 
    'MONEY OUT (Payouts)' as flow_type,
    COUNT(*) as count,
    SUM(amount_cents) as total_cents,
    SUM(amount_cents)::float / 100 as total_dollars
FROM payouts
WHERE status IN ('completed', 'processing')
AND stripe_payout_id IS NOT NULL;

-- Total money STUCK (pending payouts without Stripe)
SELECT 
    'MONEY STUCK (Failed Payouts)' as flow_type,
    COUNT(*) as count,
    SUM(amount_cents) as total_cents,
    SUM(amount_cents)::float / 100 as total_dollars
FROM payouts
WHERE status = 'pending'
AND stripe_payout_id IS NULL;

-- Total in all wallets
SELECT 
    'MONEY IN WALLETS' as flow_type,
    COUNT(*) as wallet_count,
    SUM(available_cents) as total_available_cents,
    SUM(available_cents)::float / 100 as total_available_dollars,
    SUM(escrow_cents) as total_escrow_cents,
    SUM(escrow_cents)::float / 100 as total_escrow_dollars
FROM wallets;

-- ========================================
-- PART 6: Health Check
-- ========================================

-- Check for anomalies
SELECT 
    'HEALTH CHECK' as check_type,
    'Payouts without Stripe ID' as issue,
    COUNT(*) as count
FROM payouts
WHERE status IN ('completed', 'processing')
AND stripe_payout_id IS NULL
UNION ALL
SELECT 
    'HEALTH CHECK',
    'Negative wallet balances',
    COUNT(*)
FROM wallets
WHERE available_cents < 0
UNION ALL
SELECT 
    'HEALTH CHECK',
    'Orders without payment method',
    COUNT(*)
FROM orders
WHERE payment_method IS NULL;

-- ========================================
-- EXPECTED RESULTS
-- ========================================

-- If everything is working correctly:
-- 1. "STUCK PAYOUTS" should return 0 rows (or show the problem payouts)
-- 2. "ALL PAYOUTS" should show stripe_payout_id for recent payouts
-- 3. "HEALTH CHECK" should show 0 for all anomalies
-- 4. Wallet balances should match (Money IN - Money OUT = Wallets + Stuck)

