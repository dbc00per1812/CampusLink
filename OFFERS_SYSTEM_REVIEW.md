# Unified Offers System - Code Review

**Date**: November 9, 2025  
**Reviewer**: AI Assistant  
**Status**: 🔴 **CRITICAL ISSUES FOUND**

---

## 🔴 CRITICAL ISSUES

### Issue #1: OffersListView Only Works for Seek Mode
**Location**: `CampusLink/Features/Marketplace/Views/OffersListView.swift`

**Problem:**
- Line 6: Parameter is `seekListing: ListingWithUser` - hardcoded name
- Line 35: Only displays if `AppConfig.enableSeekMode == true`
- Line 97: Only loads offers if `AppConfig.enableSeekMode == true`
- Line 184-185: Uses legacy fields `seek_listing_id` and `seeker_id`
- **Result**: When seller clicks "View Offers" on a regular listing, it shows "Coming Soon" or fails

**Impact**: 
- Sellers cannot view offers on their regular listings
- The "View Offers" button is broken for negotiation mode

**Fix Needed:**
- Remove `AppConfig.enableSeekMode` check
- Update `loadOffers()` to use `listing_id` instead of `seek_listing_id`
- Use `offer_to_user_id` to find offers where seller is receiver
- Support both seek and regular listing types

---

### Issue #2: loadOffers() Uses Legacy Fields
**Location**: `OffersListView.swift` lines 166-202

**Problem:**
```swift
.eq("seek_listing_id", value: seekListing.id.uuidString)  // ❌ Legacy field
.eq("seeker_id", value: currentUserId)                     // ❌ Legacy field
```

**Should be:**
```swift
.eq("listing_id", value: listing.id.uuidString)
.eq("offer_to_user_id", value: currentUserId)  // Seller receives offers
```

**Impact**: 
- Query fails for regular listings
- No offers will load

---

### Issue #3: OfferWithDetails Struct Missing New Fields
**Location**: `OffersListView.swift` lines 1049-1081

**Problem:**
- Still uses old field names: `seekListingId`, `seekerId`, `sellerId`
- Missing: `listingId`, `listingType`, `offerFromUserId`, `offerToUserId`, `parentOfferId`
- `toOffer()` function creates Offer with wrong field mapping

**Impact**:
- Cannot properly convert database offers to Offer model
- Counter-offers won't work
- Offer chains broken

---

### Issue #4: UnifiedOfferService Uses Hardcoded Credentials
**Location**: `UnifiedOfferService.swift` lines 24-29

**Problem:**
```swift
private var supabase: SupabaseClient {
    return SupabaseClient(
        supabaseURL: URL(string: "https://gztmsjafkmhtkkdnbwnm.supabase.co")!,
        supabaseKey: "eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9..."
    )
}
```

**Should use**: `SupabaseManager.shared.client` (like other services)

**Impact**:
- Credentials hardcoded (security risk)
- Won't work if credentials change
- Inconsistent with rest of codebase

---

### Issue #5: No Check for Existing Offers
**Location**: `ListingDetailView.swift` line 1040

**Problem:**
- Shows "Make Offer" button even if user already has pending offer
- No check to prevent duplicate offers
- Should show "View My Offer" if pending offer exists

**Impact**:
- Users can spam offers
- No way to see existing offer status

---

### Issue #6: Missing Counter-Offer UI in OffersListView
**Location**: `OffersListView.swift` - `OfferRowView`

**Problem:**
- `OfferRowView` shows Accept/Reject buttons
- But NO Counter button for sellers
- Counter-offer functionality exists in service but not accessible in UI

**Impact**:
- Sellers cannot counter offers
- Only buyers can counter (if they see it in AllMyOffersView)

---

### Issue #7: AllMyOffersView Not Integrated
**Location**: Missing navigation

**Problem:**
- `AllMyOffersView` exists but isn't accessible anywhere
- Users can't see their sent/received offers
- No way to manage offers from one place

**Impact**:
- Feature exists but unusable
- Users can't track their offer activity

---

## ⚠️ MEDIUM PRIORITY ISSUES

### Issue #8: No Validation for Minimum Offer Amount
**Location**: `MakeOfferSheet.swift` line 27

**Problem:**
- Only checks `amount > 0`
- No minimum offer validation (e.g., must be at least $1)
- No maximum validation (e.g., can't offer more than listing price + 50%)

**Impact**:
- Users can offer $0.01
- Users can offer unrealistic amounts

---

### Issue #9: No Offer Status Updates in Real-Time
**Location**: All offer views

**Problem:**
- No Supabase realtime subscriptions
- Offers don't update automatically
- User must refresh manually

**Impact**:
- Poor UX - stale data
- Missed counter-offers

---

### Issue #10: Missing Error Handling for Edge Cases
**Location**: `UnifiedOfferService.swift`

**Problem:**
- No check if listing was deleted while making offer
- No check if user was blocked
- No validation that listing still accepts offers

**Impact**:
- Errors not caught gracefully
- Confusing error messages

---

## 📋 FLOW ANALYSIS

### Current Flow (Regular Listing):

1. ✅ **Create Listing** - Toggle "Accept Offers" → Saved correctly
2. ✅ **View Listing** - Shows "Make Offer" button if `acceptsOffers == true`
3. ✅ **Make Offer** - `MakeOfferSheet` works correctly
4. ✅ **Create Offer** - `UnifiedOfferService.createOffer()` works
5. ❌ **View Offers** - `OffersListView` fails (uses legacy fields, seek-only)
6. ❌ **Accept Offer** - Can't access (no UI in OffersListView)
7. ❌ **Counter Offer** - No button in UI

### Current Flow (Seek Listing):

1. ✅ **Create Seek** - Works (always accepts offers)
2. ✅ **View Seek** - Shows "Offer My Item" button
3. ✅ **Make Offer** - Works (seller offers to buyer)
4. ✅ **View Offers** - Works (but only because of legacy fields)
5. ⚠️ **Accept Offer** - Works but uses old OfferService
6. ❌ **Counter Offer** - Not accessible in UI

---

## 🔧 REQUIRED FIXES

### Priority 1 (Critical - System Broken):

1. **Fix OffersListView for Regular Listings**
   - Remove `AppConfig.enableSeekMode` dependency
   - Update `loadOffers()` to use `listing_id` and `offer_to_user_id`
   - Support both seek and regular listing types
   - Rename parameter from `seekListing` to `listing`

2. **Fix OfferWithDetails Struct**
   - Add all new fields (listingId, listingType, etc.)
   - Update `toOffer()` to map correctly
   - Support both offer types

3. **Add Counter-Offer Button**
   - Add "Counter" button to `OfferRowView`
   - Wire up to `UnifiedOfferService.counterOffer()`
   - Show counter sheet

4. **Fix UnifiedOfferService Supabase Client**
   - Use `SupabaseManager.shared.client`
   - Remove hardcoded credentials

### Priority 2 (Important - UX Issues):

5. **Check for Existing Offers**
   - Before showing "Make Offer", check if pending offer exists
   - Show "View My Offer" if exists
   - Prevent duplicate offers

6. **Integrate AllMyOffersView**
   - Add to Wallet or Profile tab
   - Make accessible from navigation

7. **Add Real-Time Updates**
   - Subscribe to offer changes
   - Auto-refresh when offers update

### Priority 3 (Nice to Have):

8. **Add Offer Validation**
   - Minimum offer amount
   - Maximum offer amount
   - Better error messages

9. **Improve Error Handling**
   - Check listing status
   - Check user blocking
   - Validate listing accepts offers

---

## 🎯 SUMMARY

**Status**: System is **PARTIALLY WORKING**

**What Works:**
- ✅ Creating negotiable listings
- ✅ Making offers (both directions)
- ✅ Offer creation in database
- ✅ Accept offer → create order (service layer)

**What's Broken:**
- ❌ Viewing offers on regular listings
- ❌ Accepting offers from UI (no button)
- ❌ Countering offers (no UI)
- ❌ AllMyOffersView (not accessible)

**Root Cause:**
- `OffersListView` was never updated for regular listings
- Still uses seek-mode-only logic
- Missing UI for counter-offers
- Missing integration points

**Estimated Fix Time**: 1-2 hours

---

## 📝 RECOMMENDED FIX ORDER

1. Fix `OffersListView.loadOffers()` - Use new fields
2. Update `OfferWithDetails` struct - Add new fields
3. Add Counter button to `OfferRowView`
4. Fix Supabase client in `UnifiedOfferService`
5. Add existing offer check in `ListingDetailView`
6. Integrate `AllMyOffersView` into navigation

---

**Next Step**: Should I proceed with fixing these issues?

Darragh

