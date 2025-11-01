# FIX: Stripe Capabilities Error - "destination account needs transfers enabled"

## The Problem

Users are seeing this error when trying to buy items:
```
Server error (400): {"error":"Your destination account needs to have at least one of the following capabilities enabled: transfers, crypto_transfers, legacy_payments"}
```

## Root Cause

The seller has a Stripe Connect account, but the `transfers` capability is not yet **ACTIVE**. This happens when:

1. **Seller created account but didn't complete onboarding** - They started the Connect setup but didn't finish
2. **Transfers capability is still pending** - Stripe is reviewing their information
3. **Account is restricted** - Stripe flagged the account for some reason

## The Solution

We need to update `create_payment_intent` to check if the seller's Connect account has active transfers capability BEFORE trying to create a payment intent with destination charges.

### Step 1: Check Seller's Capabilities

Before creating the payment intent, we need to:
1. Retrieve the seller's Stripe Connect account
2. Check if `transfers` capability is `active`
3. Only use destination charges if transfers is active
4. Otherwise, fall back to escrow mode (no destination charges)

### Step 2: Update create_payment_intent Function

The fix adds capability checking to gracefully fall back to escrow mode.

## Files to Update

1. **supabase_functions/create_payment_intent/index.ts** - Add capability checking
2. **Create test script** - To verify seller's Connect status

## Testing

After deployment:
1. Try purchasing from a seller who completed Connect onboarding ✅ Should work with destination charges
2. Try purchasing from a seller who has Connect ID but didn't finish onboarding ✅ Should work in escrow mode
3. Try purchasing from a seller with no Connect account ✅ Should work in escrow mode

---

**Darragh** - I'm going to fix this now by updating the payment intent function to check capabilities before using destination charges.

