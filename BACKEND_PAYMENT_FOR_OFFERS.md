# Backend Changes for In-App Payment on Accepted Offers

## Required Changes

### 1. Modify `create_payment_intent` Edge Function
**File**: `supabase/functions/create_payment_intent/index.ts` (or `supabase_functions/`)

**Change**: Support BOTH `listing_id` (new purchase) AND `order_id` (accepted offer payment)

```typescript
// Current: const { listing_id } = await req.json();
// New:
const { listing_id, order_id } = await req.json();

if (order_id) {
  // PAYING FOR EXISTING ORDER (accepted offer)
  // Get order details
  const { data: order, error: orderError } = await supabaseAdmin
    .from("orders")
    .select(`
      id,
      buyer_id,
      seller_id,
      buyer_price_cents,
      seller_price_cents,
      listing_id,
      listing:listings(id, title, user_id)
    `)
    .eq("id", order_id)
    .single();

  if (orderError || !order) {
    throw new Error("Order not found");
  }

  // Verify current user is the buyer
  if (order.buyer_id !== userId) {
    throw new Error("Unauthorized - not the buyer");
  }

  // Verify order is unpaid
  if (order.payment_status !== 'pending') {
    throw new Error("Order already paid");
  }

  // Use order's buyer_price_cents for payment amount
  const amountCents = order.buyer_price_cents;
  const sellerId = order.seller_id;
  
  // Continue with existing payment intent creation logic...
  // Add order_id to metadata so webhook knows to update instead of create
  metadata: {
    listing_id: order.listing_id,
    order_id: order.id,  // ← KEY: tells webhook to update this order
    buyer_id: userId,
    seller_id: sellerId
  }
  
} else if (listing_id) {
  // EXISTING FLOW: new purchase
  // ... current code ...
}
```

### 2. Modify Stripe Webhook Handler
**File**: `supabase/functions/stripe-webhook/index.ts`

**Change**: Check if order already exists before creating

```typescript
async function createOrderFromPayment(paymentIntentId) {
  const supabase = getSupabaseServiceClient();
  try {
    // Get payment intent metadata
    const paymentIntent = await stripe.paymentIntents.retrieve(paymentIntentId);
    const orderId = paymentIntent.metadata.order_id;
    
    if (orderId) {
      // ORDER ALREADY EXISTS - just update it
      console.log(`Updating existing order ${orderId} with payment`);
      
      const { error: updateError } = await supabase
        .from("orders")
        .update({
          stripe_payment_intent_id: paymentIntentId,
          payment_status: "succeeded",
          updated_at: new Date().toISOString()
        })
        .eq("id", orderId);
      
      if (updateError) {
        console.error(`Failed to update order ${orderId}:`, updateError);
      } else {
        console.log(`Order ${orderId} updated successfully`);
      }
      return;
    }
    
    // EXISTING FLOW: create new order
    const { data: payment, error: paymentError } = await supabase
      .from("payments")
      .select("listing_id, buyer_id, seller_id, amount_cents, payment_method")
      .eq("payment_intent_id", paymentIntentId)
      .single();
    
    // ... rest of existing code ...
  }
}
```

## Frontend Changes (Already Done)

The frontend already calls `handleConfirmAndPay()` which uses:
```swift
paymentService.configurePaymentSheet(for: listingId.uuidString)
```

We just need to update PaymentService to support order_id:

### 3. Update PaymentService.swift
**File**: `CampusLink/Features/Payments/Managers/PaymentService.swift`

Add new method:
```swift
func preparePaymentSheetForOrder(orderId: String) async throws -> (...) {
    // Call edge function with order_id instead of listing_id
    let body = ["order_id": orderId]
    // ... rest similar to preparePaymentSheet
}
```

## Deployment Steps

1. **Deploy Updated Edge Function**:
```bash
# In supabase/functions/create_payment_intent/
supabase functions deploy create_payment_intent
```

2. **Deploy Updated Webhook**:
```bash
# In supabase/functions/stripe-webhook/
supabase functions deploy stripe-webhook
```

3. **Test Flow**:
   - Seller accepts offer → order created (payment_status: pending)
   - Buyer taps "Confirm Order & Pay"
   - Payment sheet shows with correct amount
   - Buyer completes payment
   - Webhook updates order (payment_status: succeeded)
   - Order proceeds normally

## Summary

**Backend**: 2 file modifications
- `create_payment_intent/index.ts` - support order_id parameter
- `stripe-webhook/index.ts` - update existing order instead of creating

**Frontend**: Small update to call new endpoint
- `PaymentService.swift` - add method for order payment
- `OrderDetailView.swift` - call new method

Total work: ~30 minutes of backend + 10 minutes frontend

