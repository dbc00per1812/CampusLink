# Fix Connect Onboarding 500 Error

## Problem

When clicking "Complete Payout Setup", you get error:
```
Failed to start onboarding: Edge Function returned a non-2xx status code: 500
```

## Root Cause

The `connect_onboarding` edge function is missing the `STRIPE_SECRET_KEY` environment variable.

The function exists in Supabase but can't initialize Stripe without the secret key, causing it to return a 500 error.

## Quick Fix (2 minutes)

### Step 1: Go to Supabase Dashboard
1. Open: https://supabase.com/dashboard
2. Select project: **CampusLink** 
3. Click **Edge Functions**

### Step 2: Find connect_onboarding Function
- Look for `connect_onboarding` function
- Click on it

### Step 3: Add Missing Environment Variable
1. Click **Settings** or **Secrets** tab
2. Check if `STRIPE_SECRET_KEY` is set
3. If missing, add it:

   **Key**: `STRIPE_SECRET_KEY`
   **Value**: Your Stripe secret key
   - For **test mode**: `sk_test_...`
   - For **live mode**: `sk_live_...`
   
   Get it from: https://dashboard.stripe.com/apikeys

4. Also verify these are set (should be auto-set):
   - `SUPABASE_URL`
   - `SUPABASE_SERVICE_ROLE_KEY`

### Step 4: Redeploy
Click **Redeploy** or **Deploy** button to apply changes.

### Step 5: Test
1. Go back to your app
2. Click "Complete Payout Setup" again
3. Should open Stripe onboarding successfully

## Check ALL Edge Functions

While you're at it, make sure ALL these functions have `STRIPE_SECRET_KEY` set:

1. ✅ `stripe_webhook` - already fixed
2. ⚠️ `connect_onboarding` - needs fixing
3. `process-payout` - check this too
4. `add-debit-card` - check this too

They all need the same `STRIPE_SECRET_KEY`.

## Alternative: Check Supabase Logs

To see the actual error:

1. Go to Supabase Dashboard → **Logs**
2. Click **Edge Functions** logs
3. Look for recent `connect_onboarding` errors
4. You'll likely see: "Missing STRIPE_SECRET_KEY environment variable"

---

**Time to fix**: 2 minutes  
**Impact**: Critical - enables payout setup for sellers

