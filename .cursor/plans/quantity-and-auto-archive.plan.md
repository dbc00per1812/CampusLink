<!-- quantity-management-plan -->

# Quantity Management & Auto-Archive Implementation

## Overview

Add quantity tracking for listings so sellers can list multiple units and buyers can purchase specific quantities. Auto-archive or decrement quantity after purchase.

## Database Changes (Supabase)

### 1. Add columns to `listings` table

```sql
-- Add quantity fields
ALTER TABLE listings 
ADD COLUMN quantity_available INTEGER DEFAULT 1,
ADD COLUMN quantity_sold INTEGER DEFAULT 0;

-- Backfill existing listings
UPDATE listings 
SET quantity_available = 1,
    quantity_sold = 0
WHERE quantity_available IS NULL;

-- Add constraint to prevent negative quantities
ALTER TABLE listings 
ADD CONSTRAINT quantity_available_check CHECK (quantity_available >= 0);
```

### 2. Add column to `orders` table

```sql
-- Add quantity purchased field
ALTER TABLE orders 
ADD COLUMN quantity INTEGER DEFAULT 1;

-- Backfill existing orders
UPDATE orders 
SET quantity = 1
WHERE quantity IS NULL;
```

### 3. Create trigger/function to update quantity on purchase

```sql
-- Function to decrement listing quantity and archive if needed
CREATE OR REPLACE FUNCTION decrement_listing_quantity()
RETURNS TRIGGER AS $$
BEGIN
  -- Update the listing
  UPDATE listings
  SET 
    quantity_sold = quantity_sold + NEW.quantity,
    quantity_available = quantity_available - NEW.quantity,
    archived = CASE 
      WHEN (quantity_available - NEW.quantity) <= 0 THEN true 
      ELSE archived 
    END,
    is_sold = CASE 
      WHEN (quantity_available - NEW.quantity) <= 0 THEN true 
      ELSE is_sold 
    END
  WHERE id = NEW.listing_id;
  
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

-- Create trigger on order creation
DROP TRIGGER IF EXISTS on_order_created ON orders;
CREATE TRIGGER on_order_created
  AFTER INSERT ON orders
  FOR EACH ROW
  EXECUTE FUNCTION decrement_listing_quantity();
```

## Swift Model Changes

### 1. Update `ProductModels.swift` - Listing struct

Add quantity fields:

```swift
struct Listing: Codable, Identifiable {
    // ... existing fields ...
    let quantityAvailable: Int?
    let quantitySold: Int?
    
    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case quantityAvailable = "quantity_available"
        case quantitySold = "quantity_sold"
    }
    
    // Computed property
    var hasMultipleUnits: Bool { (quantityAvailable ?? 1) > 1 }
    var isOutOfStock: Bool { (quantityAvailable ?? 1) <= 0 }
}
```

### 2. Update `ListingCreate` struct

```swift
struct ListingCreate: Codable {
    // ... existing fields ...
    let quantityAvailable: Int?
    
    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case quantityAvailable = "quantity_available"
    }
}
```

### 3. Update `OrderModels.swift` - Order struct

Add quantity field:

```swift
struct Order: Codable, Identifiable {
    // ... existing fields ...
    let quantity: Int
    
    enum CodingKeys: String, CodingKey {
        // ... existing cases ...
        case quantity
    }
}

struct OrderCreate: Codable {
    // ... existing fields ...
    let quantity: Int
}

struct OrderInsert: Codable {
    // ... existing fields ...
    let quantity: Int
}
```

## UI Changes

### 1. Create Listing / Edit Listing - Add Quantity Input

**File**: `CreateListingView.swift` and `EditListingView.swift`

Add after price input:

```swift
// Quantity selector (for products)
if selectedListingType == .product {
    VStack(alignment: .leading, spacing: 8) {
        Text("Quantity Available")
            .font(.headline)
        
        HStack {
            Button(action: {
                if quantity > 1 {
                    quantity -= 1
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title2)
                    .foregroundColor(quantity > 1 ? Color("ThemeColor") : .gray)
            }
            .disabled(quantity <= 1)
            
            Text("\(quantity)")
                .font(.title2)
                .fontWeight(.bold)
                .frame(minWidth: 50)
            
            Button(action: {
                if quantity < 999 {
                    quantity += 1
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title2)
                    .foregroundColor(Color("ThemeColor"))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
        
        Text("How many units are you selling?")
            .font(.caption)
            .foregroundColor(.secondary)
    }
}
```

Add state variable:

```swift
@State private var quantity: Int = 1
```

### 2. Listing Detail View - Show Quantity & Allow Selection

**File**: `ListingDetailView.swift`

Add quantity display in header:

```swift
// After price section, before description
if let quantityAvailable = listing.quantityAvailable, quantityAvailable > 1 {
    HStack {
        Image(systemName: "cube.box.fill")
            .foregroundColor(.secondary)
        Text("\(quantityAvailable) available")
            .font(.subheadline)
            .foregroundColor(.secondary)
        Spacer()
    }
}
```

Add quantity selector before purchase button:

```swift
// Quantity selector for purchase
if !isOwnListing && listing.quantityAvailable ?? 1 > 0 {
    VStack(alignment: .leading, spacing: 12) {
        Text("Quantity")
            .font(.headline)
        
        HStack {
            Button(action: {
                if purchaseQuantity > 1 {
                    purchaseQuantity -= 1
                }
            }) {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .foregroundColor(purchaseQuantity > 1 ? Color("ThemeColor") : .gray)
            }
            .disabled(purchaseQuantity <= 1)
            
            Text("\(purchaseQuantity)")
                .font(.title3)
                .fontWeight(.bold)
                .frame(minWidth: 40)
            
            Button(action: {
                if purchaseQuantity < (listing.quantityAvailable ?? 1) {
                    purchaseQuantity += 1
                }
            }) {
                Image(systemName: "plus.circle.fill")
                    .font(.title3)
                    .foregroundColor(purchaseQuantity < (listing.quantityAvailable ?? 1) ? Color("ThemeColor") : .gray)
            }
            .disabled(purchaseQuantity >= (listing.quantityAvailable ?? 1))
            
            Spacer()
            
            // Show total price
            VStack(alignment: .trailing) {
                Text("Total")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Text(formatPrice(purchaseQuantity))
                    .font(.headline)
                    .foregroundColor(Color("ThemeColor"))
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(12)
    }
}
```

Add state variable:

```swift
@State private var purchaseQuantity: Int = 1
```

### 3. Listing Card - Show Quantity Badge

**File**: `HomeTabView.swift` - ListingCard

Add quantity badge overlay on image:

```swift
.overlay(
    VStack {
        HStack {
            Spacer()
            if let qty = listing.quantityAvailable, qty > 1 {
                Text("\(qty) left")
                    .font(.system(size: 10, weight: .bold))
                    .foregroundColor(.white)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.black.opacity(0.7))
                    .cornerRadius(8)
                    .padding(8)
            }
        }
        Spacer()
    },
    alignment: .topTrailing
)
```

### 4. Profile/Seller View - Show Quantity Sold

**File**: `ProfileTabView.swift`

Show quantity info in listing row:

```swift
// Add after price
if let qtyAvailable = listing.quantityAvailable, 
   let qtySold = listing.quantitySold,
   (qtyAvailable + qtySold) > 1 {
    Text("\(qtySold) sold • \(qtyAvailable) left")
        .font(.caption)
        .foregroundColor(.secondary)
}
```

## Order Creation Updates

### Update `OrderService.swift`

Modify `createOrder` to accept quantity:

```swift
func createOrder(_ orderCreate: OrderCreate) async throws -> Order {
    // ... existing code ...
    
    let orderData = OrderInsert(
        // ... existing fields ...
        quantity: orderCreate.quantity
    )
    
    // ... rest of code ...
}
```

### Update Payment Flow

**File**: `ListingDetailView.swift`

Update order creation to include quantity and calculate total price:

```swift
// Calculate total price based on quantity
let sellerPriceCents = Int((listing.price ?? 0) * 100) * purchaseQuantity
let buyerPriceCents = FeeCalculationService.shared.calculateBuyerPrice(sellerPriceCents: sellerPriceCents)

let orderCreate = OrderCreate(
    listingId: listing.id,
    buyerId: currentUserId,
    sellerId: sellerId,
    priceCents: sellerPriceCents,
    sellerPriceCents: sellerPriceCents,
    buyerPriceCents: buyerPriceCents,
    paymentMethod: .card,
    timeSlotId: nil,
    quantity: purchaseQuantity  // NEW
)
```

## Edge Function Updates

### Update `create_payment_intent`

Calculate price based on quantity:

```typescript
// Get listing and quantity from request
const { listing_id, quantity = 1 } = await req.json();

const listing = await fetchListing(listing_id);

// Calculate for total quantity
const sellerPriceCents = Math.round(listing.price * 100) * quantity;
const stripeFeeCents = Math.round((sellerPriceCents * 0.029) + 30);
const subtotalCents = sellerPriceCents + stripeFeeCents;
const buyerPriceCents = Math.ceil(subtotalCents / 100) * 100;

// Add quantity to metadata
const paymentIntent = await stripe.paymentIntents.create({
  amount: buyerPriceCents,
  currency: 'usd',
  metadata: {
    listing_id: listing.id,
    quantity: quantity.toString(),
    // ... other metadata
  }
});
```

## Testing Checklist

- [ ] Create listing with quantity = 5
- [ ] Verify quantity shows on listing card ("5 left")
- [ ] Verify quantity selector shows in detail view
- [ ] Purchase 2 units → verify charged for 2x price
- [ ] Verify listing now shows quantity = 3
- [ ] Purchase 3 more units → verify listing is archived/sold
- [ ] Verify quantity sold is tracked correctly
- [ ] Test with quantity = 1 (default behavior)

## Files to Modify

1. ✅ `CampusLink/Core/Models/ProductModels.swift` - Add quantity fields to Listing
2. ✅ `CampusLink/Core/Models/OrderModels.swift` - Add quantity to Order
3. ⏳ `CampusLink/Features/Marketplace/Views/CreateListingView.swift` - Quantity input
4. ⏳ `CampusLink/Features/Marketplace/Views/EditListingView.swift` - Quantity input
5. ⏳ `CampusLink/Features/Marketplace/Views/ListingDetailView.swift` - Quantity selector
6. ⏳ `CampusLink/Features/Home/HomeTabView.swift` - Quantity badge
7. ⏳ `CampusLink/Features/Profile/ProfileTabView.swift` - Quantity info
8. ⏳ `CampusLink/Core/Services/OrderService.swift` - Handle quantity in orders
9. ⏳ External: Supabase database migrations
10. ⏳ External: Update edge functions

## Notes

- Services (tutoring, etc.) typically don't need quantity - only products
- Default quantity = 1 for backward compatibility
- When quantity_available reaches 0, auto-archive listing
- Consider bulk pricing discounts in future enhancement