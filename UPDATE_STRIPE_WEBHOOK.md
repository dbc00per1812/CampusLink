# Update Stripe Webhook to Handle Payout Events

## 🚨 Issue

You're getting 404 errors because Stripe is trying to send `payout.paid`, `payout.failed`, and `payout.canceled` events, but your current webhook only handles `transfer` events.

**Your `process_payout` function creates payouts** → Stripe sends `payout.*` events  
**Your webhook only listens for transfers** → Stripe gets 404 because those events aren't subscribed

## ✅ Solution

Update your existing webhook to ADD payout event handlers (keeping all existing functionality).

---

## What to Do (10 minutes)

### Step 1: Update Webhook Code in Supabase (5 min)

1. **Go to Supabase Dashboard**
   - Navigate to: https://supabase.com/dashboard
   - Select project: **CampusLink**
   - Click **Edge Functions** → **stripe-webhook**

2. **Replace the Code**
   - Open: `/Users/eileenmurphy/CampusLink/supabase/functions/stripe-webhook/index.ts`
   - Copy the ENTIRE file
   - Paste into Supabase code editor (replacing current code)
   - Click **Deploy**

### Step 2: Update Stripe Webhook Configuration (3 min)

1. **Go to Stripe Dashboard**
   - Live mode: https://dashboard.stripe.com/webhooks
   - OR Test mode: https://dashboard.stripe.com/test/webhooks

2. **Find Your Webhook**
   - URL: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`
   - Click on it

3. **Add New Events**
   - Click **"Edit endpoint"** or **"Listen to events"**
   - Search for and ADD these events:
     - ✅ `payout.paid`
     - ✅ `payout.failed`
     - ✅ `payout.canceled`
   - Keep ALL existing events (payment_intent.*, transfer.*, account.updated, etc.)
   - Click **"Update endpoint"**

### Step 3: Test (2 min)

1. **Send Test Event**
   - In Stripe Dashboard → Webhooks → Your webhook
   - Click **"Send test webhook"**
   - Select: `payout.paid`
   - Should see: ✅ **200 - Success**

2. **Check Logs**
   - Supabase Dashboard → Edge Functions → stripe-webhook → Logs
   - Should see: `💰 Payout completed: po_xxxxx`

---

## What Changed

### Added to Your Existing Webhook

**Three new event handlers**:

1. **`payout.paid`** 
   - Updates `payouts` table: `status = 'completed'`
   - Sets `completed_at` timestamp
   - Finds payout by `stripe_payout_id`

2. **`payout.failed`**
   - Updates `payouts` table: `status = 'failed'`
   - **Automatically refunds wallet balance**
   - Logs failure reason

3. **`payout.canceled`**
   - Updates `payouts` table: `status = 'canceled'`
   - **Automatically refunds wallet balance**

### Kept All Existing Functionality

- ✅ All payment_intent events
- ✅ All transfer events (for Connect transfers)
- ✅ All account.updated events
- ✅ Order creation logic
- ✅ Wallet refund logic
- ✅ All error handling

**Nothing was removed or broken!**

---

## Why Both Transfer AND Payout Events?

You might wonder why we handle both `transfer.*` and `payout.*` events:

**Transfers** (`tr_xxxxx`):
- Move money between Stripe accounts
- Used for Stripe Connect platform transfers
- Your existing functionality

**Payouts** (`po_xxxxx`):
- Move money from Stripe to bank accounts
- Created by `stripe.payouts.create()` in your `process_payout` function
- **This is what was missing!**

Both are needed because you're using both features!

---

## Verification Checklist

After deploying:

- [ ] Code updated in Supabase Edge Functions
- [ ] Function redeployed
- [ ] Events added in Stripe Dashboard: `payout.paid`, `payout.failed`, `payout.canceled`
- [ ] Test webhook sent from Stripe
- [ ] Response: 200 Success
- [ ] Logs show payout event processed
- [ ] 404 errors stop appearing in Stripe

---

## Expected Results

**Before**:
- ❌ Stripe sends payout events → 404 error
- ❌ Payouts stuck in "processing" forever
- ❌ Users can't see when money arrives

**After**:
- ✅ Stripe sends payout events → 200 success
- ✅ Payouts automatically update to "completed"
- ✅ Users see when money arrives
- ✅ Failed payouts auto-refund to wallet
- ✅ No more 404 errors

---

## Quick Comparison

| Feature | Before | After |
|---------|--------|-------|
| Payment events | ✅ Working | ✅ Working |
| Transfer events | ✅ Working | ✅ Working |
| Payout events | ❌ Missing | ✅ Added |
| Wallet refunds (transfers) | ✅ Working | ✅ Working |
| Wallet refunds (payouts) | ❌ None | ✅ Added |
| Auto status updates | ❌ No | ✅ Yes |

---

## Database Schema Note

Your webhook code looks for payouts by **two different fields**:

1. **`stripe_transfer_id`** - For transfer events
2. **`stripe_payout_id`** - For payout events

Make sure your `payouts` table has BOTH columns! If `stripe_payout_id` doesn't exist, run:

```sql
-- Check if column exists
SELECT column_name 
FROM information_schema.columns 
WHERE table_name = 'payouts' 
AND column_name = 'stripe_payout_id';

-- If missing, add it
ALTER TABLE payouts 
ADD COLUMN IF NOT EXISTS stripe_payout_id TEXT;

-- Add index for faster lookups
CREATE INDEX IF NOT EXISTS idx_payouts_stripe_payout_id 
ON payouts(stripe_payout_id);
```

---

## Troubleshooting

### Still Getting 404 Errors?

1. Make sure you clicked **Deploy** in Supabase after updating code
2. Check the function URL matches exactly: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`
3. Verify function shows as "Active" in Supabase Dashboard

### Getting 400 Errors?

1. Check `STRIPE_WEBHOOK_SECRET` is set correctly
2. Make sure you're using the signing secret from the SAME mode (test/live) as your Stripe key

### Webhook Returns 200 But Database Not Updated?

1. Check function logs for warnings like "No payout found"
2. Verify payout record exists with matching `stripe_payout_id`
3. Run:
   ```sql
   SELECT id, status, stripe_payout_id 
   FROM payouts 
   WHERE stripe_payout_id IS NOT NULL
   ORDER BY created_at DESC 
   LIMIT 5;
   ```

---

## That's It!

Just:
1. Deploy updated code (5 min)
2. Add events in Stripe (3 min)
3. Test (2 min)

And your payout system will be fully functional!

**Darragh!** 🚀

