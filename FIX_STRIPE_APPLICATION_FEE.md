# Fix: Stripe Application Fee Calculation for Destination Charges

**Date**: November 7, 2025  
**Priority**: 🔴 **CRITICAL** - Sellers receiving 2.24x too much, platform losing money on every transaction  
**Environment**: Production (Live Mode)

---

## The Problem

### What Was Happening
When using **destination charges** (seller with completed Stripe Connect onboarding):

**Example: $0.25 listing**
```
❌ OLD CALCULATION (BROKEN):
Buyer pays: $1.00
Application fee to platform: $0.44 (just the round-up amount)
Seller receives: $1.00 - $0.44 = $0.56 ❌ WRONG!
  → Seller should get: $0.25
  → Seller got extra: $0.31

Platform receives: $0.44
Stripe fee deducted from platform: $0.33
Platform net: $0.44 - $0.33 = $0.11
  → Platform should get: $0.44
  → Platform lost: $0.33
```

**Result**: Platform loses $0.33 per transaction, seller gets paid 2.24x their listing price!

---

## Root Cause

### How Stripe Destination Charges Work

With destination charges, Stripe automatically routes money:
```
Payment Intent created with:
- amount: $1.00
- application_fee_amount: $0.44
- transfer_data.destination: seller's Connect account

When captured:
1. Stripe takes processing fee (~$0.33) from the TOTAL
2. Stripe sends application_fee_amount ($0.44) to platform
3. Remainder goes to seller: $1.00 - $0.44 = $0.56
```

**The issue**: `application_fee_amount` was set to `campusLinkCutCents` (just the round-up profit), but it should be **everything except the seller's listing price**.

---

## The Solution

### New Calculation

```typescript
// OLD (BROKEN):
const application_fee_amount = campusLinkCutCents; // Just round-up ($0.44)

// NEW (FIXED):
const application_fee_amount = buyerPriceCents - sellerPriceCents; // Everything except seller price ($0.75)
```

### Example: $0.25 listing

```
✅ NEW CALCULATION (FIXED):
Buyer pays: $1.00
Application fee to platform: $0.75
  → Covers: Stripe fee ($0.31) + round-up profit ($0.44)
Seller receives: $1.00 - $0.75 = $0.25 ✅ CORRECT!

Platform receives: $0.75
Stripe fee deducted from platform: $0.33 (estimated)
Platform net: $0.75 - $0.33 = $0.42
  → Close to intended $0.44 (slight variance due to actual Stripe fee)
```

---

## Code Changes

### Files Modified

1. **`supabase/functions/create_payment_intent/index.ts`**
2. **`supabase_functions/create_payment_intent/index.ts`** (duplicate)

### Changes Made

**Lines 145-164** - Updated fee calculations:
```typescript
// BEFORE:
const campusLinkCutCents = buyerPriceCents - subtotalCents;
const sellerReceivesCents = buyerPriceCents - campusLinkCutCents - stripeFeeCents;

// AFTER:
const campusLinkCutCents = buyerPriceCents - subtotalCents;  // Still track this for escrow mode

// For destination charges: application fee = everything except seller's listing price
const applicationFeeCents = buyerPriceCents - sellerPriceCents;

// Seller receives exactly their listing price with destination charges
const sellerReceivesCents = sellerPriceCents;
```

**Line 195** - Fixed application_fee_amount:
```typescript
// BEFORE:
paymentIntentParams.application_fee_amount = campusLinkCutCents;

// AFTER:
paymentIntentParams.application_fee_amount = applicationFeeCents;
```

**Lines 174-183** - Added application_fee_cents to metadata:
```typescript
metadata: {
  // ... other fields ...
  campuslink_cut_cents: campusLinkCutCents.toString(),
  application_fee_cents: applicationFeeCents.toString(),  // NEW
  seller_receives_cents: sellerReceivesCents.toString(),
}
```

**Lines 198-201** - Updated console logs:
```typescript
console.log("✅ Using DESTINATION CHARGES:");
console.log(`   → Seller receives: $${sellerReceivesCents / 100} (their listing price)`);
console.log(`   → Application fee to platform: $${applicationFeeCents / 100}`);
console.log(`   → Platform net after Stripe fee: ~$${(applicationFeeCents - stripeFeeCents) / 100}`);
```

---

## Money Flow Before vs After

### Before Fix (BROKEN)

**$0.25 listing:**
```
Buyer → Stripe: $1.00
    ↓
Platform gets: $0.44 application fee
    ↓
Seller gets: $0.56 (WRONG - should be $0.25!)
    ↓
Stripe deducts from platform: $0.33
    ↓
Platform net: $0.11 (LOSS of $0.33!)
```

### After Fix (WORKING)

**$0.25 listing:**
```
Buyer → Stripe: $1.00
    ↓
Platform gets: $0.75 application fee
    ↓
Seller gets: $0.25 (CORRECT!)
    ↓
Stripe deducts from platform: $0.33
    ↓
Platform net: $0.42 (close to intended $0.44)
```

---

## Impact Analysis

### Before Fix
- **Per $0.25 transaction**:
  - Seller overpaid: +$0.31 (224% of listing price!)
  - Platform underpaid: -$0.33 (75% loss!)
  
- **Per $10.00 transaction**:
  - Buyer pays: $11.00 (rounded up from $10.59)
  - Seller should get: $10.00
  - Seller WAS getting: $10.59 (+$0.59 overpayment!)
  - Platform WAS getting: $0.41 - $0.32 = $0.09 (should be ~$0.41)

### After Fix
- **Per $0.25 transaction**:
  - Seller gets: $0.25 ✅
  - Platform gets: ~$0.42 ✅
  
- **Per $10.00 transaction**:
  - Buyer pays: $11.00
  - Seller gets: $10.00 ✅
  - Platform gets: ~$0.68 ✅ (after Stripe's $0.32 fee)

---

## Deployment

### 🚨 Critical: This is a BACKEND change!

**Files to Deploy**:
- `supabase/functions/create_payment_intent/index.ts`

### Deployment Steps

#### Option 1: Using Supabase CLI (Recommended)

```bash
# Navigate to project directory
cd /Users/eileenmurphy/CampusLink

# Deploy the updated function
supabase functions deploy create_payment_intent

# Verify deployment
supabase functions list
```

#### Option 2: Via Supabase Dashboard

1. Go to: https://supabase.com/dashboard
2. Select your CampusLink project
3. Navigate to: **Edge Functions**
4. Find: `create_payment_intent`
5. Click: **Deploy new version**
6. Upload the updated `index.ts` file
7. Click: **Deploy**

### Verification

After deployment, create a test listing and purchase to verify:

**Test Case: $0.25 listing**
```sql
-- Check the payment metadata in Stripe dashboard
-- Look for: application_fee_cents = 75
-- Seller should receive: $0.25
-- Platform should receive: $0.75 (minus Stripe fee)
```

---

## Testing Checklist

### Test 1: Small Amount ($0.25)
- [ ] Create listing: $0.25
- [ ] Complete purchase (buyer pays $1.00)
- [ ] Verify seller receives: $0.25
- [ ] Verify platform application fee: $0.75
- [ ] Verify Stripe fee: ~$0.33

### Test 2: Medium Amount ($10.00)
- [ ] Create listing: $10.00
- [ ] Complete purchase (buyer pays $11.00)
- [ ] Verify seller receives: $10.00
- [ ] Verify platform application fee: $1.00
- [ ] Verify Stripe fee: ~$0.32

### Test 3: Large Amount ($50.00)
- [ ] Create listing: $50.00
- [ ] Complete purchase (buyer pays $52.00)
- [ ] Verify seller receives: $50.00
- [ ] Verify platform application fee: $2.00
- [ ] Verify Stripe fee: ~$1.50

---

## Escrow Mode (Unchanged)

This fix **only affects destination charges** (sellers with completed Stripe onboarding).

**Escrow mode** (sellers without onboarding) is **unchanged**:
- Money goes to platform Stripe account
- Seller wallet credited with: `sellerPriceCents - campusLinkCutCents`
- Platform holds funds until seller completes onboarding

---

## Production Safety

### What Could Go Wrong?

❌ **If deployment fails**: Previous (broken) code continues running
  - **Impact**: Platform continues losing money
  - **Fix**: Retry deployment

❌ **If deployed with bugs**: Sellers might get wrong amount
  - **Impact**: Could overpay or underpay sellers
  - **Fix**: Rollback to previous version, investigate

### Rollback Plan

If issues occur after deployment:

```bash
# Rollback to previous version
supabase functions deploy create_payment_intent --version <PREVIOUS_VERSION>

# Or manually restore the old code
# OLD CODE (line 189):
paymentIntentParams.application_fee_amount = campusLinkCutCents;
```

---

## Financial Impact

### Money Lost Before Fix

**If you processed 100 transactions at $0.25 each**:
- Sellers overpaid: 100 × $0.31 = **$31.00 overpaid**
- Platform underpaid: 100 × $0.33 = **$33.00 lost**
- Total platform loss: **$33.00**

**If you processed 100 transactions at $10.00 each**:
- Sellers overpaid: 100 × $0.59 = **$59.00 overpaid**
- Platform underpaid: 100 × $0.32 = **$32.00 lost**
- Total platform loss: **$32.00**

### Money Saved After Fix

✅ Platform receives correct application fee  
✅ Sellers receive exactly their listing price  
✅ No money leakage

---

## Key Takeaway

**The Formula**:
```typescript
// For destination charges with Stripe Connect:
application_fee_amount = buyerPrice - sellerPrice

// NOT:
application_fee_amount = roundUpAmount // ❌ WRONG!
```

**Why**: With destination charges, Stripe automatically routes the remainder to the seller. The application fee must account for ALL platform costs (Stripe fee + profit), not just the profit.

---

## Status
✅ **CODE FIXED** - Ready for deployment  
⏳ **NEEDS DEPLOYMENT** - Must deploy to Supabase Edge Functions

---

**Darragh** - This fix is CRITICAL for production. Every transaction is currently losing you money. Deploy this ASAP using the Supabase CLI or dashboard. The seller will now receive exactly their listing price ($0.25 in your test case), and you'll receive the correct application fee to cover Stripe's processing costs plus your platform profit.

