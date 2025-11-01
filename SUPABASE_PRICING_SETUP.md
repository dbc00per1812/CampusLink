# Supabase Setup for Dynamic Pricing

This document contains the **external work** needed to complete the dynamic pricing implementation. All Swift/iOS code changes have been completed - these are the database and edge function changes needed.

## Overview

The app now implements two-tier pricing:
- **Sellers** set their price and see what they'll receive
- **Buyers** see the seller's price + Stripe fees, rounded up to the next dollar
- **CampusLink's cut** is the difference between what buyers pay and actual costs

Example:
- Seller sets price: **$20.00**
- Stripe fee (2.9% + $0.30): **$0.88**
- Subtotal: **$20.88**
- Buyer pays (rounded up): **$21.00**
- CampusLink's cut: **$0.12**

---

## Step 1: Update Database Schema

### Add new columns to the `orders` table

Go to Supabase Dashboard → SQL Editor → New Query

```sql
-- Add new price columns to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS seller_price_cents INTEGER,
ADD COLUMN IF NOT EXISTS buyer_price_cents INTEGER;

-- Backfill existing orders with current price_cents value
UPDATE orders 
SET seller_price_cents = price_cents,
    buyer_price_cents = price_cents
WHERE seller_price_cents IS NULL;

-- Add comments for documentation
COMMENT ON COLUMN orders.seller_price_cents IS 'Amount seller receives (their listing price)';
COMMENT ON COLUMN orders.buyer_price_cents IS 'Amount buyer pays (seller price + fees, rounded up)';
COMMENT ON COLUMN orders.price_cents IS 'Legacy field, kept for backward compatibility';
```

**Run this query**, then verify:
```sql
SELECT id, price_cents, seller_price_cents, buyer_price_cents 
FROM orders 
LIMIT 5;
```

---

## Step 2: Update `create_payment_intent` Edge Function

### Location
Supabase Dashboard → Edge Functions → `create_payment_intent`

### Find the current code
Look for where the PaymentIntent is created. It should look something like:

```typescript
const paymentIntent = await stripe.paymentIntents.create({
  amount: priceCents,  // <-- This needs to change
  currency: 'usd',
  // ... other config
});
```

### Replace with this new logic

**BEFORE the `paymentIntent` creation, add this:**

```typescript
// Get listing price from database
const { data: listing, error: listingError } = await supabase
  .from('listings')
  .select('price')
  .eq('id', listing_id)
  .single();

if (listingError || !listing) {
  throw new Error('Listing not found');
}

// Calculate pricing breakdown
const sellerPriceCents = Math.round(listing.price * 100);

// Calculate Stripe processing fee (2.9% + $0.30)
const stripeFeeCents = Math.round((sellerPriceCents * 0.029) + 30);

// Calculate subtotal (seller price + Stripe fee)
const subtotalCents = sellerPriceCents + stripeFeeCents;

// Round UP to next dollar - this is what the buyer pays
const buyerPriceCents = Math.ceil(subtotalCents / 100) * 100;

// CampusLink's cut is the difference
const campusLinkCutCents = buyerPriceCents - subtotalCents;

console.log('Pricing breakdown:', {
  sellerPriceCents,
  stripeFeeCents,
  subtotalCents,
  buyerPriceCents,
  campusLinkCutCents
});
```

**UPDATE the PaymentIntent creation:**

```typescript
const paymentIntent = await stripe.paymentIntents.create({
  amount: buyerPriceCents,  // ← CHANGED: Use buyer price (rounded up)
  currency: 'usd',
  // ... keep all other existing config (metadata, etc.)
});
```

**UPDATE the return statement:**

```typescript
return new Response(
  JSON.stringify({
    client_secret: paymentIntent.client_secret,
    seller_price_cents: sellerPriceCents,      // NEW
    buyer_price_cents: buyerPriceCents,        // NEW
    stripe_fee_cents: stripeFeeCents,          // Keep existing
    campuslink_cut_cents: campusLinkCutCents,  // NEW
    total_amount_cents: buyerPriceCents        // Keep existing (now = buyer price)
  }),
  { 
    headers: { 'Content-Type': 'application/json' },
    status: 200,
  }
);
```

### Save and Deploy
Click **Save** then **Deploy** in the Supabase Edge Functions interface.

---

## Step 3: Update `create_offer_payment_intent` Edge Function

### Location
Supabase Dashboard → Edge Functions → `create_offer_payment_intent`

### Apply the same changes

Follow the **exact same pattern** as Step 2, but:
- Instead of fetching from `listings`, get the price from the `offers` table
- Use `offer_id` instead of `listing_id`

```typescript
// Get offer price from database
const { data: offer, error: offerError } = await supabase
  .from('offers')
  .select('price_cents')
  .eq('id', offer_id)
  .single();

if (offerError || !offer) {
  throw new Error('Offer not found');
}

// Calculate pricing breakdown
const sellerPriceCents = offer.price_cents;

// ... rest of the calculation logic is identical to Step 2
```

The PaymentIntent creation and return statement are **identical** to Step 2.

### Save and Deploy
Click **Save** then **Deploy**.

---

## Step 4: Testing

### 4.1 Test in the iOS App

1. **Create a new listing** at $20.00
2. **As the seller** (logged in as listing creator):
   - View the listing → should show "Your price: $20.00" and "Buyers see: $21.00"
3. **As a buyer** (different user):
   - View the same listing → should show "$21.00" as the main price
   - Purchase the item
   - Check payment confirmation → should show "$21.00" paid
4. **Check the database**:
   ```sql
   SELECT 
     id,
     seller_price_cents,
     buyer_price_cents,
     marketplace_fee_cents
   FROM orders
   ORDER BY created_at DESC
   LIMIT 1;
   ```
   Should show:
   - `seller_price_cents`: 2000
   - `buyer_price_cents`: 2100
   - `marketplace_fee_cents`: Should track the CampusLink cut

### 4.2 Test in Stripe Dashboard

1. Go to Stripe Dashboard → Payments
2. Find the most recent payment
3. Verify the amount is **$21.00** (the buyer price, rounded up)
4. Check that the PaymentIntent metadata includes the pricing breakdown

### 4.3 Test Edge Cases

| Seller Price | Stripe Fee | Subtotal | Buyer Pays | CampusLink Cut |
|--------------|-----------|----------|------------|----------------|
| $10.00       | $0.59     | $10.59   | $11.00     | $0.41          |
| $50.00       | $1.75     | $51.75   | $52.00     | $0.25          |
| $100.00      | $3.20     | $103.20  | $104.00    | $0.80          |
| $5.00        | $0.45     | $5.45    | $6.00      | $0.55          |

Create test listings at these prices and verify the buyer prices match.

---

## Step 5: Monitor and Verify

### Check logs in Supabase

1. Go to Supabase Dashboard → Edge Functions → Logs
2. Watch for the pricing breakdown console.log output
3. Verify calculations are correct

### Check for errors

```sql
-- Check if any orders have missing price data
SELECT COUNT(*) as missing_prices
FROM orders
WHERE seller_price_cents IS NULL 
   OR buyer_price_cents IS NULL;
```

Should return **0** for new orders after deployment.

---

## Rollback Plan (If Needed)

If something goes wrong:

1. **Revert edge functions** to previous version (Supabase keeps version history)
2. **Database rollback** (run this only if necessary):
   ```sql
   -- Remove the new columns
   ALTER TABLE orders 
   DROP COLUMN IF EXISTS seller_price_cents,
   DROP COLUMN IF EXISTS buyer_price_cents;
   ```
3. The iOS app will gracefully fall back to using `price_cents` for both (thanks to the `??` fallback operators in the code)

---

## Questions or Issues?

If you encounter any problems:

1. Check Supabase Edge Function logs for errors
2. Verify the database columns were created successfully
3. Test with a small listing price ($1-2) to minimize any issues
4. Ensure Stripe is in test mode while testing

---

## Summary Checklist

- [ ] Run database migration SQL (Step 1)
- [ ] Update `create_payment_intent` edge function (Step 2)
- [ ] Update `create_offer_payment_intent` edge function (Step 3)
- [ ] Deploy both edge functions
- [ ] Test with a $20 listing (Step 4.1)
- [ ] Verify in Stripe Dashboard (Step 4.2)
- [ ] Test edge cases (Step 4.3)
- [ ] Monitor logs for 24 hours (Step 5)

Once all checkboxes are complete, the dynamic pricing system is fully operational! 🎉

