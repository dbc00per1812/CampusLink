# Unified Offers System - Complete Logic Review

## Date: November 11, 2025
## Status: ✅ All Logic Verified and Fixed

---

## Overview

Reviewed and fixed all offer system logic after user testing. System now works correctly for both regular and seek listings.

---

## 1. Offer Creation Flow ✅

### Regular Listings (Buyer → Seller)
```
Buyer clicks "Make Offer" on seller's listing
  ↓
MakeOfferSheet opens
  ↓
Buyer enters amount (just the price, no fee display)
  ↓
UnifiedOfferService.createOffer()
  - listing_id = listing.id
  - listing_type = "regular"
  - offer_from_user_id = buyer ID
  - offer_to_user_id = seller ID
  - price_cents = offer amount
  ↓
Database trigger fires
  ↓
  ├─→ Creates conversation (buyer_id, seller_id)
  ├─→ Inserts chat message
  └─→ Queues push notification to seller
  ↓
Seller receives notification ✅
```

### Seek Listings (Seller → Buyer)
```
Seller clicks "Offer My Item" on buyer's wanted post
  ↓
MakeOfferSheet opens
  ↓
Seller enters amount
  ↓
UnifiedOfferService.createOffer()
  - listing_id = seek listing.id
  - listing_type = "seek"
  - offer_from_user_id = seller ID
  - offer_to_user_id = buyer ID (seeker)
  - price_cents = offer amount
  ↓
Database trigger fires
  ↓
  ├─→ Creates conversation (buyer_id, seller_id)
  ├─→ Inserts chat message
  └─→ Queues push notification to buyer
  ↓
Buyer receives notification ✅
```

---

## 2. Viewing Offers ✅

### OffersListView (Specific Listing)
```
Query:
.from("offers")
.eq("listing_id", value: listing.id)
.eq("offer_to_user_id", value: currentUserId)
.in("status", values: ["pending", "accepted"])  ✅ Excludes declined
.order("created_at", ascending: false)

Display:
- Regular listings: "Offer from Buyer" + buyer name ✅
- Seek listings: "Offer from Seller" + seller name ✅
```

### AllMyOffersView (All Offers)
```
Query via UnifiedOfferService.getMyOffers():
.from("offers")
.or("offer_from_user_id.eq.{userId},offer_to_user_id.eq.{userId}")
.in("status", values: ["pending", "accepted", "countered"])  ✅ Excludes declined
.order("created_at", ascending: false)

Separated into:
- Sent offers: where offer_from_user_id = currentUserId
- Received offers: where offer_to_user_id = currentUserId
```

---

## 3. Accepting Offers ✅

### Logic Flow
```
User clicks "Accept"
  ↓
UnifiedOfferService.acceptOffer()
  ↓
Verify user is receiver (offer_to_user_id) ✅
  ↓
Determine buyer/seller based on listing type:
  - Regular: buyer = offer_from_user_id, seller = offer_to_user_id
  - Seek: buyer = offer_to_user_id, seller = offer_from_user_id
  ↓
Calculate prices:
  - sellerPriceCents = offer.price_cents
  - buyerPriceCents = FeeCalculationService.calculateBuyerPrice(sellerPriceCents)
  ↓
Create Order via OrderService
  - order.buyer_id = buyer
  - order.seller_id = seller
  - order.seller_price_cents = seller price
  - order.buyer_price_cents = buyer price (with fees)
  - order.payment_status = "pending"
  ↓
Update offer.status = "accepted"
Update offer.order_id = new order ID
  ↓
Return order
```

### UI Behavior After Accept
```
If current user IS buyer:
  ↓
  Show payment sheet ✅
  User completes payment
  Order status → "paid"
  
If current user IS seller:
  ↓
  Show success message: "Buyer will be notified to pay" ✅
  No payment sheet shown
  Buyer gets notification to complete payment
```

---

## 4. Declining Offers ✅

### Logic Flow
```
User clicks "Decline"
  ↓
UnifiedOfferService.rejectOffer()
  ↓
Verify user is receiver (offer_to_user_id) ✅
  ↓
Update offer.status = "declined"
  ↓
Database trigger fires (status change)
  ↓
Notification sent to offerer
  ↓
UI refreshes
  ↓
Declined offer disappears (filtered out) ✅
```

### Query Filters
```
OffersListView.loadOffers():
.in("status", values: ["pending", "accepted"])
❌ Excludes "declined" and "withdrawn"

UnifiedOfferService.getMyOffers():
.in("status", values: ["pending", "accepted", "countered"])
❌ Excludes "declined" and "withdrawn"

Result: Declined offers immediately disappear ✅
```

---

## 5. Counter-Offers ✅

### Logic Flow
```
User clicks "Counter" on received offer
  ↓
Counter offer sheet opens
  ↓
User enters new amount and message
  ↓
UnifiedOfferService.counterOffer()
  ↓
Verify user is participant ✅
  ↓
Update parent offer:
  parent_offer.status = "countered"
  ↓
Create new offer:
  - parent_offer_id = original offer ID
  - listing_id = same listing
  - listing_type = same type
  - offer_from_user_id = current user (swapped)
  - offer_to_user_id = other user (swapped)
  - price_cents = counter amount
  - status = "pending"
  ↓
Database trigger fires
  ↓
Other user receives counter-offer notification
  ↓
They can accept/reject/counter again
```

### Counter-Offer Chain
```
Buyer offers $50
  ↓
Seller counters $60 (parent_offer_id = offer 1)
  ↓
Buyer counters $55 (parent_offer_id = offer 2)
  ↓
Seller accepts $55
  ↓
Order created at $55 ✅
```

---

## 6. Order Creation from Accepted Offer ✅

### Buyer/Seller Determination
```
Regular Listings:
  buyer_id = offer.offer_from_user_id  ✅
  seller_id = offer.offer_to_user_id   ✅

Seek Listings:
  buyer_id = offer.offer_to_user_id    ✅
  seller_id = offer.offer_from_user_id ✅
```

### Price Calculation
```
sellerPriceCents = offer.price_cents (negotiated amount)
buyerPriceCents = FeeCalculationService.calculateBuyerPrice(sellerPriceCents)

Example:
  Negotiated: $50.00
  Seller sees: $50.00 (their net)
  Buyer pays: $52.00 (includes Stripe fees, rounded up)
  Platform profit: $2.00 - (actual Stripe fees)
```

### Order Fields
```
OrderCreate {
  listing_id: offer.listing_id
  buyer_id: determined above
  seller_id: determined above
  price_cents: sellerPriceCents (legacy)
  seller_price_cents: sellerPriceCents
  buyer_price_cents: buyerPriceCents
  payment_method: .card (buyer will pay)
  quantity: 1
}
```

---

## 7. Payment Flow ✅

### When Seller Accepts Buyer's Offer
```
Seller clicks "Accept"
  ↓
Order created (payment_status = "pending")
  ↓
Seller sees: "Buyer will be notified to pay" ✅
  ↓
Buyer receives notification
  ↓
Buyer navigates to order
  ↓
Buyer completes payment
  ↓
Order.payment_status = "paid"
Order.order_status = "confirmed"
```

### When Buyer Accepts Seller's Offer (Seek Mode)
```
Buyer clicks "Accept"
  ↓
Order created
  ↓
Buyer sees payment sheet ✅
  ↓
Buyer completes payment
  ↓
Order.payment_status = "paid"
Order.order_status = "confirmed"
```

---

## 8. Database Trigger Logic ✅

### When Offer Created (INSERT)
```
trigger: notify_offer_activity()

If parent_offer_id IS NULL:
  - Type: "offer_received"
  - Notification: "New Offer Received"
  - Message: "💰 New Offer: $X.XX"
  
If parent_offer_id IS NOT NULL:
  - Type: "offer_countered"
  - Notification: "Counter-Offer Received"
  - Message: "🔄 Counter-Offer: $X.XX"

For both:
  - Find or create conversation (buyer_id, seller_id) ✅
  - Insert message into conversation
  - Queue push notification
```

### When Offer Status Changes (UPDATE)
```
If status → "accepted":
  - Type: "offer_accepted"
  - Notification: "Offer Accepted"
  - Message: "✅ Offer Accepted: $X.XX"
  - Sent to: offer_from_user_id (original offerer)

If status → "declined":
  - Type: "offer_rejected"
  - Notification: "Offer Declined"
  - Message: "❌ Offer Declined: $X.XX"
  - Sent to: offer_from_user_id (original offerer)
```

---

## 9. Status Flow ✅

```
Offer Created
  ↓
status = "pending"
  ↓
  ├─→ Accepted → status = "accepted", order_id set
  ├─→ Declined → status = "declined"
  └─→ Countered → status = "countered", new offer created

Counter-Offer
  ↓
Original offer: status = "countered"
New offer: status = "pending"
  ↓
  ├─→ Accepted → status = "accepted"
  ├─→ Declined → status = "declined"
  └─→ Countered again → chain continues
```

---

## 10. Conversation Creation ✅

### Buyer/Seller Determination in Trigger
```
If listing_type = "seek":
  buyer_id = offer_to_user_id (seeker)
  seller_id = offer_from_user_id (seller offering)

If listing_type = "regular":
  buyer_id = offer_from_user_id (buyer offering)
  seller_id = offer_to_user_id (seller's listing)
```

### Conversation Query
```
SELECT id FROM conversations
WHERE (buyer_id = v_buyer_id AND seller_id = v_seller_id)
   OR (buyer_id = v_seller_id AND seller_id = v_buyer_id)
LIMIT 1

If not found:
  INSERT INTO conversations (buyer_id, seller_id, listing_id, ...)

If found:
  UPDATE conversations SET last_message_at = NOW()
```

---

## 11. Permissions & Security ✅

### RLS Policies (from migration)
```
Offers table:
- Users can view offers where they are participant
  (offer_from_user_id OR offer_to_user_id = current user)
- Users can create offers (INSERT allowed)
- Users can update their own offers

Verification in Code:
- acceptOffer(): Verifies user is receiver (offer_to_user_id)
- rejectOffer(): Verifies user is receiver (offer_to_user_id)
- counterOffer(): Verifies user is participant
```

---

## 12. Edge Cases Handled ✅

### Listing Already Sold
```
acceptOffer() checks:
- listing.is_sold = false ✅
- listing.archived = false ✅

If sold/archived: throws OfferServiceError.listingNotAvailable
```

### Offer Already Accepted
```
acceptOffer() checks:
- offer.status = "pending" ✅

If not pending: throws OfferServiceError.offerNotPending
```

### Unauthorized User
```
All methods verify:
- Current user is participant ✅
- Current user has permission for action ✅

If unauthorized: throws OfferServiceError.unauthorized
```

### Invalid Amount
```
createOffer() checks:
- amountCents > 0 ✅

If invalid: throws OfferServiceError.invalidAmount
```

---

## 13. UI/UX Behavior Summary

| Action | Regular Listing | Seek Listing |
|--------|----------------|--------------|
| **Offer Button** | "Make Offer" (buyer) | "Offer My Item" (seller) |
| **Offer Label** | "Offer from Buyer" | "Offer from Seller" |
| **Accept (Receiver)** | Seller: show success msg | Buyer: show payment sheet |
| **Accept (Offerer)** | Buyer: show payment sheet | Seller: show success msg |
| **Decline** | Disappears immediately | Disappears immediately |
| **Counter** | Back-and-forth enabled | Back-and-forth enabled |

---

## 14. Testing Checklist

### ✅ Regular Listing Flow
- [x] Buyer can make offer
- [x] Seller receives notification
- [x] Seller sees "Offer from Buyer"
- [x] Seller can accept (no payment sheet)
- [x] Seller can decline (offer disappears)
- [x] Seller can counter
- [x] Buyer accepts counter (payment sheet shown)
- [x] Order created with correct prices

### ✅ Seek Listing Flow
- [x] Seller can offer on wanted post
- [x] Buyer receives notification
- [x] Buyer sees "Offer from Seller"
- [x] Buyer can accept (payment sheet shown)
- [x] Buyer can decline (offer disappears)
- [x] Buyer can counter
- [x] Seller accepts counter (no payment sheet)
- [x] Order created with correct prices

### ✅ General Functionality
- [x] Declined offers disappear from all views
- [x] Counter-offers create proper chain
- [x] Chat messages created automatically
- [x] Push notifications sent
- [x] Conversation created/updated
- [x] Fees calculated correctly
- [x] RLS policies enforced

---

## Conclusion

**Status**: ✅ All logic verified and working correctly

The unified offers system now properly handles:
- Both regular and seek listing types
- Correct buyer/seller determination
- Proper payment flow (only buyers see payment sheets)
- Role labels that make sense
- Declined offers that actually disappear
- Counter-offer chains
- Database triggers and notifications

**Ready for production use!**

---

Generated: November 11, 2025

