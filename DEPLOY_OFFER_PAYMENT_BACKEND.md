# Deploy Offer Payment Backend Support

## Overview
Enable in-app payments for accepted offers. When a seller accepts a buyer's offer, the buyer can complete payment directly in the app using Stripe, just like regular purchases.

## What Was Changed

### iOS App (Already Done ✅)
- `PaymentService.swift` - Added `preparePaymentSheetForOrder()` and `configurePaymentSheetForOrder()`
- `OrderDetailView.swift` - Added "Confirm Order & Pay" button for unpaid orders
- `UnifiedOfferService.swift` - Creates unpaid orders when offer accepted
- `PendingTransactionDetailView.swift` - Role-aware success messages

**Build Status**: ✅ BUILD SUCCEEDED

### Backend (Needs Deployment)
- `create_payment_intent/index.ts` - Support paying for existing orders
- `stripe-webhook/index.ts` - Update existing orders instead of creating new ones

## Backend Changes Summary

### 1. create_payment_intent Function
**What Changed**:
- Now accepts `order_id` OR `listing_id` in request body
- If `order_id`: Gets order details (already has prices)
- If `listing_id`: Gets listing and calculates prices (existing flow)
- Includes `order_id` in payment intent metadata when provided

**Key Logic**:
```typescript
if (order_id) {
  // Get order, verify buyer, verify unpaid
  // Use order's buyer_price_cents and seller_price_cents
} else if (listing_id) {
  // Existing flow: get listing, calculate prices
}

// Create payment intent with order_id in metadata if present
```

### 2. stripe-webhook Function  
**What Changed**:
- Renamed function: `createOrderFromPayment` → `createOrUpdateOrderFromPayment`
- Checks metadata for `order_id`
- If `order_id` exists: Updates existing order
- If no `order_id`: Creates new order (existing flow)

**Key Logic**:
```typescript
if (metadata?.order_id) {
  // UPDATE existing order
  supabase.from("orders").update({
    stripe_payment_intent_id: paymentIntentId,
    payment_status: "succeeded"
  }).eq("id", orderId)
} else {
  // CREATE new order (existing flow)
}
```

## Deployment Steps

### Step 1: Deploy create_payment_intent Function

```bash
cd /Users/eileenmurphy/CampusLink

# Deploy using Supabase CLI (if you have it)
supabase functions deploy create_payment_intent

# OR: Manual deployment via Supabase Dashboard
```

**Manual Deployment (Supabase Dashboard)**:
1. Go to: https://supabase.com/dashboard → Your Project → Edge Functions
2. Find: `create_payment_intent`
3. Click "Edit"
4. Copy entire content from: `supabase/functions/create_payment_intent/index.ts`
5. Click "Deploy"

**Environment Variables** (should already be set):
- `STRIPE_SECRET_KEY` - Your Stripe secret key
- `SUPABASE_URL` - Automatically available
- `SUPABASE_SERVICE_ROLE_KEY` - Automatically available

### Step 2: Deploy stripe-webhook Function

```bash
# Deploy using Supabase CLI
supabase functions deploy stripe-webhook

# OR: Manual deployment via Supabase Dashboard
```

**Manual Deployment (Supabase Dashboard)**:
1. Go to: Edge Functions
2. Find: `stripe-webhook`
3. Click "Edit"  
4. Copy entire content from: `supabase/functions/stripe-webhook/index.ts`
5. Click "Deploy"

**Environment Variables** (should already be set):
- `STRIPE_SECRET_KEY`
- `STRIPE_WEBHOOK_SECRET`
- `SUPABASE_URL`
- `SUPABASE_SERVICE_ROLE_KEY`

### Step 3: Test Complete Flow

#### Test Scenario 1: Buyer Makes Offer → Seller Accepts → Buyer Pays

**As Buyer (Account A)**:
1. Browse marketplace
2. Find a listing
3. Tap "Make an Offer"
4. Enter $2.00
5. Submit offer
6. Verify: Offer appears in Wallet → Pending Transactions

**As Seller (Account B)**:
1. Go to Wallet → Pending Transactions
2. See buyer's offer
3. Tap the offer
4. Tap "Accept Offer"
5. Verify: Success message "Waiting for buyer to complete payment"

**As Buyer (Account A)**:
1. Receive push notification: "Offer Accepted!"
2. Tap notification OR go to Wallet → Orders
3. Tap the unpaid order
4. See: Orange "Payment Required" banner
5. See: Green "Confirm Order & Pay" button
6. Tap "Confirm Order & Pay"
7. Payment sheet should appear
8. Select payment method (test card OR Apple Pay)
9. Complete payment
10. Verify: Success message "Payment completed! Your order has been confirmed."

**Backend Verification**:
```sql
-- Check order was updated (not duplicated)
SELECT id, order_status, payment_status, stripe_payment_intent_id 
FROM orders 
WHERE buyer_id = 'buyer_uuid'
ORDER BY created_at DESC;

-- Should show:
-- payment_status: 'succeeded'
-- stripe_payment_intent_id: 'pi_xxxxx' (now populated)
```

**As Seller (Account B)**:
11. Verify: Order now shows as paid
12. Can proceed with normal fulfillment flow

#### Test Scenario 2: Regular Purchase (Existing Flow)

1. Browse listing
2. Tap "Buy Now"
3. Complete payment
4. Verify: Still works as before

**This ensures backwards compatibility** ✅

### Step 4: Monitor Logs

After deployment, monitor edge function logs for any errors:

**Supabase Dashboard** → Edge Functions → Select function → "Logs" tab

Watch for:
- ✅ "Payment for existing order: [order_id]"
- ✅ "Order updated with payment successfully"
- ❌ Any error messages

### Step 5: Update Documentation

After successful deployment, update:
- Mark `BACKEND_PAYMENT_FOR_OFFERS.md` as complete
- Update `log.md` with deployment date
- Note any issues encountered

## Files Modified

### iOS App
1. `CampusLink/Features/Payments/Managers/PaymentService.swift`
2. `CampusLink/Features/Payments/Views/OrderDetailView.swift`  
3. `CampusLink/Features/Wallet/Views/PendingTransactionDetailView.swift`
4. `CampusLink/Core/Services/UnifiedOfferService.swift`

### Backend Edge Functions
1. `supabase/functions/create_payment_intent/index.ts`
2. `supabase_functions/create_payment_intent/index.ts` (copy)
3. `supabase/functions/stripe-webhook/index.ts`

## Rollback Plan

If payment fails after deployment:

1. **Quick Fix**: Revert to "Contact Seller" flow (code is in git history)
2. **Debug**: Check edge function logs for errors
3. **Fix**: Deploy corrected version
4. **Verify**: Test with test cards before production

## Test Cards (Stripe)

**Successful Payment**:
- Card: `4242 4242 4242 4242`
- Exp: Any future date
- CVC: Any 3 digits

**Payment Requires Authentication**:
- Card: `4000 0025 0000 3155`

**Decline**:
- Card: `4000 0000 0000 0002`

## Success Criteria

✅ Seller accepts offer → Order created (payment_status: pending)
✅ Buyer gets notification with link to order
✅ Buyer taps "Confirm Order & Pay" → Payment sheet appears
✅ Buyer completes payment → Payment succeeds
✅ Order payment_status → "succeeded"
✅ stripe_payment_intent_id populated
✅ Money goes to escrow/seller Connect account
✅ No duplicate orders created
✅ Regular purchases still work

## Edge Cases Handled

✅ Buyer tries to pay already-paid order → "Order already paid" error
✅ Wrong user tries to pay → "Unauthorized" error
✅ Payment fails → Clear error message, can retry
✅ Seller cancels before payment → Buyer can't pay
✅ Listing_id flow still works → Backwards compatible

---

**Status**: ✅ iOS Ready, Backend Ready to Deploy
**Estimated Deployment Time**: 10 minutes
**Risk Level**: Low (backwards compatible, isolated changes)
**Next Step**: Deploy edge functions to Supabase

