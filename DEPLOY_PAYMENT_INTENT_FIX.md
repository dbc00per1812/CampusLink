# CRITICAL FIX: Deploy Updated create_payment_intent with Destination Charges

## The Problem

Your current `create_payment_intent` function is NOT using destination charges, which causes:
- ❌ Money goes to platform account instead of seller's Connect account
- ❌ No application fee is set, so you don't get your cut automatically
- ❌ When you try to pay out sellers, your platform balance goes negative
- ❌ Accounting is broken because internal wallet doesn't match Stripe balances

## The Solution

The new `create_payment_intent` function uses **Stripe Destination Charges** which:
- ✅ Automatically sends money to seller's Connect account when payment is captured
- ✅ Takes your platform application fee automatically
- ✅ Keeps accounting in sync (seller's Connect balance = seller's internal wallet)
- ✅ Prevents negative platform balances

## How Destination Charges Work

```
Buyer pays $1.00
  ↓
Payment is CAPTURED (when buyer confirms delivery)
  ↓
Stripe automatically splits the money:
  ├─ $0.50 → Seller's Connect account ✅
  ├─ $0.19 → Your platform (application fee) ✅
  └─ $0.31 → Stripe keeps (their processing fee)
```

**Key point:** Money goes DIRECTLY to seller's Connect account, NOT your platform!

## Deployment Steps

### Step 1: Deploy via Supabase CLI

```bash
cd /Users/eileenmurphy/CampusLink
supabase functions deploy create_payment_intent
```

**OR via Supabase Dashboard:**

1. Go to: https://supabase.com/dashboard
2. Select your project
3. Navigate to **Edge Functions** in left sidebar
4. Find `create_payment_intent` function
5. Click **Edit**
6. Replace the ENTIRE function code with the contents of:
   `/Users/eileenmurphy/CampusLink/supabase_functions/create_payment_intent/index.ts`
7. Click **Deploy**

### Step 2: Verify Deployment

Check that the function is deployed:

```bash
supabase functions list | grep create_payment_intent
```

Should show:
```
create_payment_intent | create_payment_intent | ACTIVE | [version] | [date]
```

### Step 3: Test the Complete Flow

**IMPORTANT:** Test with a FRESH transaction (not the old refunded ones):

1. **Create a test listing** (seller price: $0.50)
2. **Buy it with a card** (buyer pays $1.00)
3. **Check Stripe Dashboard:**
   - PaymentIntent should show as "Uncaptured"
   - Amount: $1.00
4. **Seller confirms order** in app
5. **Buyer confirms delivery** in app
   - ✅ This triggers payment capture
   - ✅ Money moves: $0.50 → seller's Connect, $0.20 → platform
6. **Check Stripe Dashboard again:**
   - PaymentIntent status: "Succeeded"
   - Platform balance: Should show +$0.20 (your cut)
   - Seller's Connect account: Should show +$0.50
7. **Seller requests payout** in app
   - ✅ Should work without errors
   - ✅ Money moves from Connect → seller's bank

## What Changed in the Code

### Before (Broken):
```typescript
const paymentIntent = await stripe.paymentIntents.create({
  amount: buyerPriceCents,  // $1.00
  currency: 'usd',
  capture_method: 'manual',
  // ❌ NO destination charges!
  // ❌ NO application fee!
});
```

### After (Fixed):
```typescript
const paymentIntent = await stripe.paymentIntents.create({
  amount: buyerPriceCents,  // $1.00
  currency: 'usd',
  capture_method: 'manual',
  
  // ✅ DESTINATION CHARGE CONFIG:
  on_behalf_of: sellerStripeConnectId,
  transfer_data: {
    destination: sellerStripeConnectId,
  },
  application_fee_amount: campusLinkCutCents,  // Your $0.20 cut
  
  metadata: {
    seller_price_cents: '50',
    buyer_price_cents: '100',
    campuslink_cut_cents: '20',
    // ...
  }
});
```

## Money Flow Diagram

### OLD (Broken) Flow:
```
Buyer pays $1.00
  ↓
Capture → ALL to platform account
  ↓
Platform balance: $0.70 (after Stripe fee)
  ↓
Try to pay seller $0.81
  ↓
Platform balance: -$0.11 ❌ NEGATIVE!
```

### NEW (Fixed) Flow:
```
Buyer pays $1.00
  ↓
Capture → Split automatically:
  ├─ Seller's Connect: $0.50 ✅
  ├─ Platform: $0.20 ✅
  └─ Stripe: $0.30
  ↓
Seller requests payout
  ↓
Payout: Connect → Bank ($0.50) ✅
  ↓
Platform balance stays positive! ✅
```

## Expected Results After Deployment

✅ **Platform balance:** Always positive (only receives application fees)
✅ **Seller Connect balance:** Matches what they're owed
✅ **Payouts:** Work without "insufficient funds" errors
✅ **Your cut:** Automatic $0.01 to $0.99 per transaction
✅ **No negative balances:** Ever!

## Troubleshooting

### If you still see negative balances:

1. **Check Stripe logs:**
   ```
   Dashboard → Developers → Logs
   Look for "application_fee_amount" in PaymentIntent creation
   ```

2. **Verify the new function is deployed:**
   ```bash
   supabase functions list
   ```
   Check the VERSION number increased

3. **Test with a NEW transaction** (old ones won't work correctly)

### If application fee isn't showing:

- Check that seller has completed Connect onboarding
- Verify `stripe_connect_id` is in their user profile in database
- Look at PaymentIntent metadata in Stripe Dashboard

## Questions?

If you see errors or unexpected behavior after deploying:
1. Check the Edge Function logs in Supabase Dashboard
2. Check Stripe Dashboard → Developers → Logs
3. Look for error messages in app console when making payment

---

**Deploy this now to fix your payment flow!**

