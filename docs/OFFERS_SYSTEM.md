# Unified Offers & Negotiation System

## Overview

The unified offers system supports bidirectional negotiations in CampusLink marketplace:
- **Seek Mode**: Sellers make offers on buyer "wanted" posts
- **Negotiation Mode**: Buyers make offers on seller listings (when `accepts_offers` is enabled)

Both flows use the same database schema, services, and UI components with intelligent role-switching based on context.

## Architecture

### Database Schema

**offers table** (enhanced for bidirectional support):
```sql
CREATE TABLE offers (
  id UUID PRIMARY KEY,
  listing_id UUID NOT NULL,              -- Universal: works for any listing
  listing_type TEXT NOT NULL,            -- 'seek' or 'regular'
  offer_from_user_id UUID NOT NULL,      -- Person making the offer
  offer_to_user_id UUID NOT NULL,        -- Person receiving the offer
  parent_offer_id UUID,                  -- Links counter-offers
  price_cents INT,
  message TEXT,
  status TEXT DEFAULT 'pending',
  order_id UUID,                         -- Linked when accepted
  
  -- Legacy fields (deprecated but kept for compatibility)
  seek_listing_id UUID,
  seeker_id UUID,
  seller_id UUID,
  offer_listing_id UUID,
  
  created_at TIMESTAMPTZ,
  updated_at TIMESTAMPTZ
);
```

**listings table** (new field):
```sql
ALTER TABLE listings ADD COLUMN accepts_offers BOOLEAN DEFAULT false;
```

### Offer Direction Semantics

| Listing Type | Scenario | offer_from_user | offer_to_user | Example |
|-------------|----------|-----------------|---------------|---------|
| **seek** | Seller offers to buyer | seller_id | seeker_id | Buyer posts "Want bike $50", seller offers their bike |
| **regular** | Buyer offers to seller | buyer_id | seller_id | Seller posts "Bike $100", buyer offers "$80" |

### Role Determination

```swift
// In UnifiedOfferService
if listingType == .seek {
    buyerId = offer.offerToUserId   // Seeker is buyer
    sellerId = offer.offerFromUserId // Offerer is seller
} else {
    buyerId = offer.offerFromUserId  // Offerer is buyer  
    sellerId = offer.offerToUserId   // Listing owner is seller
}
```

## Key Components

### 1. Models (`CampusLink/Core/Models/ProductModels.swift`)

```swift
enum OfferListingType: String, Codable {
    case seek = "seek"
    case regular = "regular"
}

struct Offer: Codable, Identifiable {
    let id: UUID
    let listingId: UUID
    let listingType: OfferListingType
    let offerFromUserId: String
    let offerToUserId: String
    let parentOfferId: UUID?
    let priceCents: Int?
    let status: String
    // ... other fields
    
    var isCounterOffer: Bool { parentOfferId != nil }
    var isSeekOffer: Bool { listingType == .seek }
    var isBuyerOffer: Bool { listingType == .regular }
    
    func getUserRole(currentUserId: String) -> OfferUserRole {
        if offerFromUserId == currentUserId { return .sender }
        if offerToUserId == currentUserId { return .receiver }
        return .none
    }
}
```

### 2. UnifiedOfferService (`CampusLink/Core/Services/UnifiedOfferService.swift`)

**Methods:**
- `createOffer()` - Create initial offer (both directions)
- `counterOffer()` - Create counter-offer (swaps roles)
- `acceptOffer()` - Accept offer → create order
- `rejectOffer()` - Reject offer
- `getOffersForListing()` - Get all offers for a listing
- `getMyOffers()` - Get user's sent/received offers
- `getOfferChain()` - Get full negotiation history
- `canInteractWithOffer()` - Validate if can accept

**Key Logic:**
```swift
func acceptOffer(offerId: UUID, currentUserId: String) async throws -> Order {
    let offer = // fetch offer
    let listing = // fetch listing
    
    // Determine buyer/seller
    let (buyerId, sellerId) = listing.intent == .seek 
        ? (offer.offerToUserId, offer.offerFromUserId)  // Seeker buys
        : (offer.offerFromUserId, offer.offerToUserId)  // Offerer buys
    
    // Calculate prices with fees
    let sellerPriceCents = offer.priceCents
    let buyerPriceCents = FeeCalculationService.shared
        .calculateBuyerPrice(sellerPriceCents: sellerPriceCents)
    
    // Create order
    let order = try await OrderService.shared.createOrder(
        listingId: offer.listingId,
        sellerId: sellerId,
        buyerId: buyerId,
        sellerPriceCents: sellerPriceCents,
        buyerPriceCents: buyerPriceCents,
        paymentMethod: .card,
        quantity: 1
    )
    
    // Link offer to order
    // Update offer status to 'accepted'
    
    return order
}
```

### 3. UI Components

**MakeOfferSheet.swift** - Universal offer creation
- Detects listing type automatically
- Shows appropriate fee preview
- Works for both seek and regular listings

**AllMyOffersView.swift** - Unified offers management
- Tabs: "Received" | "Sent"
- Shows all offers in one place
- Quick actions: Accept/Reject/Counter
- Add to Wallet tab

**ListingDetailView.swift** - Updated with offer buttons
- Shows "Make Offer" if `acceptsOffers == true`
- Shows "View Offers" for own listings
- Works for both seek and regular

**EditListingView.swift** - Listing creation
- Toggle: "Accept Offers" (for regular listings)
- Default: OFF
- Seek listings always accept offers

## Fee Handling

**Seller Perspective:**
- Sees only their negotiated amount (no fees shown)
- Receives exactly the negotiated price

**Buyer Perspective:**
- Sees negotiated amount + Stripe fees (2.9% + $0.30)
- Amount rounded UP to next dollar
- Example: Offer $20 → Fees $0.88 → Pay $21

**Platform Profit:**
```
Platform Cut = Buyer Price - (Seller Price + Stripe Fees)
             = $21.00 - ($20.00 + $0.88)
             = $0.12
```

## Counter-Offer Flow

1. **User A makes offer**
   - Status: 'pending'
   - offer_from: A, offer_to: B

2. **User B counters**
   - Parent offer status: 'countered'
   - New offer status: 'pending'
   - offer_from: B, offer_to: A (roles swapped)
   - parent_offer_id: points to original

3. **User A counters back**
   - Previous offer status: 'countered'
   - New offer status: 'pending'
   - offer_from: A, offer_to: B (swapped again)
   - parent_offer_id: points to B's counter

4. **Either party accepts**
   - Offer status: 'accepted'
   - Order created
   - order_id linked to offer

## Notifications

**Triggers created** (`offer_notification_triggers.sql`):
- `offer_received` - New offer created
- `offer_countered` - Counter-offer received
- `offer_accepted` - Offer was accepted
- `offer_rejected` - Offer was declined

**Notification Flow:**
1. Trigger fires on offer INSERT/UPDATE
2. Creates chat message in conversation
3. Queues push notification
4. User sees both in-app and push alert

## RLS Policies

```sql
-- Only participants can view offers
CREATE POLICY "Offer participants can view"
  ON offers FOR SELECT
  USING (auth.uid() = offer_from_user_id OR auth.uid() = offer_to_user_id);

-- Only sender can create
CREATE POLICY "Users can create offers"
  ON offers FOR INSERT
  WITH CHECK (auth.uid() = offer_from_user_id);

-- Both can update (for counter-offers, accept/reject)
CREATE POLICY "Participants can update offers"
  ON offers FOR UPDATE
  USING (auth.uid() = offer_from_user_id OR auth.uid() = offer_to_user_id);
```

## Edge Cases Handled

1. **Multiple Offers**
   - All offers stay open
   - Active order blocks accepting other offers
   - If order cancelled, offers become actionable again

2. **Quantity > 1**
   - Accepting offer creates order for quantity=1
   - Other offers valid for remaining quantity

3. **User Blocking**
   - Blocked users cannot create offers
   - Handled by existing `BlockedUsersService`

4. **Listing States**
   - Cannot offer on sold listings
   - Cannot offer on archived listings
   - Validation in `UnifiedOfferService`

## Migration Guide

**From old seek-only system:**

1. Run `migrate_offers_to_unified.sql`
   - Adds new columns with defaults
   - Migrates existing data
   - Updates RLS policies

2. Run `add_accepts_offers_field.sql`
   - Adds field to listings
   - Sets all seek listings to accept offers

3. Deploy edge function updates
   - No changes needed; works with new schema

4. Test flows:
   - Seek mode (existing) still works
   - New negotiation mode works
   - Counter-offers work both ways

## Testing Checklist

- [ ] Create regular listing with `accepts_offers = true`
- [ ] Buyer makes offer → seller receives notification
- [ ] Seller counters → buyer receives notification
- [ ] Buyer counters back → unlimited negotiation works
- [ ] Seller accepts → order created at negotiated price
- [ ] Verify buyer pays (amount + fees, rounded up)
- [ ] Verify seller receives exact negotiated amount
- [ ] Test seek mode still works (seller→buyer offers)
- [ ] Multiple offers on same listing stay open
- [ ] Active order blocks accepting other offers
- [ ] RLS: Users only see offers they're involved in
- [ ] Chat integration shows offer cards
- [ ] Push notifications deliver correctly

## Files Modified

**Database:**
- `migrate_offers_to_unified.sql` - Schema migration
- `add_accepts_offers_field.sql` - Add listing field
- `offer_notification_triggers.sql` - Notification triggers

**Models:**
- `CampusLink/Core/Models/ProductModels.swift` - Enhanced Offer model

**Services:**
- `CampusLink/Core/Services/UnifiedOfferService.swift` - New service

**Views:**
- `CampusLink/Features/Marketplace/Views/EditListingView.swift` - Add toggle
- `CampusLink/Features/Marketplace/Views/ListingDetailView.swift` - Add buttons
- `CampusLink/Features/Marketplace/Views/MakeOfferSheet.swift` - New sheet
- `CampusLink/Features/Marketplace/Views/AllMyOffersView.swift` - New view

## Future Enhancements

1. **Offer Expiration**
   - Add `expires_at` field
   - Auto-expire after X hours
   - Cron job to update statuses

2. **Offer Analytics**
   - Track acceptance rate
   - Average negotiation rounds
   - Time to acceptance

3. **Smart Suggestions**
   - Suggest counter-offer amounts
   - Based on historical data
   - ML model for optimal pricing

4. **Bulk Operations**
   - Accept multiple offers at once
   - Reject all pending
   - Counter all with same amount

---

**Last Updated**: November 9, 2025  
**Version**: 1.0  
**Author**: AI Assistant (for Darragh)

