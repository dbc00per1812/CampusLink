<!-- e538a967-b079-4241-99b8-1c166945ad97 5de96890-45dc-4f22-b90f-656903d68d38 -->
# Unified Offers & Negotiation System

## Overview

Redesign the existing offers system to work bidirectionally: support both seek mode (where sellers make offers on buyer "wanted" posts) AND negotiation mode (where buyers make offers on seller listings). Replace separate systems with one unified, flexible offers table and UI.

## Key Changes from Current System

- **Current**: `offers` table only works for seek listings (seller→buyer direction)
- **New**: Enhanced `offers` table works both directions with clear role semantics
- **Current**: Separate UIs for seek offers vs regular purchases
- **New**: Unified "My Offers" showing all sent/received offers in one place above transactions in wallet

## Key Requirements

- **Bidirectional**: Seek mode (seller offers to buyer) + Negotiation mode (buyer offers to seller)
- **Private**: Only the two parties involved see each offer
- **Unlimited negotiation**: Counter-offers can go back and forth indefinitely
- **Multiple offers**: Keep all pending; block interactions only when order is active
- **Dual display**: Show in chat AND dedicated "My Offers" view
- **No expiration**: Offers stay pending until acted upon
- **Fee transparency**: Buyer always pays offer amount + fees (rounded up), seller sees only negotiated amount

## Implementation Plan

### Phase 1: Database Schema Redesign

**Migrate existing `offers` table to support both directions**

Current schema is seek-specific. Enhance it to be direction-agnostic:

```sql
-- Add new columns for bidirectional support
ALTER TABLE offers ADD COLUMN listing_type TEXT CHECK (listing_type IN ('seek', 'regular'));
ALTER TABLE offers ADD COLUMN offer_from_user_id UUID REFERENCES users(id);
ALTER TABLE offers ADD COLUMN offer_to_user_id UUID REFERENCES users(id);
ALTER TABLE offers ADD COLUMN parent_offer_id UUID REFERENCES offers(id); -- For counter-offers

-- Add index for counter-offer chains
CREATE INDEX idx_offers_parent ON offers(parent_offer_id);

-- Update to use generic listing_id (rename seek_listing_id)
-- Actual migration: copy seek_listing_id → listing_id, then drop seek_listing_id
```

**Semantic mapping**:

- **Seek listing** (buyer posts "I want bike"):
  - `listing_type = 'seek'`
  - `listing_id` = the seek post
  - `offer_from_user_id` = seller making the offer
  - `offer_to_user_id` = seeker (buyer)
  - `offer_listing_id` = (optional) seller's existing listing they're offering

- **Regular listing** (seller posts "Bike $100", buyer offers "$80"):
  - `listing_type = 'regular'`  
  - `listing_id` = the seller's listing
  - `offer_from_user_id` = buyer making the offer
  - `offer_to_user_id` = seller (listing owner)
  - `offer_listing_id` = NULL (buyer doesn't have a listing)

**Update RLS policies** to use new fields:

```sql
-- Drop old policies
DROP POLICY IF EXISTS "Users can view their own offers" ON offers;

-- New bidirectional policies
CREATE POLICY "Offer participants can view"
  ON offers FOR SELECT
  USING (auth.uid() = offer_from_user_id OR auth.uid() = offer_to_user_id);

CREATE POLICY "Users can create offers"
  ON offers FOR INSERT
  WITH CHECK (auth.uid() = offer_from_user_id);

CREATE POLICY "Participants can update offers"
  ON offers FOR UPDATE
  USING (auth.uid() = offer_from_user_id OR auth.uid() = offer_to_user_id);
```

**Add field to listings table** (for negotiable flag):

```sql
ALTER TABLE listings ADD COLUMN accepts_offers BOOLEAN DEFAULT false;
UPDATE listings SET accepts_offers = true WHERE intent = 'seek'; -- All seek listings accept offers
```

### Phase 2: Swift Models Update

**Update**: `CampusLink/Core/Models/ProductModels.swift`

Enhance existing `Offer` struct (line ~336):

```swift
struct Offer: Codable, Identifiable {
    let id: UUID
    let listingId: UUID  // Renamed from seekListingId
    let listingType: OfferListingType  // NEW: 'seek' or 'regular'
    let offerListingId: UUID?
    let offerFromUserId: String  // NEW: Person making offer
    let offerToUserId: String    // NEW: Person receiving offer
    let parentOfferId: UUID?     // NEW: For counter-offers
    
    // Legacy fields for backward compatibility
    let seekerId: String?
    let sellerId: String?
    
    let message: String?
    let status: String
    let priceCents: Int?
    let orderId: UUID?
    let createdAt: Date
    let updatedAt: Date
    
    // Computed properties
    var isCounterOffer: Bool { parentOfferId != nil }
    var isSeekOffer: Bool { listingType == .seek }
    var isBuyerOffer: Bool { listingType == .regular }
    // ... existing price formatting
}

enum OfferListingType: String, Codable {
    case seek = "seek"
    case regular = "regular"
}
```

Add `acceptsOffers: Bool?` to:

- `Listing` struct
- `CreateListingRequest` struct  
- `ListingWithUser` struct

### Phase 3: Enhanced Offer Service

**Update**: Existing offer service or create `CampusLink/Core/Services/UnifiedOfferService.swift`

Methods to support both directions:

```swift
class UnifiedOfferService {
    // Create offer (works for both directions)
    func createOffer(
        listingId: UUID,
        listingType: OfferListingType,
        toUserId: String,
        amountCents: Int,
        message: String?,
        offerListingId: UUID? = nil
    ) async throws -> Offer
    
    // Counter-offer (either party can counter)
    func counterOffer(
        parentOfferId: UUID,
        amountCents: Int,
        message: String?
    ) async throws -> Offer
    
    // Accept offer → create order
    func acceptOffer(offerId: UUID) async throws -> Order
    
    // Reject offer
    func rejectOffer(offerId: UUID) async throws
    
    // Get all offers for a listing (seller view or seeker view)
    func getOffersForListing(listingId: UUID) async throws -> [Offer]
    
    // Get my offers (sent + received, unified view)
    func getMyOffers() async throws -> (sent: [Offer], received: [Offer])
    
    // Get negotiation chain
    func getOfferChain(offerId: UUID) async throws -> [Offer]
    
    // Check if can interact
    func canInteractWithOffer(offerId: UUID) async throws -> Bool
}
```

**Order creation logic** (same for both directions):

- Determine who is buyer/seller based on listing type
- Use `priceCents` as `sellerPriceCents`
- Calculate `buyerPriceCents` using `FeeCalculationService`
- Create order with proper buyer/seller roles

### Phase 4: Listing Creation/Edit UI

**Update**: `CampusLink/Features/Marketplace/Views/EditListingView.swift`

For regular listings (intent='offer'):

- Add "Accept Offers" toggle below price field
- Helper text: "Let buyers negotiate the price with you"
- Default: OFF

For seek listings (intent='seek'):

- `accepts_offers` automatically true (no toggle needed)
- This is how seek mode works

### Phase 5: Listing Detail - Making Offers

**Update**: `CampusLink/Features/Marketplace/Views/ListingDetailView.swift`

**For regular listings with `acceptsOffers = true`:**

- Show "Make Offer" button (buyer side)
- If user already has pending offer, show "View My Offer"
- Present `MakeOfferSheet`

**For seek listings (existing behavior enhanced):**

- Show "Make Offer" button (seller side)
- Use same `MakeOfferSheet` but reverse the roles
- Can optionally link to one of seller's existing listings

**For own listings:**

- Show "View Offers" button with badge count
- Navigate to `OffersListView`

**File**: `CampusLink/Features/Marketplace/Views/MakeOfferSheet.swift` (new)

Universal offer creation sheet:

- Detects listing type (seek vs regular) to determine role
- Price input field with validation
- Optional message field
- Shows "You'll pay/receive" preview with fees
- Submit creates offer via `UnifiedOfferService`

### Phase 6: Unified Offers Management

**Update**: `CampusLink/Features/Marketplace/Views/OffersListView.swift`

Enhance existing view to support both types:

- Show offers for a specific listing (seller managing offers on their post)
- Works for both seek listings and regular listings
- Display offer chain/history
- Action buttons: Accept, Reject, Counter
- Counter-offer sheet
- Show active order blocking state

**Create**: `CampusLink/Features/Marketplace/Views/AllMyOffersView.swift` (new)

Unified view for user's complete offer activity:

- Tabs: "Received" | "Sent"
- **Received**: Offers others made to me (on my listings)
- **Sent**: Offers I made to others (on their listings)
- Each shows: listing preview, amount, status, timestamp
- Tap to see full negotiation chain
- Quick actions: Accept/Reject/Counter
- Filter by status: Pending, Accepted, Rejected

Add navigation to this view from:

- Wallet tab (as user suggested)
- Profile tab
- Or dedicated nav item

### Phase 7: Chat Integration

**Update**: `CampusLink/Features/Messaging/Views/ChatView.swift`

The chat already has offer handling (line ~10-16). Enhance it:

- Detect both offer types (seek offers + negotiation offers)
- Display `OfferCardView` inline for both
- Show action buttons contextually
- Update to use `UnifiedOfferService`

**Update**: `CampusLink/Features/Messaging/Views/MessageBubble.swift`

Currently detects `offer_notification` messages (line ~388). Enhance:

- Support both offer directions
- Show appropriate actions based on role
- Link to full offer chain view

**Create database trigger** to auto-create chat messages:

```sql
CREATE OR REPLACE FUNCTION notify_offer_activity()
RETURNS TRIGGER AS $$
BEGIN
  -- Find or create conversation
  -- Insert message with type 'offer_notification'
  -- Queue push notification
  RETURN NEW;
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER offer_activity_trigger
AFTER INSERT OR UPDATE ON offers
FOR EACH ROW EXECUTE FUNCTION notify_offer_activity();
```

### Phase 8: Notifications

**Update**: Push notification system

Add notification types:

- `offer_received` - Someone made you an offer
- `offer_countered` - Someone countered your offer
- `offer_accepted` - Your offer was accepted
- `offer_rejected` - Your offer was rejected

Notification content includes:

- Listing title
- Offer amount
- Sender name
- Deep link to conversation or offer detail

### Phase 9: Migration & Backward Compatibility

**Data migration SQL**: `migrate_offers_to_unified.sql`

```sql
-- Add new columns
ALTER TABLE offers ADD COLUMN IF NOT EXISTS listing_type TEXT DEFAULT 'seek';
ALTER TABLE offers ADD COLUMN IF NOT EXISTS offer_from_user_id UUID;
ALTER TABLE offers ADD COLUMN IF NOT EXISTS offer_to_user_id UUID;
ALTER TABLE offers ADD COLUMN IF NOT EXISTS parent_offer_id UUID;

-- Migrate existing data (all current offers are seek-type)
UPDATE offers SET
  listing_type = 'seek',
  offer_from_user_id = seller_id,
  offer_to_user_id = seeker_id
WHERE listing_type IS NULL;

-- Add constraints
ALTER TABLE offers 
  ALTER COLUMN listing_type SET NOT NULL,
  ADD CONSTRAINT offers_listing_type_check 
    CHECK (listing_type IN ('seek', 'regular'));
```

Keep `seeker_id` and `seller_id` for now (deprecated but not dropped) to avoid breaking existing queries during transition.

### Phase 10: Business Logic & Edge Cases

**Validation**:

- Cannot offer on own listing (any type)
- Amount must be > 0
- Cannot create offer if listing sold/archived
- For regular listings: only allowed if `accepts_offers = true`
- Check blocked users
- Active order blocks accepting other offers (unless for that specific offer)

**Counter-offer logic**:

- Creates new offer row with `parent_offer_id` set
- Swaps roles: offer_from ↔ offer_to
- Previous offer status → 'countered'
- New offer status → 'pending'

**Order creation roles**:

```swift
// Determine buyer/seller based on listing type
let (buyerId, sellerId) = listing.intent == .seek 
    ? (offer.offerToUserId, offer.offerFromUserId)  // Seeker is buyer, seller is seller
    : (offer.offerFromUserId, offer.offerToUserId)  // Offerer is buyer, listing owner is seller
```

**Quantity handling**:

- Accepting offer for quantity > 1 listing only affects quantity=1
- Other offers remain valid for remaining stock

### Phase 11: Testing & Polish

**Test both directions**:

1. **Seek mode**: Create seek listing → seller makes offer → seeker counters → seller accepts → order created
2. **Negotiation mode**: Create regular listing with accepts_offers → buyer offers → seller counters → buyer accepts → order created
3. **Fee validation**: Verify buyer pays rounded-up amount, seller sees only negotiated price
4. **Multiple offers**: Multiple buyers offer on same listing, all stay open
5. **Active order**: One accepted offer blocks accepting others until order completes
6. **Chat integration**: Offers appear in messages for both types
7. **Unified view**: "My Offers" shows both sent and received correctly
8. **RLS**: Users can only see offers they're involved in

**UI/UX Polish**:

- Loading states
- Error handling
- Optimistic updates
- Pull-to-refresh
- Empty states
- Clear labeling ("Offer from X" vs "Offer to Y")

### Phase 12: Documentation

Update `docs/OFFERS_SYSTEM.md`:

- Bidirectional architecture
- Database schema with both offer types
- Code examples for both directions
- Fee calculation for offers
- Migration guide from old system

Update `log.md` with implementation details

## Files to Create

1. SQL: `migrate_offers_to_unified.sql`
2. SQL: `add_accepts_offers_field.sql`
3. SQL: `offer_notification_triggers.sql`
4. Service: `CampusLink/Core/Services/UnifiedOfferService.swift`
5. View: `CampusLink/Features/Marketplace/Views/MakeOfferSheet.swift`
6. View: `CampusLink/Features/Marketplace/Views/AllMyOffersView.swift`
7. Docs: `docs/OFFERS_SYSTEM.md`

## Files to Modify

1. `CampusLink/Core/Models/ProductModels.swift` - Update Offer model, add acceptsOffers to Listing
2. `CampusLink/Features/Marketplace/Views/EditListingView.swift` - Add accepts_offers toggle
3. `CampusLink/Features/Marketplace/Views/ListingDetailView.swift` - Add Make Offer button
4. `CampusLink/Features/Marketplace/Views/OffersListView.swift` - Support both offer types
5. `CampusLink/Features/Messaging/Views/ChatView.swift` - Handle both offer directions
6. Notification system - Add new offer notification types

## Success Metrics

- Seek mode continues working (seller→buyer offers)
- New negotiation mode works (buyer→seller offers)
- Unlimited counter-offers function properly
- Unified "My Offers" shows all activity
- Orders created with correct buyer/seller roles for both types
- Fees properly calculated (buyer pays +fees, seller sees negotiated amount)
- Both offer types appear in chat
- RLS policies enforce privacy

### To-dos

- [ ] Migrate offers table to support bidirectional offers with new columns (listing_type, offer_from_user_id, offer_to_user_id, parent_offer_id) and add accepts_offers to listings
- [ ] Update Offer model in ProductModels.swift to support both directions and add acceptsOffers field to Listing models
- [ ] Create UnifiedOfferService with methods for create/accept/reject/counter that work for both seek and regular listing offers
- [ ] Add accepts_offers toggle to EditListingView and Make Offer button to ListingDetailView for both offer types
- [ ] Update OffersListView to support both types and create AllMyOffersView showing sent/received offers in unified interface
- [ ] Enhance ChatView to display both offer types inline with appropriate action buttons
- [ ] Add offer notification types and database triggers for both offer directions
- [ ] Test both seek and negotiation flows, fee calculations, counter-offers, and add UI polish