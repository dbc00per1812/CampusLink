# CampusLink Payment System - Complete Code-Based Explanation

## Overview

Your payment system has **TWO MODES** based on seller's Stripe Connect verification status:
1. **Destination Charges Mode** (seller verified) → Money goes directly to seller
2. **Escrow Mode** (seller not verified) → Money goes to platform, held in app wallet

---

## STEP 1: Payment Intent Creation
**File**: `supabase_functions/create_payment_intent/index.ts`

### Code Flow (Lines 133-198):

```typescript
// 1. Calculate pricing
const sellerPriceCents = Math.round(listing.price * 100);           // $0.50 = 50¢
const stripeFeeCents = Math.round((sellerPriceCents * 0.029) + 30); // ~31¢
const subtotalCents = sellerPriceCents + stripeFeeCents;             // 81¢
const buyerPriceCents = Math.ceil(subtotalCents / 100) * 100;       // Round up to $1.00
const campusLinkCutCents = buyerPriceCents - subtotalCents;         // 19¢ (your cut)

// 2. Check seller's Connect account capabilities
const sellerAccount = await stripe.accounts.retrieve(sellerStripeConnectId);
const canUseDestinationCharges = sellerAccount.capabilities?.transfers === 'active';

// 3. Create payment intent
if (canUseDestinationCharges && sellerStripeConnectId) {
  // DESTINATION CHARGES MODE
  paymentIntentParams.on_behalf_of = sellerStripeConnectId;
  paymentIntentParams.transfer_data = { destination: sellerStripeConnectId };
  paymentIntentParams.application_fee_amount = campusLinkCutCents;
  // → Money will go DIRECTLY to seller's Stripe Connect account when captured
} else {
  // ESCROW MODE
  // (no destination parameters)
  // → Money will go to YOUR platform account when captured
}

const paymentIntent = await stripe.paymentIntents.create(paymentIntentParams);
```

### What Happens:
- **Destination Mode**: Payment intent configured to send money to seller's Connect account
- **Escrow Mode**: Payment intent is standard → money goes to your platform Stripe account
- Payment is **NOT captured yet** (manual capture mode)
- Buyer completes payment (Apple Pay, card, etc.) but money is **held by Stripe**

---

## STEP 2: Order Creation & Status
**File**: `CampusLink/Core/Services/OrderService.swift` (lines 73-157)

### After Payment Intent Succeeds:

```swift
// Order is created with status = "pending"
// payment_status = "requires_capture"
// Buyer's money is authorized but NOT captured
```

### Money Status:
- **Stripe**: Holding buyer's money (not captured yet)
- **Seller Wallet**: $0 (nothing released yet)
- **Buyer**: Charged but can still be refunded automatically

---

## STEP 3: Seller Ships/Delivers
**File**: `CampusLink/Core/Services/OrderService.swift` (lines 227-274)

```swift
// Seller marks order as delivered
// Order status changes: pending → seller_confirmed
// Payment is STILL not captured (buyer hasn't confirmed receipt)
```

### Money Status:
- **Stripe**: Still holding buyer's money (not captured)
- **Seller Wallet**: Still $0
- **Buyer**: Can still get automatic refund if they dispute

---

## STEP 4: Buyer Confirms Delivery (THE CRITICAL MOMENT)
**File**: `CampusLink/Core/Services/OrderService.swift` (lines 302-353)

### Code Flow:

```swift
// 1. CAPTURE THE PAYMENT (lines 302-314)
if let paymentIntentId = order.stripePaymentIntentId, order.paymentMethod == .card {
    try await PaymentService.shared.capturePayment(paymentIntentId: paymentIntentId)
    // → THIS is when money actually moves in Stripe
}
```

### What Happens When Payment is Captured:

#### **IF DESTINATION CHARGES MODE** (seller verified):
```
Stripe captures $1.00 from buyer
  ↓
Stripe AUTOMATICALLY splits:
  ├─ $0.50 → Seller's Stripe Connect account (seller_receives_cents)
  ├─ $0.19 → Your platform account (application_fee_amount)
  └─ $0.31 → Stripe keeps (their processing fee)
```

**Money is DONE moving in Stripe. Seller has it in their Connect account.**

#### **IF ESCROW MODE** (seller not verified):
```
Stripe captures $1.00 from buyer
  ↓
$0.69 → YOUR platform Stripe account (after Stripe's 31¢ fee)
```

**Money stays on your platform. Now you need to credit seller's app wallet:**

```swift
// 2. RELEASE ESCROW TO SELLER'S WALLET (lines 352-353)
try await releaseEscrowFunds(order: order)
```

### Escrow Release Code (lines 475-568):

```swift
// Calculate net amount (after marketplace fees)
let netAmountCents = order.priceCents - order.marketplaceFeeCents  // $0.50 - $0.19 = $0.31

// Get seller's wallet
let sellerWallet = try await supabase.from("wallets")
    .select()
    .eq("user_id", value: order.sellerId.uuidString)
    .single()
    .execute()
    .value

// Credit seller's wallet
let updateData = WalletUpdate(
    available_cents: sellerWallet.availableCents + netAmountCents,  // Add $0.31 to wallet
    updated_at: ISO8601DateFormatter().string(from: Date())
)

try await supabase.from("wallets")
    .update(updateData)
    .eq("user_id", value: order.sellerId.uuidString)
    .execute()

// Order status changes: seller_confirmed → completed
```

### Money Status After Buyer Confirms:

#### **Destination Mode**:
- **Seller's Stripe Connect**: $0.50 ✅ (can payout to bank immediately)
- **Your Platform Stripe**: $0.19 ✅ (your profit)
- **Seller's App Wallet**: $0 (not used in this mode)

#### **Escrow Mode**:
- **Your Platform Stripe**: $0.69 ✅ (holding funds)
- **Seller's App Wallet**: $0.31 ✅ (can request payout)
- **Platform owes**: $0.31 to seller

---

## STEP 5: Seller Requests Payout
**File**: `supabase/functions/process-payout/index.ts`

### Destination Mode (Direct):
```swift
// Seller's money is ALREADY in their Stripe Connect account
// They just request payout from Connect → Bank

let stripePayout = await stripe.payouts.create({
  amount: payout.net_amount_cents,
  currency: "usd",
  method: "standard"  // or "instant" for debit card
}, {
  stripeAccount: userProfile.stripe_connect_id  // Create payout FROM seller's Connect account
});

// Money moves: Seller's Connect → Seller's Bank
```

### Escrow Mode (Platform Transfer):
```swift
// Step 1: Transfer from platform to seller's Connect account
const transfer = await stripe.transfers.create({
  amount: payout.net_amount_cents,
  currency: "usd",
  destination: userProfile.stripe_connect_id
});
// Money moves: Your Platform → Seller's Connect

// Step 2: Create payout from Connect to bank
const stripePayout = await stripe.payouts.create({
  amount: payout.net_amount_cents,
  currency: "usd",
  method: "standard"
}, {
  stripeAccount: userProfile.stripe_connect_id
});
// Money moves: Seller's Connect → Seller's Bank
```

---

## Complete Money Flow Summary

### Destination Charges Mode (Seller Verified):
```
Buyer pays $1.00
  ↓ (payment intent created, not captured)
Buyer confirms Apple Pay
  ↓ (money authorized, not captured)
Seller delivers
  ↓
Buyer confirms receipt
  ↓ (CAPTURE HAPPENS)
Stripe automatically splits:
  ├─ $0.50 → Seller's Connect account ✅
  ├─ $0.19 → Platform account ✅
  └─ $0.31 → Stripe keeps
  ↓
Seller requests payout
  ↓
$0.50 → Seller's bank account ✅
```

### Escrow Mode (Seller Not Verified):
```
Buyer pays $1.00
  ↓ (payment intent created, not captured)
Buyer confirms Apple Pay
  ↓ (money authorized, not captured)
Seller delivers
  ↓
Buyer confirms receipt
  ↓ (CAPTURE HAPPENS)
$0.69 → Platform Stripe account (after Stripe fee)
  ↓
App credits seller's wallet: +$0.31
Platform keeps: $0.19 profit
Platform holds: $0.31 escrow
  ↓
Seller requests payout
  ↓
Platform transfers $0.31 to seller's Connect
  ↓
$0.31 → Seller's bank account ✅
```

---

## Key Code Locations

1. **Payment Intent Creation**: `supabase_functions/create_payment_intent/index.ts:182-198`
2. **Payment Capture**: `CampusLink/Core/Services/OrderService.swift:302-314`
3. **Escrow Release**: `CampusLink/Core/Services/OrderService.swift:475-568`
4. **Payout Processing**: `supabase/functions/process-payout/index.ts:121-183`

---

## The Fix We Just Made

**Before**: Always tried to use destination charges → failed if seller not verified
**After**: Checks `transfers` capability → uses escrow mode if not active

This allows sellers to list and sell items BEFORE completing Stripe verification. Money safely held in escrow until they verify, then paid out.

**Darragh**

