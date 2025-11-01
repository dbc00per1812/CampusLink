# Test Guide: Offer Functionality

## Overview
This guide walks through testing the complete offer flow from creation to acceptance and payment.

---

## Prerequisites
- 2 test user accounts (User A = Seeker, User B = Seller)
- Both users verified and logged in
- Both users have the same email domain for campus filtering (if enabled)

---

## Test Flow

### Phase 1: Create a Seek Listing (User A - Seeker)

**Steps:**
1. Log in as User A
2. Navigate to Home tab
3. Tap the "+" button
4. Select "Post a Wanted Item" (Seek mode)
5. Fill in the details:
   - **Title**: "Looking for Calculus Textbook"
   - **Description**: "Need Math 211 textbook for this semester"
   - **Price Range**: $30 - $50
   - **Category**: Books
   - **Condition**: Any
6. Tap "Post"

**Expected Result:**
- ✅ Listing appears in feed with "WANTED" badge
- ✅ Listing shows price range
- ✅ "Offer My Item" button visible on listing detail

---

### Phase 2: Make an Offer (User B - Seller)

**Steps:**
1. Log out, then log in as User B
2. Find the seek listing in the home feed (you may need to disable domain filter temporarily)
3. Tap on the seek listing to view details
4. Tap "Offer My Item" button
5. Enter offer amount using keypad: **$40.00**
6. Add optional message: "I have the textbook in great condition"
7. Tap "Submit Offer"

**Expected Results:**
- ✅ Success message appears
- ✅ Offer is submitted successfully
- ✅ User B is redirected or sees confirmation

**Database Verification:**
```sql
-- Run in Supabase SQL Editor
SELECT 
    o.id,
    o.price_cents,
    o.status,
    o.message,
    l.title as seek_title,
    u.name as seller_name
FROM offers o
JOIN listings l ON o.seek_listing_id = l.id
JOIN profiles u ON o.seller_id = u.id
ORDER BY o.created_at DESC
LIMIT 5;
```
Expected: New offer with price_cents = 4000, status = 'pending'

---

### Phase 3: View Offer Notifications (User A - Seeker)

**Steps:**
1. Log out, then log in as User A
2. Check notifications:
   - **Bell icon** should show a new notification
   - Notification should say: "New Offer! Someone offered $40.00 for your post"

3. **View offer in Messages:**
   - Navigate to Messages tab
   - Should see a new conversation with User B
   - Message should contain: "💰 New Offer: $40.00"
   - "Accept Offer" and "View Details" buttons should be visible

4. **View offer in Wallet:**
   - Navigate to Wallet tab
   - Look for "Pending Offers" section
   - Should see the $40.00 offer listed
   - Green "Accept" button should be visible

**Expected Results:**
- ✅ Notification received
- ✅ Offer visible in Messages with action buttons
- ✅ Offer visible in Wallet under "Pending Offers"
- ✅ Offer shows correct price and details

---

### Phase 4: Accept the Offer (User A - Seeker)

**Option A: Accept from Messages**
**Steps:**
1. In Messages, tap "Accept Offer" button on the offer message
2. Review offer details in the popup
3. Confirm acceptance

**Option B: Accept from Wallet**
**Steps:**
1. In Wallet, tap on the offer in "Pending Offers" section
2. Review offer details in the sheet
3. Tap "Accept Offer" button
4. Confirm acceptance

**Expected Results:**
- ✅ Confirmation message appears
- ✅ Offer status changes to "accepted"
- ✅ An order is automatically created
- ✅ User is prompted to complete payment

**Database Verification:**
```sql
-- Check offer status
SELECT id, status, order_id, price_cents
FROM offers
WHERE status = 'accepted'
ORDER BY updated_at DESC
LIMIT 5;

-- Check that order was created
SELECT 
    o.id,
    o.status,
    o.total_price,
    o.buyer_id,
    o.seller_id,
    l.title
FROM orders o
JOIN listings l ON o.listing_id = l.id
WHERE o.created_at > NOW() - INTERVAL '5 minutes'
ORDER BY o.created_at DESC;
```

---

### Phase 5: Verify Seller Notification (User B - Seller)

**Steps:**
1. Log out, then log in as User B
2. Check notifications
3. Should see: "Offer Accepted! Your offer of $40.00 was accepted. Complete payment to proceed."

**Expected Results:**
- ✅ Seller receives acceptance notification
- ✅ Seller can see the accepted offer in their offers list

---

### Phase 6: Complete Payment (User A - Seeker)

**Steps:**
1. Log in as User A
2. Navigate to Wallet tab
3. Find the new order in "Pending Orders" or "Active Orders"
4. Tap on the order
5. Choose payment method:
   - **Option A**: Pay with Wallet Balance (if sufficient)
   - **Option B**: Pay with Card (Stripe integration)
6. Complete payment

**Expected Results:**
- ✅ Payment processes successfully
- ✅ Order status changes to "pending_fulfillment"
- ✅ Funds are held in escrow
- ✅ Both parties receive confirmation

---

### Phase 7: Test Decline Flow (Optional)

**Create another offer and decline it:**

**Steps:**
1. Repeat Phases 1-3 to create another offer
2. As User A (Seeker), tap "Decline" instead of "Accept"
3. Optionally add a decline reason: "Found another seller"
4. Confirm decline

**Expected Results:**
- ✅ Offer status changes to "declined"
- ✅ User B receives decline notification
- ✅ Offer no longer appears in pending offers

**Database Verification:**
```sql
SELECT id, status, message
FROM offers
WHERE status = 'declined'
ORDER BY updated_at DESC
LIMIT 5;
```

---

## Edge Cases to Test

### Test 1: Multiple Offers on Same Seek
- Have 2-3 different sellers make offers on the same seek listing
- Verify all offers appear correctly
- Accept one offer
- Verify other pending offers are automatically declined
- Verify seek listing is archived

### Test 2: Offer with No Listing
- Make an offer with just a custom price (no linked listing)
- Verify offer_listing_id is null
- Verify acceptance flow still works

### Test 3: Invalid Price Amounts
- Try to submit offer with $0.00 → Should be prevented
- Try to submit offer with negative amount → Should be prevented
- Try to submit offer outside seeker's budget range → Should show warning

### Test 4: Expired Offers
- Check if offers have expiration logic
- Verify expired offers cannot be accepted

---

## Database Functions to Verify

### Check RPC Functions Exist
```sql
-- Verify these functions exist and work
SELECT proname, prosrc 
FROM pg_proc 
WHERE proname IN ('accept_offer', 'decline_offer', 'get_user_offers');
```

### Test accept_offer RPC
```sql
-- Test the accept_offer function (replace with actual IDs)
SELECT * FROM accept_offer(
    p_offer_id := 'YOUR-OFFER-UUID',
    p_user_id := 'YOUR-USER-UUID'
);
```

### Test get_user_offers RPC
```sql
-- Get offers for current user
SELECT * FROM get_user_offers(
    p_user_id := 'YOUR-USER-UUID',
    p_role := 'seeker'  -- or 'seller' or 'both'
);
```

---

## Notification Triggers

### Verify Triggers Are Active
```sql
-- Check offer notification triggers
SELECT 
    trigger_name, 
    event_manipulation, 
    event_object_table,
    action_statement
FROM information_schema.triggers
WHERE event_object_table = 'offers'
ORDER BY trigger_name;
```

Expected triggers:
- `offer_created_notification_trigger` (INSERT)
- `offer_status_notification_trigger` (UPDATE)

---

## Common Issues & Solutions

### Issue 1: Offers Not Appearing
**Check:**
- User permissions on `offers` table
- RLS policies allow reading offers
- Offer status is 'pending'
- User IDs match correctly

### Issue 2: Accept Button Not Working
**Check:**
- `accept_offer` RPC function exists
- User has permission to call RPC
- Offer hasn't already been accepted
- Network connectivity

### Issue 3: Notifications Not Sent
**Check:**
- Triggers are enabled (see SQL above)
- Notification service is running
- APNs/FCM tokens are valid
- User has notifications enabled

### Issue 4: Payment Fails After Acceptance
**Check:**
- Stripe integration is configured
- User has payment method added
- Wallet has sufficient balance (if paying with wallet)
- Order was created correctly with proper price

---

## Success Criteria

The offer functionality is working correctly if:

- ✅ Sellers can create offers on seek listings
- ✅ Seekers receive notifications for new offers
- ✅ Offers appear in Messages and Wallet
- ✅ Seekers can accept offers successfully
- ✅ Orders are automatically created on acceptance
- ✅ Seekers can decline offers with reasons
- ✅ All parties receive appropriate notifications
- ✅ Payment flow works after acceptance
- ✅ Multiple offers are handled correctly
- ✅ Database triggers fire correctly

---

## Quick Test Script (For Developers)

If you have access to the database, you can create test data:

```sql
-- 1. Create a seek listing
INSERT INTO listings (
    id, user_id, title, description, 
    price_cents, category, status, listing_type,
    min_price_cents, max_price_cents
) VALUES (
    gen_random_uuid(),
    'YOUR-USER-A-ID',
    'Looking for Calculus Textbook',
    'Need Math 211 textbook',
    4000, -- average price
    'Books',
    'active',
    'seek',
    3000, -- min
    5000  -- max
) RETURNING id;

-- 2. Create an offer (use the returned listing ID)
INSERT INTO offers (
    id, seek_listing_id, seeker_id, seller_id,
    price_cents, message, status
) VALUES (
    gen_random_uuid(),
    'YOUR-LISTING-ID',
    'YOUR-USER-A-ID',
    'YOUR-USER-B-ID',
    4000,
    'I have the textbook in great condition',
    'pending'
) RETURNING id;

-- 3. Check that notifications were created
SELECT * FROM notifications 
WHERE type = 'listing_interest'
ORDER BY created_at DESC 
LIMIT 5;
```

---

## Next Steps After Testing

1. **Document any bugs found** in GitHub issues
2. **Update log.md** with test results
3. **Consider adding unit tests** for OfferService
4. **Test UI/UX flow** for any confusing interactions
5. **Verify performance** with many offers on a single seek

---

**Test conducted by:** _____________  
**Date:** _____________  
**Result:** PASS / FAIL / PARTIAL  
**Notes:** ___________________________

