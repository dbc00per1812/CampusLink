# ESCROW MODE Problem - Funds Stuck in Platform Account

**Date**: November 12, 2025  
**Issue**: Payout fails with "insufficient funds" error  
**Root Cause**: Payments going to platform account instead of seller's Connect account

---

## 🎯 What's Happening

### Current Flow (ESCROW MODE - Wrong for payouts)

```
1. Buyer pays $5.00
   ↓
2. Check: Is seller's Connect account ready?
   ↓
3. NO → Money goes to PLATFORM account (escrow)
   ↓
4. Platform account: +$5.00 ✅
5. Seller's Connect account: $0.00 ❌
   ↓
6. Seller requests payout
   ↓
7. process-payout tries to payout from SELLER'S Connect account
   ↓
8. Stripe error: "Insufficient funds in YOUR Stripe account" ❌
```

### How It SHOULD Work (DESTINATION CHARGES)

```
1. Buyer pays $5.00
   ↓
2. Check: Is seller's Connect account ready?
   ↓
3. YES → Money goes DIRECTLY to seller's Connect account
   ↓
4. Platform keeps application fee ($0.50)
5. Seller's Connect account: +$4.50 ✅
   ↓
6. Seller requests payout
   ↓
7. process-payout creates payout from seller's Connect account
   ↓
8. SUCCESS! Money transferred to bank ✅
```

---

## 🔍 Why You're in Escrow Mode

Your `create_payment_intent` function checks:

```typescript
if (canUseDestinationCharges && sellerStripeConnectId) {
  // Use destination charges
} else {
  // Use escrow mode
}
```

**You're in escrow mode because ONE of these is false:**

1. ❌ `sellerStripeConnectId` is null/missing
2. ❌ Connect account not fully verified by Stripe
3. ❌ Missing "transfers" capability
4. ❌ Connect account not enabled for charges

---

## ✅ Solution Options

### Option 1: Complete Stripe Connect Onboarding (Recommended)

**This fixes the root cause so future payments work correctly**

1. **Check your Connect account status:**
   ```sql
   -- Run in Supabase SQL Editor
   SELECT 
     stripe_connect_id,
     stripe_payouts_enabled,
     stripe_details_submitted,
     stripe_charges_enabled
   FROM users
   WHERE id = auth.uid();
   ```

2. **If ANY of these are NULL or FALSE:**
   - Go to your Stripe Dashboard
   - Or complete Connect onboarding in your app
   - Submit all required information
   - Wait for Stripe verification (usually instant for test mode)

3. **Verify it worked:**
   - Make a test purchase
   - Check edge function logs for "Using DESTINATION CHARGES"
   - Money should appear in Connect account balance

### Option 2: Transfer Stuck Funds (Immediate Fix)

**This releases the money that's currently stuck in platform account**

#### Step 1: Check Platform Balance

Go to Stripe Dashboard:
1. https://dashboard.stripe.com/test/balance (or /balance for live)
2. Look at "Available balance"
3. You should see the $5.00 (or whatever was paid)

#### Step 2: Create Manual Transfer

You need to create an edge function or manually transfer:

**Quick Manual Transfer via Stripe Dashboard:**
1. Dashboard → Connect → Accounts
2. Find the seller's Connect account
3. Click "Transfer"
4. Enter amount ($4.50 if they sold for $5.00)
5. Submit

**OR create an edge function:**

```typescript
// Manual transfer from platform to seller's Connect account
const transfer = await stripe.transfers.create({
  amount: 450, // $4.50 in cents
  currency: "usd",
  destination: "acct_SELLER_CONNECT_ID",
  description: "Manual transfer for stuck escrow payment"
});
```

#### Step 3: Now Seller Can Payout

After transfer:
- Seller's Connect account has balance
- Seller can request payout
- Should work! ✅

---

## 🔧 Option 3: Fix Payout Function for Escrow Mode

**Change payout to work with escrow mode**

Currently `process-payout` assumes destination charges. For escrow mode, you need:

```typescript
// In process-payout/index.ts

// Check if using destination charges or escrow mode
const { data: recentPayment } = await supabaseAdmin
  .from("orders")
  .select("stripe_payment_intent_id")
  .eq("seller_id", userId)
  .order("created_at", { ascending: false })
  .limit(1)
  .single();

// Get payment intent to check if it used destination charges
const paymentIntent = await stripe.paymentIntents.retrieve(
  recentPayment.stripe_payment_intent_id
);

if (paymentIntent.transfer_data) {
  // DESTINATION CHARGES - money in Connect account
  // Current payout logic works ✅
} else {
  // ESCROW MODE - money in platform account
  // Need to transfer first, then payout
  const transfer = await stripe.transfers.create({
    amount: payout.net_amount_cents,
    currency: "usd",
    destination: userProfile.stripe_connect_id
  });
  
  // Then create payout
  const stripePayout = await stripe.payouts.create({...});
}
```

---

## 📊 Diagnostic Steps

### Step 1: Run Connect Account Status Check

```bash
# In Supabase SQL Editor
# Copy contents of CHECK_CONNECT_ACCOUNT_STATUS.sql and run
```

### Step 2: Check create_payment_intent Logs

1. Supabase Dashboard → Edge Functions → create_payment_intent
2. Click "Logs"
3. Find recent payment creation
4. Look for either:
   - ✅ "Using DESTINATION CHARGES" → Good!
   - ❌ "Using ESCROW MODE" → This is your problem

### Step 3: Check Stripe Balance

1. Stripe Dashboard → Balance
2. Platform "Available balance" section
3. Do you see money there? → It's stuck in escrow

### Step 4: Check Stripe Connect Account Balance

1. Stripe Dashboard → Connect → Accounts
2. Click on your Connect account
3. Look at "Balance"
4. Is it $0? → Confirms escrow mode

---

## 🎯 Recommended Action Plan

**Immediate (Do Now):**

1. ✅ Run `CHECK_CONNECT_ACCOUNT_STATUS.sql`
2. ✅ Check create_payment_intent logs for "ESCROW MODE" message
3. ✅ Check Stripe Dashboard balances (platform vs Connect)

**Short-term (This Week):**

1. ✅ Complete Stripe Connect onboarding if not done
2. ✅ Transfer stuck funds from platform → Connect account
3. ✅ Test payout again (should work after transfer)

**Long-term (Production):**

1. ✅ Ensure all sellers complete Connect onboarding before selling
2. ✅ Update payout function to handle both modes
3. ✅ Add admin dashboard to monitor stuck funds
4. ✅ Set up alerts for escrow mode payments

---

## 💰 Understanding the Money Flow

### Destination Charges (Correct)

```
Buyer pays $5.00
  → Stripe processes payment
  → Platform fee: $0.50 (goes to YOUR platform account)
  → Seller amount: $4.50 (goes to SELLER's Connect account)
  → Seller can withdraw immediately ✅
```

### Escrow Mode (Current Problem)

```
Buyer pays $5.00
  → Stripe processes payment
  → All $5.00 goes to YOUR platform account
  → Seller's Connect account: $0.00
  → Seller tries to withdraw → ERROR ❌
  → You must manually transfer to seller
  → Then seller can withdraw
```

---

## 🚨 Why This Matters

**For Test Mode:**
- Minor inconvenience
- Can fix with manual transfers
- Good learning opportunity

**For Production:**
- **MAJOR ISSUE** - you'd have to manually transfer EVERY payment
- Not scalable
- Legal liability (holding seller funds)
- Poor user experience

**FIX BEFORE GOING LIVE!**

---

## 📞 Next Steps

**Tell me:**

1. **Connect account status** (run the SQL)
2. **What do the create_payment_intent logs say?** (Destination charges or escrow?)
3. **Platform balance in Stripe** (how much stuck?)
4. **Connect account balance in Stripe** ($0 or has money?)

With these 4 answers, I can give you the EXACT fix.

---

Darragh, this is actually a common issue when setting up Stripe Connect. Once your Connect account is fully verified, destination charges will work and payouts will be seamless!


