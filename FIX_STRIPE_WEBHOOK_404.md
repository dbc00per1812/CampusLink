# URGENT: Fix Stripe Webhook 404 Error

## 🚨 Deadline: October 24, 2025 at 10:33:37 PM UTC

Stripe will disable your webhook if not fixed by this date.

---

## What's Wrong?

Your webhook endpoint returns **404 (Not Found)** because the edge function was never created.

**Webhook URL**: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`

**Error**: HTTP 404 - endpoint doesn't exist

**Impact**: 
- ✅ Payouts work and money transfers
- ❌ Status never updates from "processing" → "completed"
- ❌ Users can't see when money arrives

---

## What to Do (15 minutes)

### 1️⃣ Deploy Edge Function (7 min)

1. Go to https://supabase.com/dashboard
2. Select project: **CampusLink** (ID: `vnmzijluyctlufnzxast`)
3. Click **Edge Functions** → **New function**
4. Name: `stripe-webhook`
5. Copy code from: `/Users/eileenmurphy/CampusLink/supabase/functions/stripe-webhook/index.ts`
6. Click **Deploy**

### 2️⃣ Set Environment Variables (2 min)

In function settings, add:

- `STRIPE_SECRET_KEY` = Your Stripe key (sk_test_... or sk_live_...)
- `STRIPE_WEBHOOK_SECRET` = (leave blank for now, get in next step)

### 3️⃣ Get Webhook Secret from Stripe (3 min)

1. Go to https://dashboard.stripe.com/webhooks
2. Find webhook: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`
3. Click on it
4. Find "Signing secret" → Click **Reveal**
5. Copy it (starts with `whsec_...`)

### 4️⃣ Add Secret to Supabase (2 min)

1. Back in Supabase: Edge Functions → stripe-webhook → Secrets
2. Update `STRIPE_WEBHOOK_SECRET` with the value from step 3
3. Save

### 5️⃣ Test It (1 min)

1. In Stripe Dashboard → Webhooks → Your webhook
2. Click **Send test webhook**
3. Select: `payout.paid`
4. Should see: ✅ **200 - Success**

---

## Full Instructions

See: **`DEPLOY_STRIPE_WEBHOOK.md`** for complete guide with troubleshooting

---

## Files Created

✅ `/Users/eileenmurphy/CampusLink/supabase/functions/stripe-webhook/index.ts` - Webhook handler  
✅ `/Users/eileenmurphy/CampusLink/DEPLOY_STRIPE_WEBHOOK.md` - Full deployment guide  
✅ `/Users/eileenmurphy/CampusLink/log.md` - Detailed documentation

---

## What This Fixes

- ✅ Resolves 404 errors
- ✅ Automatic payout status updates
- ✅ Users see when money arrives
- ✅ Better user experience

---

## Questions?

Check `DEPLOY_STRIPE_WEBHOOK.md` for:
- Detailed instructions
- Troubleshooting guide
- Testing procedures
- Monitoring tips

---

**Bottom line**: The webhook handler is ready, just needs to be deployed to Supabase!


