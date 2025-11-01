# Fix Stripe Webhook URL - URGENT

## Problem

Your Stripe webhook is failing because there's a URL mismatch:

- **Stripe is calling**: `https://vnmzjluyctlufnzxast.supabase.co/functions/v1/stripe_webhook` (underscore)
- **Your function is deployed as**: `stripe-webhook` (hyphen)

This causes a 500 error showing "Missing STRIPE_WEBHOOK_SECRET" because the function isn't even being reached.

## Solution (2 minutes)

### Go to Stripe Dashboard and Update the Webhook URL

1. **Open Stripe Dashboard**
   - Go to: https://dashboard.stripe.com/webhooks
   - Or for test mode: https://dashboard.stripe.com/test/webhooks

2. **Find your webhook**
   - Look for the webhook named "whimsical-finesse" (as shown in your screenshot)
   - Click on it

3. **Update the URL**
   - Click "Edit endpoint" or "..."  menu → "Update details"
   - Change the URL from:
     ```
     https://vnmzjluyctlufnzxast.supabase.co/functions/v1/stripe_webhook
     ```
   - To:
     ```
     https://vnmzjluyctlufnzxast.supabase.co/functions/v1/stripe-webhook
     ```
   - Click "Update endpoint"

4. **Test it**
   - Click "Send test webhook"
   - Select event: `payout.paid`
   - Click "Send test webhook"
   - You should see: ✅ **200 OK** instead of 500 error

## Why This Happened

Supabase functions use hyphens in their URLs, but the webhook was configured with an underscore. The function exists and is working fine - Stripe was just calling the wrong address!

## Verify Environment Variables (Already Set Correctly)

You mentioned you already have the webhook secret set in Supabase. Just to confirm it's correct:

1. Go to Supabase Dashboard → Edge Functions → `stripe-webhook` → Secrets
2. Verify these are set:
   - `STRIPE_SECRET_KEY` (sk_live_... or sk_test_...)
   - `STRIPE_WEBHOOK_SECRET` (whsec_...)
   - `SUPABASE_URL` (should be auto-set)
   - `SUPABASE_SERVICE_ROLE_KEY` (should be auto-set)

## After Fix

Once the URL is updated:
- ✅ Webhooks will work immediately
- ✅ Payout status will update automatically
- ✅ No more 500 errors
- ✅ Users will see accurate payout information

---

**Time to fix**: 2 minutes
**Impact**: Critical - fixes all webhook failures

