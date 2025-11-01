# Stripe Webhook 404 Fix - Action Required

## 🎯 The Real Problem

You already have a webhook deployed, but it's missing the payout event handlers!

**Current webhook handles**:
- ✅ Payment events (payment_intent.*)
- ✅ Transfer events (transfer.*)  
- ✅ Account events (account.updated)

**Missing**:
- ❌ Payout events (payout.paid, payout.failed, payout.canceled)

**Why this causes 404s**:
- Your `process_payout` function creates **payouts** (po_xxxxx) via `stripe.payouts.create()`
- Stripe tries to send `payout.paid` events
- Your webhook isn't subscribed to these events
- Stripe gets 404 because endpoint doesn't handle those events

---

## ✅ The Fix (10 minutes total)

### 1. Deploy Updated Webhook Code (5 min)

**File to deploy**: `/Users/eileenmurphy/CampusLink/supabase/functions/stripe-webhook/index.ts`

This file now has:
- ✅ All your existing functionality (payments, transfers, accounts)
- ✅ NEW: Payout event handlers (paid, failed, canceled)
- ✅ NEW: Automatic wallet refunds for failed payouts

**Steps**:
1. Supabase Dashboard → Edge Functions → stripe-webhook
2. Replace code with updated version
3. Click Deploy

### 2. Add Events in Stripe (3 min)

**Steps**:
1. Stripe Dashboard → Webhooks
2. Click your webhook: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`
3. Edit endpoint → Add events:
   - `payout.paid`
   - `payout.failed`  
   - `payout.canceled`
4. Save

### 3. Test (2 min)

**Steps**:
1. Stripe Dashboard → Send test webhook
2. Select: `payout.paid`
3. Should see: ✅ 200 Success

---

## 📋 What Was Added

**Three new event handlers**:

```typescript
case "payout.paid":
  // Update status to 'completed'
  // Set completed_at timestamp

case "payout.failed":
  // Update status to 'failed'
  // Refund wallet balance automatically

case "payout.canceled":
  // Update status to 'canceled'
  // Refund wallet balance automatically
```

---

## 📖 Full Guide

See: **`UPDATE_STRIPE_WEBHOOK.md`** for complete instructions

---

## ⏰ Deadline

**October 24, 2025** - Stripe will disable webhook if not fixed

---

## Impact

**Before**:
- ❌ 404 errors in Stripe  
- ❌ Payouts stuck in "processing"
- ❌ No wallet refunds for failed payouts

**After**:
- ✅ No more 404 errors
- ✅ Automatic status updates
- ✅ Automatic wallet refunds
- ✅ Better user experience

---

**Bottom line**: Your webhook exists but needs to be updated with payout handlers. Takes 10 minutes!

**Darragh!** 🚀

