<!-- db91baf1-1f8c-4fe1-9b07-a5d4bc3163f2 1017fa8a-39d4-4ea7-bc72-a15e58972a91 -->
# Dynamic Pricing with Markup Implementation

## Overview

Implement two-tier pricing: sellers see their set price, buyers see seller price + fees rounded up (CampusLink's cut). All calculations happen on-the-fly in the app.

## Changes Needed

### 1. Core Pricing Logic (`FeeCalculationService.swift`)

**Add new methods**:

- `calculateBuyerPrice(sellerPriceCents:)` - Returns (sellerPrice + stripeFee) rounded up to next dollar
- `calculateCampusLinkCut(sellerPriceCents:)` - Returns the difference between buyer price and (sellerPrice + stripeFee)
- Update existing fee calculation to work with the new model
```swift
// Example logic:
// sellerPrice = $20.00 (2000 cents)
// stripeFee = 2.9% + $0.30 = $0.88 (88 cents)
// subtotal = $20.88 (2088 cents)
// buyerPrice = $21.00 (2100 cents) - rounded up
// campusLinkCut = $0.12 (12 cents)
```


### 2. Order Models (`OrderModels.swift`)

**Add new fields to Order struct**:

- `sellerPriceCents: Int` - What seller set and will receive
- `buyerPriceCents: Int` - What buyer actually pays (rounded up)
- Keep `priceCents` for backward compatibility (use as sellerPriceCents)

**Update OrderInsert and OrderCreate** to include both prices

### 3. Display Logic - Show Different Prices Based on User Role

**When viewing listings** (`ListingCard`, `ListingDetailView`, `ProfileTabView`):

- If current user is the seller: Show `sellerPrice` only with label "Your price"
- If current user is the seller viewing their own listing: Show both prices - "Your price: $X" and "Buyers see: $Y"
- If current user is a buyer: Show `buyerPrice` prominently as the main price

**Existing files to update**:

- `CampusLink/Features/Home/HomeTabView.swift` (ListingCard) - lines 534-548
- `CampusLink/Features/Marketplace/Views/ListingDetailView.swift` - lines 636-668
- `CampusLink/Core/Navigation/TabViews.swift` - lines 1211-1218
- `CampusLink/Features/Profile/ProfileTabView.swift` - lines 217-246

### 4. Payment Flow Updates

**Update PaymentService** (`PaymentService.swift`):

- Modify `preparePaymentSheet` to use buyer price for payment intent
- Pass both prices to order creation

**Update OrderService** (`OrderService.swift`):

- Store both `sellerPriceCents` and `buyerPriceCents` when creating orders
- Update order queries to handle both prices

**Update views using payment**:

- `ListingDetailView.swift` - Update payment confirmation to show breakdown
- `PurchaseConfirmationView.swift` - Show buyer price
- `MyTransactionsView.swift` - Show appropriate price based on user role
- `OrderDetailView.swift` - Show price breakdown for both parties

### 5. Stripe Edge Function Changes (External - Supabase Dashboard)

**Location**: Supabase Dashboard → Edge Functions → `create_payment_intent`

**Current logic**:

- Gets listing price
- Calculates Stripe fee (2.9% + $0.30)
- Creates PaymentIntent with `listing.price`

**NEW logic needed**:

```typescript
// 1. Get listing price from database
const { data: listing } = await supabase
  .from('listings')
  .select('price')
  .eq('id', listing_id)
  .single();

const sellerPriceCents = Math.round(listing.price * 100);

// 2. Calculate Stripe processing fee
const stripeFeeCents = Math.round((sellerPriceCents * 0.029) + 30);

// 3. Calculate subtotal (seller price + Stripe fee)
const subtotalCents = sellerPriceCents + stripeFeeCents;

// 4. Round UP to next dollar
const buyerPriceCents = Math.ceil(subtotalCents / 100) * 100;

// 5. CampusLink's cut is the difference
const campusLinkCutCents = buyerPriceCents - subtotalCents;

// 6. Create PaymentIntent with BUYER price (the rounded up amount)
const paymentIntent = await stripe.paymentIntents.create({
  amount: buyerPriceCents,  // ← CHANGED: was sellerPriceCents
  currency: 'usd',
  // ... rest of config
});

// 7. Return all price breakdown
return {
  client_secret: paymentIntent.client_secret,
  seller_price_cents: sellerPriceCents,      // NEW
  buyer_price_cents: buyerPriceCents,        // NEW
  stripe_fee_cents: stripeFeeCents,          // EXISTING
  campuslink_cut_cents: campusLinkCutCents,  // NEW
  total_amount_cents: buyerPriceCents        // EXISTING (now = buyer price)
};
```

**Step-by-step in Supabase Dashboard**:

1. Go to your Supabase project → Edge Functions
2. Find `create_payment_intent` function
3. Locate where `paymentIntent` is created (probably around `stripe.paymentIntents.create`)
4. **BEFORE** that creation, add the calculation logic above
5. **CHANGE** the `amount:` parameter from seller price to `buyerPriceCents`
6. **UPDATE** the return statement to include all 5 values
7. Save and deploy the function

**Do the same for** `create_offer_payment_intent`:

- Follow identical logic
- Use offer price instead of listing price
- Return same 5 values in response

**Testing**:

- Create a listing at $20.00
- Buyer should be charged $21.00
- Check Stripe dashboard to confirm $21.00 PaymentIntent
- Verify CampusLink receives $0.12 (the difference after Stripe's cut)

### 6. Database Schema (External - Supabase Dashboard)

**Add columns to `orders` table**:

```sql
ALTER TABLE orders 
ADD COLUMN seller_price_cents INTEGER,
ADD COLUMN buyer_price_cents INTEGER;

-- Backfill existing orders
UPDATE orders 
SET seller_price_cents = price_cents,
    buyer_price_cents = price_cents;
```

## Testing Checklist

- [ ] Create new listing at $20 → verify seller sees $20, buyers see $21
- [ ] Seller views own listing → sees both prices
- [ ] Buyer purchases → charged correct rounded-up amount
- [ ] Seller receives correct amount in escrow
- [ ] Order history shows correct price for each party
- [ ] Existing listings still work correctly

## Files to Modify

1. `CampusLink/Core/Services/FeeCalculationService.swift` - Add buyer price calculations
2. `CampusLink/Core/Models/OrderModels.swift` - Add dual price fields
3. `CampusLink/Features/Home/HomeTabView.swift` - Update ListingCard price display
4. `CampusLink/Features/Marketplace/Views/ListingDetailView.swift` - Update price display logic
5. `CampusLink/Core/Navigation/TabViews.swift` - Update seller's listing view
6. `CampusLink/Features/Profile/ProfileTabView.swift` - Update profile listings view
7. `CampusLink/Features/Payments/Managers/PaymentService.swift` - Use buyer price for payments
8. `CampusLink/Core/Services/OrderService.swift` - Store both prices
9. `CampusLink/Features/Payments/Views/PurchaseConfirmationView.swift` - Show correct price
10. `CampusLink/Features/Payments/Views/OrderDetailView.swift` - Show price breakdown
11. `CampusLink/Features/Payments/Views/MyTransactionsView.swift` - Role-based display

## External Work (Supabase)

1. Update `create_payment_intent` edge function
2. Update `create_offer_payment_intent` edge function  
3. Run database migration to add price columns

### To-dos

- [ ] Add calculateBuyerPrice() and calculateCampusLinkCut() methods to FeeCalculationService
- [ ] Add sellerPriceCents and buyerPriceCents fields to Order, OrderInsert, and OrderCreate structs
- [ ] Update all listing views to show seller price for sellers, buyer price for buyers, both for seller viewing own listing
- [ ] Update PaymentService and OrderService to use buyer price for payments and store both prices
- [ ] Update MyTransactionsView, OrderDetailView, and PurchaseConfirmationView for role-based price display
- [ ] Update Stripe edge functions and run database migration (external work in Supabase)