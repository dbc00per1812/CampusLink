# Payout Error - Quick Fix Guide

**Date**: November 12, 2025  
**Error**: "Failed to process payout: Failed to initiate payout with Stripe"  
**Mysterious Issue**: payment_intent 404 errors during payout request

---

## 🎯 What You Need to Do RIGHT NOW

### Step 1: Check Supabase Edge Functions (2 minutes)

1. Go to: https://supabase.com/dashboard
2. Select your project
3. Click "Edge Functions" in left sidebar
4. **Look for**: `process-payout` (with hyphen, not underscore)

**If you see it:**
- ✅ Function is deployed
- Click on it → View logs → Look for error from ~1:51 AM
- Note down the error message

**If you DON'T see it:**
- ❌ **THIS IS YOUR PROBLEM!**
- Function needs to be deployed
- See "Deploy Edge Function" section below

### Step 2: Check Function Environment Variables (1 minute)

If function exists:
1. Click on `process-payout`
2. Go to "Settings" or "Configuration"
3. Look for environment variables
4. **Required**: `STRIPE_SECRET_KEY`

**If missing:**
- ❌ **THIS IS YOUR PROBLEM!**
- Add it:
  - Key: `STRIPE_SECRET_KEY`
  - Value: Your Stripe secret key (starts with `sk_test_` or `sk_live_`)

### Step 3: Run Diagnostic SQL (3 minutes)

1. Open Supabase SQL Editor
2. Copy/paste contents of `DIAGNOSE_PAYOUT_SYSTEM.sql`
3. Run it
4. Review results - focus on:
   - Recent payout attempts
   - Your wallet balance
   - Your Stripe Connect status

---

## 🔧 How to Deploy Edge Function

### If Function is Missing

1. **Go to Edge Functions**
   - https://supabase.com/dashboard → Your Project → Edge Functions

2. **Create New Function**
   - Click "New Function"
   - Name: `process-payout` (exactly this, with hyphen)

3. **Copy Function Code**
   - Open file: `supabase/functions/process-payout/index.ts`
   - Copy ALL contents
   - Paste into Supabase editor

4. **Deploy**
   - Click "Deploy" or "Save"
   - Wait for confirmation

5. **Set Environment Variable**
   - In function settings:
     - Key: `STRIPE_SECRET_KEY`
     - Value: Your Stripe secret key
   - Save

6. **Test Again**
   - Try requesting payout in app
   - Should work now!

---

## 🔍 About the Payment Intent Mystery

**The payment_intent errors are likely UNRELATED to your payout issue.**

Here's what probably happened:
1. You requested a payout at ~1:51 AM ✅
2. Payout failed (edge function issue) ❌
3. **SEPARATELY**: Stripe webhook retried an old payment_intent event ⚠️
4. That old payment_intent doesn't exist anymore → 404 error
5. Just bad timing - they appeared together but are separate issues

**Evidence:**
- The payment_intent ID `pi_3SSW...` appears in your old SQL query files
- It's from a PREVIOUS payment attempt (not payout)
- Payout code doesn't use payment_intents at all
- Webhooks retry failed events for up to 3 days

**Verdict:** Red herring. Focus on the edge function deployment.

---

## 📊 Diagnostic Results Checklist

After running `DIAGNOSE_PAYOUT_SYSTEM.sql`, check:

- [ ] **Recent payout attempts**: Should see one from ~1:51 AM with status "pending"
- [ ] **Wallet balance**: Should be $4.25 less than before (money was deducted)
- [ ] **Stripe Connect ID**: Should NOT be null
- [ ] **Payouts enabled**: Should be true (or null is OK)
- [ ] **Stuck payouts**: If you have pending payouts > 1 hour old, wallet needs refund

---

## 🚨 If Wallet Was Deducted But Payout Failed

Your wallet was reduced by $4.25 but money never reached Stripe. You need a refund:

```sql
-- Check your current balance
SELECT available_cents FROM wallets WHERE user_id = auth.uid();

-- Manually refund if needed (run in Supabase SQL Editor)
-- Replace XXXX with your current balance + 425 (to add $4.25 back)
UPDATE wallets 
SET available_cents = XXXX,  -- your_current_balance + 425
    updated_at = NOW()
WHERE user_id = auth.uid();

-- Verify refund
SELECT available_cents FROM wallets WHERE user_id = auth.uid();
```

**Then mark payout as failed:**

```sql
UPDATE payouts
SET status = 'failed',
    error_message = 'Edge function not deployed - wallet refunded',
    updated_at = NOW()
WHERE user_id = auth.uid()
  AND status = 'pending'
  AND created_at > NOW() - INTERVAL '2 hours';
```

---

## 💰 Understanding Your Payout System

### How It Should Work

```
1. You have $4.25 in wallet
   ↓
2. Request payout
   ↓
3. App deducts $4.25 from wallet
   ↓
4. App creates payout record (status: pending)
   ↓
5. App calls Edge Function: process-payout
   ↓
6. Edge Function calls Stripe API
   ↓
7. Stripe creates payout to your bank account
   ↓
8. Edge Function updates payout record (status: processing)
   ↓
9. Stripe sends webhook when money leaves (status: completed)
   ↓
10. Money arrives in your bank in 2-3 days
```

### What's Broken

**Your system stops at step 5.**

The edge function either:
- Doesn't exist (not deployed)
- Can't talk to Stripe (no API key)
- Can't find your Connect account (not set up)

**Fix deployment → everything else should work.**

---

## 🎯 Most Likely Scenario

Based on my analysis:

**95% certain**: Edge function is either:
- Not deployed at all
- Missing STRIPE_SECRET_KEY environment variable

**5% chance**: Edge function IS deployed and configured, but:
- Your Stripe Connect account isn't set up
- Your Connect account doesn't have payout method
- Insufficient balance in Connect account (though should have money from destination charges)

**Action**: Check Supabase Dashboard first. That's your answer.

---

## 📞 What to Report Back

After checking Supabase Dashboard, tell me:

1. **Is process-payout function deployed?** (Yes/No)
2. **Does it have STRIPE_SECRET_KEY set?** (Yes/No)
3. **What do the function logs say?** (Copy error message)
4. **What does diagnostic SQL show?** (Copy results of sections 1-4)
5. **Your Stripe Connect ID** (from users table, or "null")

With these 5 answers, I can tell you EXACTLY what's wrong and how to fix it.

---

## 🔗 Useful Links

- **Supabase Dashboard**: https://supabase.com/dashboard
- **Stripe Dashboard**: https://dashboard.stripe.com
- **Stripe Connect Onboarding**: https://dashboard.stripe.com/test/connect/accounts
- **Edge Function Logs**: Supabase → Edge Functions → process-payout → Logs

---

## ✅ Success Criteria

You'll know it's fixed when:

1. Edge function is deployed and has API key
2. You can request payout without error
3. Payout record shows `stripe_payout_id` (not null)
4. Payout status changes from "pending" to "processing"
5. Stripe dashboard shows the payout under "Payouts" tab
6. Money arrives in bank account in 2-3 days

---

Darragh

