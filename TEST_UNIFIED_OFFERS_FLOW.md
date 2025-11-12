# Test Unified Offers System

**Status**: Database migrations complete ✅  
**Date**: November 9, 2025

---

## Quick Verification

Run this in Supabase SQL Editor to verify setup:
```sql
-- Check everything is in place
SELECT * FROM (
    SELECT 'offers.listing_type' AS field, 
           EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'offers' AND column_name = 'listing_type')::TEXT AS exists
    UNION ALL
    SELECT 'listings.accepts_offers' AS field,
           EXISTS(SELECT 1 FROM information_schema.columns WHERE table_name = 'listings' AND column_name = 'accepts_offers')::TEXT AS exists
    UNION ALL
    SELECT 'offer_activity_trigger' AS field,
           EXISTS(SELECT 1 FROM pg_trigger WHERE tgname = 'offer_activity_trigger')::TEXT AS exists
) AS checks;
```

Should return 3 rows with `exists = true`

---

## Test Plan

### Test 1: Create Negotiable Listing

**Steps:**
1. Open app and go to "Post" tab
2. Create a new product listing (e.g., "Used Laptop $500")
3. **Enable the "Accept Offers" toggle** ✨ (NEW!)
4. Post the listing
5. View your listing detail - should show "View Offers" button

**Expected:**
- Toggle appears below price field
- Helper text: "Let buyers negotiate the price with you"
- Listing saved with `accepts_offers = true`

---

### Test 2: Make Offer as Buyer

**Steps:**
1. Sign in as a different user (buyer)
2. Browse to the negotiable listing
3. Should see **"Make Offer"** button (instead of just "Buy Now")
4. Tap "Make Offer"
5. Enter amount (e.g., $450)
6. Add optional message: "Would you take $450?"
7. Submit offer

**Expected:**
- Fee preview shows: "You'll pay: $463" (with fees rounded up)
- Offer created successfully
- Seller receives push notification
- Chat message appears in conversation

---

### Test 3: Seller Receives & Counters

**Steps:**
1. Switch back to seller account
2. Check notifications - should have "New Offer Received"
3. Open listing detail → "View Offers"
4. See buyer's offer: $450
5. Tap "Counter"
6. Enter $475
7. Add message: "Can you do $475?"
8. Submit counter-offer

**Expected:**
- Offer shows in list with amount and message
- Original offer status → 'countered'
- New offer created with parent_offer_id
- Buyer receives notification
- Chat updated with counter-offer

---

### Test 4: Buyer Counters Back

**Steps:**
1. Switch to buyer account
2. Check notification: "Counter-Offer Received"
3. Open chat with seller
4. See counter-offer card: $475
5. Tap "Counter"
6. Enter $460
7. Submit

**Expected:**
- Unlimited negotiation works
- Each counter swaps roles properly
- Full history visible in chat
- Notifications sent correctly

---

### Test 5: Accept Offer

**Steps:**
1. As seller, view the $460 counter-offer
2. Tap "Accept"
3. Confirm acceptance

**Expected:**
- Offer status → 'accepted'
- Order created automatically with:
  - `seller_price_cents = 46000` ($460 - seller sees this)
  - `buyer_price_cents = 47300` ($473 - buyer pays this with fees)
  - `listing_id` = original listing
  - Correct buyer/seller IDs
- Buyer receives notification to complete payment
- Order appears in "My Transactions"

---

### Test 6: Verify Fees

**Check Order Details:**

Seller view:
- Should see: $460.00 (negotiated amount)
- No fee information visible

Buyer view:
- Should see: $473.00 (negotiated + fees, rounded up)
- Fee breakdown:
  - Offer: $460.00
  - Processing fee: $13.64
  - Subtotal: $473.64
  - You pay: $473.00 (rounded up)

Platform profit:
- $473.00 - $460.00 - $13.64 = -$0.64 (covered by rounding)
- Actually: Rounded to $473, so small loss acceptable

---

### Test 7: Seek Mode (Existing Feature)

**Verify backward compatibility:**
1. Create a "seek" listing (I want X)
2. As seller, make an offer
3. As buyer, accept
4. Should work exactly as before

**Expected:**
- All existing seek mode functionality intact
- Uses same offers table
- `listing_type = 'seek'` properly set
- Notifications work

---

### Test 8: Multiple Offers

**Steps:**
1. Have 3 different buyers make offers on same listing
2. All offers should stay pending
3. Accept one offer → creates order
4. Try to accept another offer

**Expected:**
- All 3 offers visible to seller
- Each buyer only sees their own offer
- After accepting one, others show warning
- Cannot accept second offer while first order active

---

### Test 9: My Offers View

**Steps:**
1. Navigate to Wallet tab (or wherever you added it)
2. Tap "My Offers"
3. Switch between "Received" and "Sent" tabs

**Expected:**
- Received: Shows offers others made to you
- Sent: Shows offers you made to others
- Each shows listing preview, amount, status
- Tap to see negotiation history
- Quick actions: Accept/Reject/Counter

---

## Database Queries for Testing

**Check offers created:**
```sql
SELECT 
    id,
    listing_type,
    offer_from_user_id,
    offer_to_user_id,
    price_cents,
    status,
    parent_offer_id,
    created_at
FROM offers
ORDER BY created_at DESC
LIMIT 10;
```

**Check negotiation chains:**
```sql
WITH RECURSIVE offer_chain AS (
    -- Start with root offers (no parent)
    SELECT id, parent_offer_id, price_cents, status, 0 AS level
    FROM offers
    WHERE parent_offer_id IS NULL
    
    UNION ALL
    
    -- Follow the chain
    SELECT o.id, o.parent_offer_id, o.price_cents, o.status, oc.level + 1
    FROM offers o
    JOIN offer_chain oc ON o.parent_offer_id = oc.id
)
SELECT * FROM offer_chain
ORDER BY id, level;
```

**Check listings with offers enabled:**
```sql
SELECT 
    id,
    title,
    intent,
    accepts_offers,
    price
FROM listings
WHERE accepts_offers = true
ORDER BY created_at DESC
LIMIT 10;
```

---

## Known Issues / Limitations

1. **Chat Cards**: Offer cards in ChatView are ready but basic - enhance with richer UI later
2. **Expiration**: Offers don't expire yet (future enhancement)
3. **Analytics**: No tracking of acceptance rates yet
4. **Bulk Actions**: Can't accept/reject multiple offers at once

---

## Success Criteria ✅

- [x] Database schema migrated
- [x] Swift models updated
- [x] Service layer complete
- [x] UI components created
- [x] Build succeeds
- [ ] Create negotiable listing works
- [ ] Make offer as buyer works
- [ ] Counter-offers work (unlimited)
- [ ] Accept creates order with correct fees
- [ ] Seek mode still works
- [ ] Notifications send correctly
- [ ] Multiple offers stay open
- [ ] RLS enforces privacy

---

## Quick Start Testing

**1 Minute Test:**
```
1. Create listing with "Accept Offers" ON
2. Log in as different user
3. Make offer
4. Accept it
5. Verify order created
```

**Status**: Ready to test! 🎯

---

**Next**: Test the flow in the simulator and report any issues!

Darragh

