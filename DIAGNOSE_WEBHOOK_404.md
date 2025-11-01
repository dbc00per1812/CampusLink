# Diagnose Stripe Webhook 404 Errors

## You Said the Webhook Is Already Deployed

If the webhook code with payout handlers is already deployed but you're still getting 404 errors from Stripe, here's what's likely wrong:

---

## Most Likely Issue: Events Not Subscribed in Stripe

**The Problem**: Your webhook endpoint exists and works, but Stripe isn't configured to send `payout.*` events to it.

### Check This Right Now:

1. **Go to Stripe Dashboard → Webhooks**
   - Live: https://dashboard.stripe.com/webhooks
   - Test: https://dashboard.stripe.com/test/webhooks

2. **Find your webhook**:
   - URL: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`

3. **Click on it and check "Events to send"**
   
   **Do you see these?**
   - ✅ `payout.paid`
   - ✅ `payout.failed`
   - ✅ `payout.canceled`

   **If NO**: That's your problem! Add them:
   - Click "Edit endpoint"
   - Click "+ Select events"
   - Search for and add: `payout.paid`, `payout.failed`, `payout.canceled`
   - Click "Update endpoint"

---

## Other Possible Issues

### Issue #2: Using Test Mode in One Place, Live Mode in Another

**Check if modes match**:

| Component | Should Be |
|-----------|-----------|
| Stripe Dashboard | Test OR Live (pick one) |
| Webhook in Stripe | Same mode as above |
| App Stripe keys | Same mode as above |
| Supabase `STRIPE_SECRET_KEY` | Same mode as above |

**If mixed**: 
- Test mode webhooks only work with test mode events
- Live mode webhooks only work with live mode events
- You need SEPARATE webhooks for test and live!

### Issue #3: Function Name Mismatch

**Stripe is calling**: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`

**Your function must be named**: `stripe-webhook` (with the hyphen!)

**Check in Supabase**:
1. Go to Edge Functions
2. Look for function named exactly: `stripe-webhook`
3. If it's named differently (like `stripe_webhook` with underscore), rename it or update Stripe URL

### Issue #4: Function Not Deployed in Production

**Check deployment status**:
1. Supabase Dashboard → Edge Functions → stripe-webhook
2. Look for deployment status
3. If it says "Not deployed" or "Draft", click "Deploy"

---

## Quick Test

Run this test RIGHT NOW to see what's actually happening:

### 1. Test from Stripe Dashboard

1. Go to your webhook in Stripe Dashboard
2. Click "Send test webhook"
3. Select: `payout.paid`
4. Click "Send test webhook"

**What do you see?**

#### If you see "✅ 200 - Success":
- Webhook IS working!
- Problem: Events not subscribed (see Issue #1 above)
- OR: Only fails with real events, not test events

#### If you see "❌ 404 - Not Found":
- Webhook endpoint doesn't exist at that URL
- Check function name (Issue #3)
- Check deployment status (Issue #4)
- Check you're in the right Supabase project

#### If you see "❌ 400 - Bad Request":
- Webhook exists but signature verification failed
- Check `STRIPE_WEBHOOK_SECRET` environment variable
- Check test/live mode match (Issue #2)

#### If you see "❌ 500 - Server Error":
- Webhook exists but code has an error
- Check function logs in Supabase
- Check environment variables are set

### 2. Check Function Logs

1. Supabase Dashboard → Edge Functions → stripe-webhook → Logs
2. Send test webhook again
3. Look at logs

**What do you see?**
- Nothing? → Function isn't being called (404)
- Errors? → Function has a problem (post the error)
- Success? → Function works but events not subscribed!

---

## Most Common Solution

**99% of the time**, the issue is:

You already have the webhook for payments and transfers, but you never added the payout events to the subscription list in Stripe Dashboard.

**Fix**:
1. Stripe Dashboard → Webhooks → Your webhook
2. Edit endpoint
3. Add: `payout.paid`, `payout.failed`, `payout.canceled`
4. Save

**That's it!** The 404s will stop immediately.

---

## Why This Happens

Stripe treats "404" as "this endpoint doesn't handle this event type". When you:
- Create a webhook in Stripe Dashboard
- Subscribe to certain events (like `payment_intent.*`, `transfer.*`)
- But DON'T subscribe to `payout.*` events

Then Stripe will:
- Send payment/transfer events → ✅ 200 Success
- Try to send payout events → ❌ 404 Not Found (because you didn't subscribe)

It's NOT that the endpoint doesn't exist - it's that the endpoint isn't subscribed to those specific events!

---

## Action Steps

**Right now, do this**:

1. ✅ Go to Stripe Dashboard webhooks
2. ✅ Find your webhook
3. ✅ Check what events are subscribed
4. ✅ Add `payout.paid`, `payout.failed`, `payout.canceled` if missing
5. ✅ Save
6. ✅ Send test webhook to verify

**Time**: 2 minutes

---

## Still Not Working?

If you've done all the above and still getting 404s, I need more info:

1. Screenshot of your webhook configuration in Stripe Dashboard showing:
   - Webhook URL
   - Events subscribed
   - Recent delivery attempts

2. Screenshot of Supabase Edge Functions showing:
   - Function name
   - Deployment status

3. Result of sending a test webhook from Stripe Dashboard

Then we can debug further!

---

**Most likely**: You just need to add the events in Stripe Dashboard. That's the fix 99% of the time!

**Darragh!** 🚀

