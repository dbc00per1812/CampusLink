# Payment System Deep Analysis

**Date**: November 12, 2025  
**Issue**: Payout error + Stripe payment_intent 404 errors  
**User**: Darragh

---

## 🚨 CRITICAL FINDING

You experienced a **payout** error, but Stripe dashboard shows **payment_intent** 404 errors. This is a **MAJOR RED FLAG** - the payout system is trying to access payment intents when it should ONLY be working with payouts.

---

## 📊 Error Analysis

### What Happened

1. **User Action**: Requested payout of $4.25
2. **App Error**: "Failed to process payout: Failed to initiate payout with Stripe. Please contact support."
3. **Stripe Error**: 404 on `/v1/payment_intents/pi_3SSWh6PwXrdA7iH0ijuREfiL`
4. **Error Type**: `resource_missing` - No such payment_intent

### The Mystery

**WHY is there a payment_intent call during a PAYOUT request?**

Payouts should use:
- `stripe.payouts.create()` ✅
- `stripe.accounts.listExternalAccounts()` ✅ (for instant payouts)

Payouts should NEVER use:
- `stripe.paymentIntents.create()` ❌
- `stripe.paymentIntents.retrieve()` ❌
- `stripe.paymentIntents.capture()` ❌

---

## 🔍 System Architecture

### Current Payout Flow

```
1. USER REQUESTS PAYOUT
   ↓
2. PayoutService.swift → requestPayout()
   ↓
3. Creates payout record in database
   ↓
4. Updates wallet balance (deducts amount)
   ↓
5. Calls Edge Function: process-payout
   ↓
6. Edge Function: stripe.payouts.create()
   ↓
7. Updates payout record with stripe_payout_id
   ↓
8. Stripe webhook: payout.paid → mark completed
```

### Where Things Can Go Wrong

**Potential Issue #1: Wrong Edge Function Name**
- Swift code calls: `"process-payout"` (with hyphen)
- Deployed function might be: `"process_payout"` (with underscore)
- This would cause a 404 or fallback to wrong function

**Potential Issue #2: Corrupted Payment Intent Reference**
- The payment_intent ID `pi_3SSWh6PwXrdA7iH0ijuREfiL` appears in:
  - `CHECK_PAYMENT_RECORD.sql` (line 14)
  - `CHECK_WEBHOOK_FIRING.sql` (line 18)
- This suggests it was from a previous payment attempt
- Something might be incorrectly referencing this old payment_intent during payout

**Potential Issue #3: Database Trigger Interference**
- There's a `payout_success_trigger` in the database
- Trigger calls `notify_payout_success()` function
- This function might be doing something unexpected

**Potential Issue #4: Webhook Confusion**
- Stripe webhooks handle both payment_intents AND payouts
- A webhook might be firing for the wrong event type
- Cross-contamination between payment and payout logic

---

## 🧪 Testing Strategy

### Test 1: Check Deployed Function Name

Run this command to see what functions are deployed:

```bash
# Check Supabase edge functions
curl https://YOUR_PROJECT_REF.supabase.co/functions/v1/process-payout \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

Should return CORS or auth error (not 404).

If 404, try:
```bash
curl https://YOUR_PROJECT_REF.supabase.co/functions/v1/process_payout \
  -H "Authorization: Bearer YOUR_ANON_KEY"
```

### Test 2: Check Database State

```sql
-- Check if there are any payout records from the failed attempt
SELECT 
  id,
  user_id,
  amount_cents,
  net_amount_cents,
  status,
  stripe_payout_id,
  stripe_transfer_id,
  error_message,
  created_at
FROM payouts
ORDER BY created_at DESC
LIMIT 5;

-- Check if wallet was deducted
SELECT 
  user_id,
  available_cents,
  pending_cents,
  total_cents,
  updated_at
FROM wallets
WHERE user_id = 'YOUR_USER_ID';
```

### Test 3: Check Stripe Dashboard

1. Go to: https://dashboard.stripe.com/test/logs
2. Filter by last hour
3. Look for:
   - ✅ Payout-related calls (should exist)
   - ❌ Payment intent calls (should NOT exist during payout)

### Test 4: Check Edge Function Logs

1. Go to Supabase Dashboard → Edge Functions
2. Find `process-payout` or `process_payout`
3. View logs from the failed request
4. Look for error stack trace

---

## 🔧 Likely Root Causes (Ranked)

### 1. Edge Function Not Deployed (70% likelihood)
**Symptom**: Function invoke fails, triggers unknown error handler  
**Fix**: Deploy the edge function properly  
**Evidence**: Error message is generic "Please contact support"

### 2. Wrong Function Name (60% likelihood)
**Symptom**: Calls wrong function or 404  
**Fix**: Ensure Swift calls correct function name  
**Evidence**: Two folder naming conventions exist

### 3. Missing Stripe Connect Account (40% likelihood)
**Symptom**: Can't create payout without Connect account  
**Fix**: Verify user has `stripe_connect_id`  
**Evidence**: Function checks for this

### 4. Insufficient Balance in Connect Account (30% likelihood)
**Symptom**: Stripe rejects payout, no funds available  
**Fix**: Money needs to be IN the Connect account first  
**Evidence**: Using destination charges, money should be there

### 5. Database Trigger Corruption (10% likelihood)
**Symptom**: Trigger fires and does something weird  
**Fix**: Check trigger logic  
**Evidence**: Trigger exists but unlikely to cause payment_intent call

---

## 📝 Diagnostic Questions

1. **Is the `process-payout` edge function deployed?**
   - Check Supabase Dashboard → Edge Functions
   - Should see it in the list

2. **Does it have the STRIPE_SECRET_KEY env var?**
   - Check function settings
   - Must be set to work

3. **What's the user's Stripe Connect account status?**
   ```sql
   SELECT 
     id,
     email,
     stripe_connect_id,
     stripe_payouts_enabled,
     stripe_details_submitted
   FROM users
   WHERE id = 'YOUR_USER_ID';
   ```

4. **Was a payout record created?**
   - Check payouts table
   - If yes: DB insert worked, Edge function failed
   - If no: DB insert failed

5. **Was wallet deducted?**
   - Check wallets table
   - If yes: Money is stuck, needs refund
   - If no: No financial impact

---

## 🚀 Action Items (Do These Now)

### Step 1: Verify Edge Function Deployment
```
1. Open Supabase Dashboard
2. Navigate to Edge Functions
3. Look for "process-payout" or "process_payout"
4. If missing → DEPLOY IT
5. If exists → Check logs for errors
```

### Step 2: Check User's Stripe Account
```sql
SELECT 
  users.id,
  users.email,
  users.stripe_connect_id,
  users.stripe_payouts_enabled,
  wallets.available_cents
FROM users
LEFT JOIN wallets ON wallets.user_id = users.id
WHERE users.id = (SELECT user_id FROM supabase.auth.users() LIMIT 1);
```

### Step 3: Check Failed Payout Record
```sql
SELECT *
FROM payouts
WHERE status = 'pending'
  AND created_at > NOW() - INTERVAL '1 hour'
ORDER BY created_at DESC;
```

### Step 4: Review Edge Function Code
```typescript
// File: supabase/functions/process-payout/index.ts
// Verify it exists and contains:
const stripePayout = await stripe.payouts.create(...)
// NOT:
const paymentIntent = await stripe.paymentIntents.create(...)
```

---

## 💡 Recommended Fixes

### Fix 1: Ensure Correct Function Name

**File**: `CampusLink/Core/Services/PayoutService.swift`

Current code (line 173-174):
```swift
let response: ProcessPayoutResponse = try await supabase.functions.invoke(
    "process-payout",  // ← Hyphen
```

Verify deployed function name matches exactly.

### Fix 2: Add Better Error Handling

```swift
do {
    let response: ProcessPayoutResponse = try await supabase.functions.invoke(
        "process-payout",
        options: FunctionInvokeOptions(
            method: .post,
            body: ProcessPayoutRequest(payout_id: payout.id.uuidString)
        )
    )
    
    // ADD THIS: Log the full response
    print("📥 Payout response:", response)
    
    if let error = response.error {
        print("❌ Payout processing failed: \(error)")
        throw PayoutServiceError.processingFailed(error)
    }
} catch {
    // ADD THIS: Log the full error
    print("❌ Full error details:", error)
    print("❌ Error type:", type(of: error))
    throw PayoutServiceError.processingFailed("Failed to initiate payout with Stripe. Please contact support.")
}
```

### Fix 3: Refund Wallet if Payout Failed

```swift
// In catch block after failed payout
catch {
    // Refund the wallet balance
    let _: Wallet = try? await supabase
        .from("wallets")
        .update([
            "available_cents": String(wallet.availableCents), // Restore original amount
            "updated_at": ISO8601DateFormatter().string(from: Date())
        ])
        .eq("user_id", value: accountId)
        .execute()
        .value
    
    throw error
}
```

---

## 🎯 Next Steps

1. **Immediate**: Check Supabase Dashboard for deployed functions
2. **Immediate**: Check database for stuck payout record
3. **Immediate**: Verify user's Stripe Connect account exists
4. **Soon**: Add comprehensive logging to payout flow
5. **Soon**: Create admin dashboard to monitor failed payouts
6. **Later**: Set up Stripe webhook monitoring alerts

---

## 📞 Support Checklist

If user contacts support about failed payout:

- [ ] Get user ID
- [ ] Check payouts table for pending/failed records
- [ ] Check wallets table for balance
- [ ] Check users table for stripe_connect_id
- [ ] Check Stripe dashboard for payout attempts
- [ ] Check Edge Function logs
- [ ] Refund wallet if needed
- [ ] Investigate root cause

---

## ⚠️ CRITICAL SECURITY NOTE

The payment_intent ID showing up during a payout request suggests:
1. Code path confusion (mixing payment and payout logic)
2. Possible timing issue (webhook firing for unrelated event)
3. Data corruption (wrong ID being referenced)

**This needs immediate investigation before processing real money.**

---

Darragh

