# Complete Money Flow Test

## Goal
Verify that money flows correctly from buyer → seller → bank account with NO leaks.

---

## Prerequisites
- [ ] Database migration run (`add_payout_tracking.sql`)
- [ ] Edge Function deployed (`process_payout`)
- [ ] Environment variable set (`STRIPE_SECRET_KEY`)
- [ ] Stripe Connect completed (test bank account)
- [ ] Using TEST Stripe keys (not live)

---

## Test Scenario: $10 Full Cycle

### Phase 1: Buyer Purchases Item ($10)

**Step 1.1: Setup**
```sql
-- Give buyer $10 wallet credits
UPDATE wallets
SET available_cents = 1000
WHERE user_id = 'BUYER_USER_ID';

-- Check seller's starting balance
SELECT available_cents FROM wallets WHERE user_id = 'SELLER_USER_ID';
-- Record this: SELLER_START_BALANCE
```

**Step 1.2: Make Purchase**
- Buyer: Open app → Browse listings
- Find $10 item from seller
- Select "Pay with Wallet"
- Confirm purchase

**Step 1.3: Verify Deduction**
```sql
-- Buyer's wallet should be $0 now
SELECT available_cents FROM wallets WHERE user_id = 'BUYER_USER_ID';
-- Expected: 0

-- Order should exist
SELECT id, buyer_id, seller_id, price_cents, order_status, payment_method
FROM orders
WHERE buyer_id = 'BUYER_USER_ID'
ORDER BY created_at DESC LIMIT 1;
-- Expected: payment_method = 'wallet', order_status = 'placed'
```

**✅ Checkpoint 1**: Buyer's $10 deducted, order created

---

### Phase 2: Seller Delivers & Buyer Confirms

**Step 2.1: Seller Marks Delivered**
- Seller: Open app → Orders → Mark as Delivered
- Upload delivery photo
- Confirm

**Step 2.2: Buyer Confirms Receipt**
- Buyer: Open app → Orders → View Order
- Tap "Confirm Received"
- Confirm

**Step 2.3: Verify Escrow Release**
```sql
-- Order should be completed
SELECT order_status, payment_status FROM orders 
WHERE id = 'ORDER_ID';
-- Expected: order_status = 'completed', payment_status = 'released'

-- Seller's wallet should have increased
SELECT available_cents FROM wallets WHERE user_id = 'SELLER_USER_ID';
-- Expected: SELLER_START_BALANCE + 1000 (assuming no fees)
-- Note: Actual amount might be slightly less due to marketplace fees
```

**✅ Checkpoint 2**: Money released to seller's wallet

---

### Phase 3: Seller Requests Payout

**Step 3.1: Request Payout**
- Seller: Open app → Wallet → Request Payout
- Amount: $10 (or full balance)
- Select: Standard (2-3 days)
- Select: Bank Account
- Tap "Request Payout"

**Step 3.2: Check Console Logs**
Look for:
```
💳 Processing wallet payment - deducting X cents
🔄 Calling process_payout Edge Function for payout: [UUID]
✅ Payout processing initiated. Stripe Payout ID: po_xxxxx
```

**Step 3.3: Verify Database**
```sql
-- Payout should exist with Stripe ID
SELECT 
    id, 
    status, 
    stripe_payout_id, 
    amount_cents,
    created_at
FROM payouts
WHERE user_id = 'SELLER_USER_ID'
ORDER BY created_at DESC LIMIT 1;

-- CRITICAL CHECKS:
-- ✅ status should be 'processing' (NOT 'pending')
-- ✅ stripe_payout_id should be 'po_xxxxx...' (NOT NULL)
-- ❌ If status = 'pending' AND stripe_payout_id IS NULL → FAILED!
```

**Step 3.4: Verify Wallet**
```sql
-- Seller's wallet should be reduced
SELECT available_cents FROM wallets WHERE user_id = 'SELLER_USER_ID';
-- Expected: Previous balance - 1000
```

**Step 3.5: Verify Stripe Dashboard**
- Go to: https://dashboard.stripe.com/test/connect/payouts
- Should see payout listed
- Status: "in transit" or "paid"

**✅ Checkpoint 3**: Payout processed, Stripe called, money on the way

---

### Phase 4: Final Verification

**Step 4.1: Money Flow Audit**
```sql
-- Run the complete verification
-- (Copy from VERIFY_MONEY_FLOW.sql)

-- Check these key metrics:
SELECT 
    'Buyer Wallet' as account,
    available_cents::float / 100 as dollars
FROM wallets WHERE user_id = 'BUYER_USER_ID'
UNION ALL
SELECT 
    'Seller Wallet',
    available_cents::float / 100
FROM wallets WHERE user_id = 'SELLER_USER_ID'
UNION ALL
SELECT 
    'Total in System',
    SUM(available_cents)::float / 100
FROM wallets;
```

**Expected Results:**
- Buyer: $0 (paid $10)
- Seller: ~$0 (received $10, then cashed out)
- Total in System: ~$0 (money moved out to bank)

**Step 4.2: Check for Leaks**
```sql
-- No stuck payouts
SELECT COUNT(*) as stuck_count
FROM payouts
WHERE status = 'pending'
AND stripe_payout_id IS NULL;
-- Expected: 0

-- No negative balances
SELECT COUNT(*) as negative_count
FROM wallets
WHERE available_cents < 0;
-- Expected: 0

-- Order and payout match
SELECT 
    o.price_cents as order_amount,
    p.amount_cents as payout_amount,
    o.price_cents - p.amount_cents as difference
FROM orders o
JOIN payouts p ON o.seller_id = p.user_id
WHERE o.id = 'ORDER_ID'
AND p.created_at > o.created_at
ORDER BY p.created_at DESC LIMIT 1;
-- Expected: difference should equal marketplace fees
```

**✅ Checkpoint 4**: No money lost, all accounted for

---

## Success Criteria

All of these must be true:

- [x] **Buyer Payment**: $10 deducted from wallet ✅
- [x] **Seller Receipt**: $10 added to seller's wallet (minus fees) ✅
- [x] **Payout Request**: Created payout record ✅
- [x] **Stripe Integration**: stripe_payout_id is NOT NULL ✅
- [x] **Payout Status**: Status is 'processing' (not 'pending') ✅
- [x] **Stripe Dashboard**: Payout visible ✅
- [x] **No Leaks**: No stuck payouts ✅
- [x] **No Negative Balances**: All wallets ≥ 0 ✅

---

## Failure Scenarios & Fixes

### ❌ Buyer wallet not deducted
**Problem**: Bug in OrderService.createOrder()
**Fix**: Already fixed in latest code
**Verify**: Check line 97-153 in OrderService.swift

### ❌ Seller wallet not increased
**Problem**: Escrow release not working
**Fix**: Verify confirmDelivery() calls releaseEscrowFunds()
**Test**: Check order status is 'completed' and payment_status is 'released'

### ❌ Payout stuck (stripe_payout_id is NULL)
**Problem**: Edge Function not deployed or failed
**Fix**: 
1. Check Edge Function is deployed
2. Check STRIPE_SECRET_KEY is set
3. Check Edge Function logs in Supabase
**Refund**: Run REFUND_STUCK_PAYOUTS.sql

### ❌ Payout not in Stripe Dashboard
**Problem**: Wrong Stripe key (test vs live mismatch)
**Fix**: 
1. Check app is using pk_test_... (test mode)
2. Check Edge Function has sk_test_... (test mode)
3. Or vice versa for live mode
4. Make sure they match!

---

## Timeline Expectations

| Event | When | Status |
|-------|------|--------|
| Buyer pays | Immediate | Wallet deducted |
| Order created | Immediate | Database record |
| Seller delivers | Manual | Seller action |
| Buyer confirms | Manual | Buyer action |
| Escrow release | Immediate | Wallet increased |
| Payout requested | Manual | Seller action |
| Stripe called | Immediate | Edge Function |
| Money in bank | 2-3 days | Stripe processing |

**Total time**: A few minutes (manual steps) + 2-3 days (Stripe)

---

## Post-Test Cleanup

```sql
-- Mark test data (optional)
UPDATE orders SET order_status = 'cancelled'
WHERE buyer_id = 'TEST_BUYER_ID'
AND created_at > NOW() - INTERVAL '1 hour';

UPDATE payouts SET status = 'cancelled'
WHERE user_id = 'TEST_SELLER_ID'
AND created_at > NOW() - INTERVAL '1 hour';
```

---

## Notes

- Use TEST Stripe keys for all testing
- Real money won't be transferred in test mode
- Test mode payouts show in Stripe Dashboard but don't actually pay out
- Switch to LIVE mode only after all tests pass
- In live mode, real money will be transferred!

---

**If all checkpoints pass, your money flow is working perfectly!** ✅

