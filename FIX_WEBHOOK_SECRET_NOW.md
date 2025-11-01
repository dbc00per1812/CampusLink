# Fix Stripe Webhook Secret - REAL ISSUE

## The Real Problem

You have the function deployed in Supabase, but the **environment variable is missing** on that specific function deployment.

Stripe is calling: `https://vnmzjluyctlufnzxast.supabase.co/functions/v1/stripe_webhook`

The function IS responding (that's why you get a 500 error with JSON), but it's returning:
```json
{
  "error": "Missing STRIPE_WEBHOOK_SECRET"
}
```

This means the `STRIPE_WEBHOOK_SECRET` environment variable is **not set** on that function deployment.

## Quick Fix (3 minutes)

### Step 1: Go to Supabase Dashboard
1. Open: https://supabase.com/dashboard
2. Select project: **CampusLink**
3. Click **Edge Functions** in the left sidebar

### Step 2: Find the Function
Look for a function named either:
- `stripe_webhook` (with underscore)
- OR `stripe-webhook` (with hyphen)

Click on whichever one exists.

### Step 3: Add the Secret
1. In the function details, click **Settings** or **Secrets** tab
2. Add these environment variables:

**Required Variables:**
- **Key**: `STRIPE_WEBHOOK_SECRET`
- **Value**: Your webhook signing secret from Stripe (starts with `whsec_...`)
  
To get this secret:
  1. Go to: https://dashboard.stripe.com/webhooks
  2. Click on your "whimsical-finesse" webhook
  3. Find "Signing secret" 
  4. Click "Reveal" and copy it

Also verify these are set:
- `STRIPE_SECRET_KEY` = Your Stripe key (sk_live_... or sk_test_...)
- `SUPABASE_URL` = (should be auto-set)
- `SUPABASE_SERVICE_ROLE_KEY` = (should be auto-set)

### Step 4: Save and Redeploy (if needed)
1. Click **Save**
2. Some platforms need you to click **Redeploy** or **Deploy** after adding secrets
3. Look for a "Redeploy" or "Deploy" button and click it

### Step 5: Test It
1. Go back to Stripe Dashboard → Webhooks
2. Click on your webhook
3. Click **Send test webhook**
4. Select: `payout.paid`
5. Send it
6. Should now see: ✅ **200 OK** (not 500 error)

## Alternative: Redeploy the Function

If the secret still doesn't work, you might need to redeploy the entire function:

1. **Delete the old function** in Supabase Dashboard
2. **Create a new function**:
   - Name: `stripe_webhook` (with underscore to match Stripe's URL)
   - Copy code from: `/Users/eileenmurphy/CampusLink/supabase/functions/stripe-webhook/index.ts`
3. **Set all environment variables** before or after deployment
4. **Deploy**

## Verify It's Working

After the fix, you should see in Stripe Dashboard:
- ✅ Event deliveries showing **200 OK**
- ✅ No more **500 ERR** messages
- ✅ Webhook status: Active and working

---

**Time to fix**: 3 minutes  
**Impact**: Critical - fixes payout status updates

