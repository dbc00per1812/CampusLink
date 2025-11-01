# Supabase Quantity Management Setup

## Overview
This document contains all SQL migrations and edge function updates needed to implement quantity tracking and auto-archiving for listings.

**⚠️ IMPORTANT**: Execute these changes in your Supabase dashboard after completing the iOS app updates.

---

## Part 1: Database Schema Changes

### Step 1: Add Columns to `listings` Table

Run this SQL in **Supabase Dashboard → SQL Editor**:

```sql
-- Add quantity tracking columns to listings table
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS quantity_available INTEGER DEFAULT 1,
ADD COLUMN IF NOT EXISTS quantity_sold INTEGER DEFAULT 0;

-- Add constraint to prevent negative quantities (remove IF NOT EXISTS - not supported)
ALTER TABLE listings 
ADD CONSTRAINT quantity_available_check CHECK (quantity_available >= 0);

-- Backfill existing listings with default values
UPDATE listings 
SET quantity_available = 1,
    quantity_sold = 0
WHERE quantity_available IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN listings.quantity_available IS 'Number of units available for purchase';
COMMENT ON COLUMN listings.quantity_sold IS 'Total number of units sold';
```

### Step 2: Add Column to `orders` Table

```sql
-- Add quantity column to orders table
ALTER TABLE orders 
ADD COLUMN IF NOT EXISTS quantity INTEGER DEFAULT 1;

-- Backfill existing orders
UPDATE orders 
SET quantity = 1
WHERE quantity IS NULL;

-- Add comment for documentation
COMMENT ON COLUMN orders.quantity IS 'Number of units purchased in this order';
```

---

## Part 2: Auto-Decrement Trigger

### Step 3: Create Function to Handle Quantity Updates

This function will automatically:
- Decrement `quantity_available` when an order is placed
- Increment `quantity_sold`
- Set `archived = true` and `is_sold = true` when quantity reaches 0

```sql
-- Drop existing trigger if it exists
DROP TRIGGER IF EXISTS on_order_created ON orders;
DROP FUNCTION IF EXISTS decrement_listing_quantity();

-- Create function to decrement listing quantity
CREATE OR REPLACE FUNCTION decrement_listing_quantity()
RETURNS TRIGGER
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_remaining_quantity INTEGER;
BEGIN
  -- Log the order creation
  RAISE NOTICE 'Order created: % units of listing %', NEW.quantity, NEW.listing_id;
  
  -- Update the listing quantities
  UPDATE listings
  SET 
    quantity_sold = COALESCE(quantity_sold, 0) + NEW.quantity,
    quantity_available = COALESCE(quantity_available, 1) - NEW.quantity,
    archived = CASE 
      WHEN (COALESCE(quantity_available, 1) - NEW.quantity) <= 0 THEN true 
      ELSE COALESCE(archived, false)
    END,
    is_sold = CASE 
      WHEN (COALESCE(quantity_available, 1) - NEW.quantity) <= 0 THEN true 
      ELSE COALESCE(is_sold, false)
    END,
    updated_at = NOW()
  WHERE id = NEW.listing_id
  RETURNING quantity_available INTO v_remaining_quantity;
  
  -- Log the result
  RAISE NOTICE 'Listing % updated. Remaining quantity: %', NEW.listing_id, v_remaining_quantity;
  
  -- Check if quantity went negative (shouldn't happen with proper checks, but safety net)
  IF v_remaining_quantity < 0 THEN
    RAISE EXCEPTION 'Insufficient quantity available for listing %', NEW.listing_id;
  END IF;
  
  RETURN NEW;
END;
$$;

-- Create trigger to fire after order insertion
CREATE TRIGGER on_order_created
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION decrement_listing_quantity();

-- Add comment
COMMENT ON FUNCTION decrement_listing_quantity() IS 'Automatically decrements listing quantity and archives when sold out';
```

### Step 4: Create Function to Check Quantity Before Purchase (Optional but Recommended)

This RPC function can be called from the app before creating an order to verify quantity is available:

```sql
CREATE OR REPLACE FUNCTION check_listing_quantity(
  p_listing_id UUID,
  p_requested_quantity INTEGER
)
RETURNS JSON
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
  v_available INTEGER;
  v_result JSON;
BEGIN
  -- Get current available quantity
  SELECT COALESCE(quantity_available, 1)
  INTO v_available
  FROM listings
  WHERE id = p_listing_id
    AND archived = false
    AND is_sold = false;
  
  -- Check if listing exists
  IF v_available IS NULL THEN
    v_result := json_build_object(
      'available', false,
      'reason', 'Listing not found or unavailable',
      'quantity_available', 0
    );
    RETURN v_result;
  END IF;
  
  -- Check if enough quantity available
  IF v_available >= p_requested_quantity THEN
    v_result := json_build_object(
      'available', true,
      'quantity_available', v_available,
      'can_purchase', true
    );
  ELSE
    v_result := json_build_object(
      'available', false,
      'reason', 'Insufficient quantity',
      'quantity_available', v_available,
      'requested', p_requested_quantity
    );
  END IF;
  
  RETURN v_result;
END;
$$;

-- Add comment
COMMENT ON FUNCTION check_listing_quantity(UUID, INTEGER) IS 'Checks if requested quantity is available for a listing';
```

---

## Part 3: Edge Function Updates

### Step 5: Update `create_payment_intent` Function

**Location**: Supabase Dashboard → Edge Functions → `create_payment_intent`

**Changes needed**:

1. **Accept quantity parameter** in request body
2. **Multiply price by quantity** for total amount
3. **Add quantity to metadata**
4. **Verify quantity is available** before creating payment intent

**Updated code snippet** (insert around line 110-130):

```typescript
// Get listing and quantity from request
const { listing_id, quantity = 1 } = await req.json();

if (!listing_id || typeof listing_id !== "string") {
  return jsonResponse(400, { error: "Missing or invalid 'listing_id'" });
}

if (quantity < 1 || quantity > 999) {
  return jsonResponse(400, { error: "Invalid quantity. Must be between 1 and 999." });
}

const listing = await fetchListing(listing_id);

// Check if enough quantity is available
const availableQty = listing.quantity_available ?? 1;
if (quantity > availableQty) {
  return jsonResponse(400, { 
    error: `Insufficient quantity. Only ${availableQty} available.`,
    quantity_available: availableQty
  });
}

// Calculate total price for quantity
const sellerPriceCentsPerUnit = Math.round(Number(listing.price) * 100);
const sellerPriceCents = sellerPriceCentsPerUnit * quantity;

// Calculate fees on total price
const stripeFeeCents = Math.round((sellerPriceCents * 0.029) + 30);
const subtotalCents = sellerPriceCents + stripeFeeCents;
const buyerPriceCents = Math.ceil(subtotalCents / 100) * 100;
const campusLinkCutCents = buyerPriceCents - subtotalCents;

// Create PaymentIntent with buyer price
const paymentIntent = await stripe.paymentIntents.create({
  amount: buyerPriceCents,
  currency: 'usd',
  capture_method: 'manual',
  automatic_payment_methods: {
    enabled: true
  },
  metadata: {
    listing_id: listing.id,
    buyer_id: userId,
    seller_id: listing.user_id,
    seller_price_cents: sellerPriceCents.toString(),
    buyer_price_cents: buyerPriceCents.toString(),
    stripe_fee_cents: stripeFeeCents.toString(),
    campuslink_cut_cents: campusLinkCutCents.toString(),
    quantity: quantity.toString(),  // NEW: Add quantity to metadata
    price_per_unit: sellerPriceCentsPerUnit.toString()  // NEW: Track per-unit price
  }
});

// Insert payment row (amount should be buyer price)
await insertPaymentRow({
  buyerId: userId,
  sellerId: listing.user_id,
  listingId: listing.id,
  stripeFeeInCents: stripeFeeCents,
  totalAmountInCents: buyerPriceCents,
  paymentIntentId: paymentIntent.id
});

// Return pricing breakdown
return jsonResponse(200, {
  client_secret: paymentIntent.client_secret,
  seller_price_cents: sellerPriceCents,
  buyer_price_cents: buyerPriceCents,
  stripe_fee_cents: stripeFeeCents,
  campuslink_cut_cents: campusLinkCutCents,
  total_amount_cents: buyerPriceCents,
  quantity: quantity,
  price_per_unit: sellerPriceCentsPerUnit
});
```

**Also update the `fetchListing` function** to include quantity fields:

```typescript
async function fetchListing(listingId) {
  const supabase = getSupabaseServiceClient();
  const { data, error } = await supabase
    .from("listings")
    .select("id, price, user_id, quantity_available, quantity_sold")  // Add quantity fields
    .eq("id", listingId)
    .single();
  
  if (error || !data) {
    throw new Error("Listing not found");
  }
  
  return data;
}
```

---

## Part 4: Testing Checklist

After applying all changes, test the following scenarios:

### Test 1: Single Unit Purchase
- [ ] Create listing with quantity = 1
- [ ] Purchase the item
- [ ] Verify listing is archived and marked as sold
- [ ] Verify buyer was charged correct amount
- [ ] Verify seller receives correct amount

### Test 2: Multi-Unit Listing
- [ ] Create listing with quantity = 5
- [ ] Verify "5 left" badge shows on listing card
- [ ] Purchase 2 units
- [ ] Verify quantity_available = 3, quantity_sold = 2
- [ ] Verify buyer was charged for 2 units
- [ ] Purchase remaining 3 units
- [ ] Verify listing is now archived

### Test 3: Insufficient Quantity
- [ ] Create listing with quantity = 2
- [ ] Try to purchase 5 units
- [ ] Verify error message appears
- [ ] Verify purchase is blocked

### Test 4: Quantity Selector UI
- [ ] Create new listing, verify quantity selector appears for products
- [ ] Verify quantity selector does NOT appear for services
- [ ] Edit existing listing, verify quantity can be changed
- [ ] Verify quantity resets to 1 after posting

### Test 5: Database Integrity
- [ ] Verify trigger fires on order creation
- [ ] Verify quantities update correctly
- [ ] Verify archived and is_sold flags set correctly
- [ ] Check database logs for any errors

---

## Part 5: Rollback Plan (If Needed)

If something goes wrong, run this to revert:

```sql
-- Remove trigger
DROP TRIGGER IF EXISTS on_order_created ON orders;
DROP FUNCTION IF EXISTS decrement_listing_quantity();
DROP FUNCTION IF EXISTS check_listing_quantity(UUID, INTEGER);

-- Remove columns (CAUTION: This deletes data!)
ALTER TABLE listings 
DROP COLUMN IF EXISTS quantity_available,
DROP COLUMN IF EXISTS quantity_sold;

ALTER TABLE orders 
DROP COLUMN IF EXISTS quantity;
```

**Note**: This will delete all quantity data. Only use if absolutely necessary.

---

## Summary

**Files to update in Supabase**:
1. ✅ Run SQL migration for `listings` table
2. ✅ Run SQL migration for `orders` table
3. ✅ Create trigger function `decrement_listing_quantity()`
4. ✅ Create optional `check_listing_quantity()` RPC
5. ✅ Update `create_payment_intent` edge function

**Expected Behavior**:
- New listings default to quantity = 1
- Sellers can set quantity 1-999 for products
- Buyers can select quantity up to available amount
- Listings auto-archive when quantity reaches 0
- Order creation automatically decrements quantity
- Stripe charges correct total (unit price × quantity)

**Questions?**
- Check Supabase logs: Dashboard → Database → Logs
- Check Edge Function logs: Dashboard → Edge Functions → Logs
- Test RPC calls: Dashboard → SQL Editor → RPC tab

Darragh, everything is documented and ready for Supabase implementation!

