# DEPLOY: Fix Stripe Capabilities Error

## What to Deploy

**✅ ONLY ONE THING:** Deploy the updated `create_payment_intent` edge function

**❌ NO SQL NEEDED:** This is purely a logic fix

---

## Deployment Steps

### Option 1: Via Supabase CLI (Fastest)

```bash
cd /Users/eileenmurphy/CampusLink
supabase functions deploy create_payment_intent
```

### Option 2: Via Supabase Dashboard

1. Go to: https://supabase.com/dashboard
2. Select your CampusLink project
3. Navigate to **Edge Functions** in left sidebar
4. Find `create_payment_intent` function
5. Click **Deploy** or **Edit**
6. Copy the ENTIRE contents of this file:
   ```
   /Users/eileenmurphy/CampusLink/supabase_functions/create_payment_intent/index.ts
   ```
7. Paste into the editor
8. Click **Deploy**

---

## What This Fix Does

**BEFORE (Broken):**
- Tries to send money directly to seller's Connect account
- Fails if seller hasn't completed verification
- Error: "destination account needs transfers enabled"

**AFTER (Fixed):**
- Checks if seller's Connect account has `transfers` capability ACTIVE
- If YES: Uses destination charges (money → seller's Connect account)
- If NO: Uses escrow mode (money → your platform account)
- Seller can complete verification later, then you transfer the money

---

## Test After Deployment

1. Try buying the same item that gave the error
2. It should now succeed
3. Check Stripe Dashboard:
   - If seller has active Connect: Money goes to their account ✅
   - If seller doesn't: Money stays on your platform ✅
4. When seller completes onboarding, future payments go directly to them

---

## No Database Changes Needed

This fix only changes:
- **Lines 104-131**: Added capability checking logic
- **Lines 184-198**: Changed condition for destination charges

Everything else stays the same. Your database, wallet system, and order flow are unchanged.

---

**Deploy command:**
```bash
supabase functions deploy create_payment_intent
```

That's it!

**Darragh**

