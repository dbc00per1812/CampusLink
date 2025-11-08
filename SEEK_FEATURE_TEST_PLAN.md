# Seek Feature Test Plan

## Date: November 8, 2025
## Status: Testing & Validation

---

## 1. Post Creation Tests

### ✅ Test 1.1: Valid Seek Post (Max Budget Only)
- **Steps**:
  1. Open Post tab
  2. Select "Buy" intent
  3. Enter title, description, category
  4. Leave Min Budget empty
  5. Enter Max Budget: $100
  6. Click "Post Buying"
- **Expected**: Post created successfully
- **Status**: READY TO TEST

### ✅ Test 1.2: Valid Seek Post (Min & Max Budget)
- **Steps**:
  1. Open Post tab
  2. Select "Buy" intent
  3. Enter title, description, category
  4. Enter Min Budget: $50
  5. Enter Max Budget: $100
  6. Click "Post Buying"
- **Expected**: Post created successfully
- **Status**: READY TO TEST

### ❌ Test 1.3: Invalid - Min > Max (FIXED)
- **Steps**:
  1. Open Post tab
  2. Select "Buy" intent
  3. Enter title, description, category
  4. Enter Min Budget: $500
  5. Enter Max Budget: $100
  6. Observe warning message appears
  7. Try to click "Post Buying"
- **Expected**: 
  - Orange warning: "Minimum budget cannot be greater than maximum budget"
  - If user tries to submit, alert: "Minimum budget ($500) cannot be greater than maximum budget ($100). Please adjust your budget range."
- **Status**: ✅ FIXED

### ❌ Test 1.4: Invalid - Negative Budget
- **Steps**:
  1. Enter Min Budget: -$50
  2. Try to submit
- **Expected**: Alert: "Minimum budget cannot be negative."
- **Status**: ✅ FIXED

### ❌ Test 1.5: Invalid - Zero Max Budget
- **Steps**:
  1. Enter Max Budget: $0
  2. Try to submit
- **Expected**: Alert: "Maximum budget must be greater than zero."
- **Status**: ✅ FIXED

### ✅ Test 1.6: Seek Post with Delivery Method
- **Steps**:
  1. Create seek post for Product
  2. Select "Pickup" or "Delivery"
  3. Submit
- **Expected**: Post created with delivery preference
- **Status**: READY TO TEST

### ✅ Test 1.7: Seek Post for Service
- **Steps**:
  1. Create seek post
  2. Select "Service" type
  3. Submit
- **Expected**: Post created as service seek
- **Status**: READY TO TEST

---

## 2. Display & Filtering Tests

### ✅ Test 2.1: SEEKING Badge on Home Page
- **Steps**:
  1. Create a seek post
  2. Go to Home tab
  3. View the listing card
- **Expected**: Orange "SEEKING" badge visible at bottom-left of image
- **Status**: ✅ IMPLEMENTED

### ✅ Test 2.2: SEEKING Badge on Detail View
- **Steps**:
  1. Tap on a seek post
  2. View detail page
- **Expected**: Orange "SEEKING" badge visible under title with category/type badges
- **Status**: ✅ IMPLEMENTED

### ✅ Test 2.3: Filter by "Wanted" Tab
- **Steps**:
  1. Go to Home tab
  2. Select "Wanted" filter
  3. View results
- **Expected**: Only seek posts shown
- **Status**: READY TO TEST

### ✅ Test 2.4: Budget Display
- **Steps**:
  1. View seek post with min/max budget
  2. Check displayed budget
- **Expected**: Shows "$50 - $100" or "Up to $100"
- **Status**: READY TO TEST

---

## 3. Offer Submission Tests

### ✅ Test 3.1: Submit Offer
- **Steps**:
  1. As a seller, view a seek post (not your own)
  2. Click "Offer My Item" button
  3. Enter offer amount within budget
  4. Add optional message
  5. Click "Send Offer"
- **Expected**: Offer created, confirmation shown
- **Status**: READY TO TEST

### ✅ Test 3.2: Offer Above Budget
- **Steps**:
  1. Submit offer > max budget
- **Expected**: Should still work (seeker can accept or decline)
- **Status**: READY TO TEST

### ✅ Test 3.3: View My Offers (as Seller)
- **Steps**:
  1. Go to Wallet tab
  2. Select "Offers" tab
  3. View sent offers
- **Expected**: See list of offers made to seekers
- **Status**: READY TO TEST

### ✅ Test 3.4: View Received Offers (as Seeker)
- **Steps**:
  1. Go to your own seek post detail
  2. Click "View Offers"
  3. See list of offers
- **Expected**: See offers with amounts and messages
- **Status**: READY TO TEST

---

## 4. Expiration Tests

### ✅ Test 4.1: Seek Post with Expiration Date
- **Steps**:
  1. Create seek post
  2. Set expiration date to tomorrow
  3. Wait for archiver to run (30 min intervals)
- **Expected**: Post archived after expiration
- **Status**: READY TO TEST

### ✅ Test 4.2: Default Expiration (7 days)
- **Steps**:
  1. Create seek post
  2. Don't change expiration date
- **Expected**: Defaults to 7 days from now
- **Status**: READY TO TEST

---

## 5. Database Constraints Verification

### ✅ Constraint 5.1: intent must be 'offer' or 'seek'
- **Status**: ✅ VERIFIED (line 58 in schema)

### ✅ Constraint 5.2: budget_min >= 0
- **Status**: ✅ VERIFIED (line 59 in schema)

### ✅ Constraint 5.3: budget_max >= 0
- **Status**: ✅ VERIFIED (line 60 in schema)

### ✅ Constraint 5.4: budget_min <= budget_max
- **Status**: ✅ INFERRED (from error message, validation added)

---

## 6. Edge Cases

### ✅ Test 6.1: Own Seek Post Viewing
- **Steps**:
  1. View your own seek post
- **Expected**: No "Offer My Item" button, only Edit/Delete
- **Status**: READY TO TEST

### ✅ Test 6.2: Guest User Viewing Seek Post
- **Steps**:
  1. Sign out
  2. View a seek post
- **Expected**: "Sign in to make an offer" button
- **Status**: READY TO TEST

### ✅ Test 6.3: Blocked User Cannot Offer
- **Steps**:
  1. Block a user
  2. Try to view their seek post
- **Expected**: Post hidden or offer disabled
- **Status**: READY TO TEST

### ✅ Test 6.4: Campus Filtering for Seek Posts
- **Steps**:
  1. Create seek post at Purdue
  2. Sign in as IU user
  3. View home page
- **Expected**: Purdue seek post not visible to IU user
- **Status**: READY TO TEST (already implemented for all posts)

---

## Known Issues Fixed

### ✅ Issue #1: Min Budget > Max Budget
- **Problem**: Database constraint error when min > max
- **Solution**: Added validation with visual warning and error message
- **Status**: ✅ FIXED

---

## Next Steps

1. **Test all scenarios above** with real app usage
2. **Verify offer acceptance and payment flow**
3. **Test notification system for new offers**
4. **Verify escrow release for accepted offers**
5. **Test rating system after seek transaction**

---

## Feature Completeness Checklist

- ✅ Database schema for seek posts
- ✅ Database schema for offers table
- ✅ Post creation UI for seek posts
- ✅ Budget validation (min/max)
- ✅ Visual budget warnings
- ✅ SEEKING badge on cards
- ✅ SEEKING badge on detail view
- ✅ Filtering by "Wanted" tab
- ✅ Offer submission UI
- ✅ Offer storage in database
- ✅ Offer viewing UI (seeker side)
- ✅ Offer viewing UI (seller side)
- ✅ Seek post expiration handling
- ⏳ Offer acceptance & payment flow
- ⏳ Notification system for offers
- ⏳ Rating system for seek transactions

**Overall Status**: Core features implemented, ready for testing and payment flow integration

