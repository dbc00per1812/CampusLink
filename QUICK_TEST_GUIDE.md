# Quick Test Guide - Unified Offers System

## 🚀 Ready to Test!

All critical fixes are complete. Here's the fastest way to verify everything works:

---

## Test Scenario 1: Buyer Makes Offer (3 minutes)

### Setup
- **User A**: Has a listing for sale
- **User B**: Wants to buy it

### Steps

1. **User A: Create Listing**
   - Open app → Post tab
   - Create new product listing
   - **IMPORTANT**: Toggle "Accept Offers" to ON
   - Set price: $100
   - Post it

2. **User B: Make Offer**
   - Find User A's listing
   - Tap "Make Offer" button
   - Enter: $80
   - Add message: "Best I can do"
   - Submit
   - **Verify**: Shows "You'll pay: $XX.XX" (with fees)

3. **User A: Check Notification**
   - Should receive push notification
   - **Verify**: "New Offer Received" notification

4. **User A: View Offer**
   - Option 1: Profile tab → "My Offers" → Received tab
   - Option 2: On listing → "View Offers"
   - **Verify**: See $80 offer from User B

5. **User A: Accept Offer**
   - Tap "Accept"
   - **Verify**: Order created successfully
   - **Verify**: User A sees $80 (their price)

6. **User B: Check Order**
   - **Verify**: Received "Offer Accepted" notification
   - **Verify**: Order shows with fees

---

## Test Scenario 2: Counter-Offer (2 minutes)

### Steps

1. **User A: Counter Instead of Accept**
   - Tap "Counter" instead
   - Enter: $90
   - Add message: "Meet in the middle?"
   - Submit

2. **User B: Receive Counter**
   - **Verify**: Notification received
   - Profile → "My Offers" → Sent tab
   - See counter-offer: $90

3. **User B: Accept Counter**
   - Tap "Accept"
   - **Verify**: Order created at $90
   - **Verify**: User B sees $XX.XX (with fees)
   - **Verify**: User A sees $90 (no fees)

---

## Test Scenario 3: Seek Mode (3 minutes)

### Steps

1. **User A: Create Wanted Post**
   - Post tab
   - Select "Wanted" (seek mode)
   - Title: "Looking for PS5 controller"
   - Budget: $50-60
   - Post it

2. **User B: Make Offer**
   - Find wanted post
   - Tap "Offer My Item"
   - Enter: $55
   - **Verify**: Shows "You'll receive: $55.00" (seller perspective)
   - Submit

3. **User A: View Offers**
   - Tap "View Offers" on wanted post
   - **Verify**: See $55 offer
   - Accept or counter

---

## Quick Checks ✅

After testing, verify:

- [ ] Push notifications work
- [ ] Chat messages created automatically
- [ ] "My Offers" accessible from Profile
- [ ] Both sent and received offers visible
- [ ] Fee calculations correct
- [ ] Counter-offers work
- [ ] Final order prices correct
- [ ] Both seek and regular listing offers work

---

## If Something Doesn't Work

### 1. Notification not received?
- Check app notification permissions
- Check trigger was deployed: Run in Supabase SQL editor:
  ```sql
  SELECT * FROM pg_trigger WHERE tgname = 'offer_activity_trigger';
  ```
  Should return a row.

### 2. "My Offers" button not showing?
- Pull to refresh Profile tab
- Restart app

### 3. "Make Offer" button not showing?
- Verify listing has `accepts_offers = true`
- Check in Supabase:
  ```sql
  SELECT id, title, accepts_offers FROM listings WHERE id = 'YOUR_LISTING_ID';
  ```

### 4. Fee calculations wrong?
- Check `FeeCalculationService` 
- Verify Stripe fee calculation (2.9% + $0.30)

---

## Expected Behavior

### Buyer Offering on Regular Listing
- **Buyer sees**: Offer amount + fees (rounded up)
- **Seller sees**: Just the offer amount (net to them)
- **Example**: Buyer offers $50 → Buyer pays $52, Seller gets $50

### Seller Offering on Seek Post
- **Seller sees**: Offer amount (what they'll receive)
- **Buyer sees**: Offer amount + fees (rounded up) when accepting
- **Example**: Seller offers $60 → Buyer pays $62, Seller gets $60

---

## Success Criteria

System is working if:
1. ✅ Offers can be created
2. ✅ Notifications are received
3. ✅ Offers visible in "My Offers"
4. ✅ Accept/Reject/Counter work
5. ✅ Orders created with correct prices
6. ✅ Both listing types work (seek + regular)

---

**Time to test**: ~8-10 minutes for all scenarios

Good luck! 🎉

