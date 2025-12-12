# CampusLink Development Log

## December 8, 2025 - Guest Campus Selection Feature

### Overview
Implemented a campus selection flow for guest users to allow them to browse campus-specific listings without creating an account.

### Changes Made

#### 1. Created GuestCampusSelectionView.swift
- New SwiftUI view that presents available campuses to guest users
- Clean, modern UI with campus cards showing display names and abbreviations
- Stores selected campus in AppStorage as "guestSelectedCampus"
- Dismisses welcome sheet and marks it as seen after campus selection
- Location: `ios-swift/CampusLink/Core/Auth/GuestCampusSelectionView.swift`

#### 2. Updated WelcomeView.swift
- Modified "Browse as Guest" button to show campus selection sheet
- Added @State variable for showing campus selection
- Integrated GuestCampusSelectionView as a sheet presentation
- Ensures campus selection is required before browsing as guest

#### 3. Updated HomeTabView.swift
- Modified `loadUserCampus()` to check for guest campus in AppStorage
- When user is not authenticated, uses "guestSelectedCampus" from AppStorage
- Updated all listing load methods (loadAllListings, loadOfferListings, loadSeekListings, loadCategoryListings)
- Guest users now see campus-filtered listings just like authenticated users
- Added debug logging for guest campus detection
- Guest campus persists across app sessions via AppStorage

#### 4. Updated GuestProfileView.swift
- Added campus selection button in settings section
- Shows currently selected campus with abbreviation
- Allows guests to change campus after initial selection
- Integrated campus selection sheet in profile view

### Technical Details

**AppStorage Key**: `guestSelectedCampus` (String)
- Stores the raw value of the selected Campus enum
- Persists across app launches
- Cleared when user signs up or logs in (automatic when session changes)

**Campus Filtering Logic**:
- Authenticated users: Fetch campus from user profile in database
- Guest users: Read from AppStorage "guestSelectedCampus"
- Existing campus filter applies to both authenticated and guest users
- Server-side filtering unchanged (uses campus value for database query optimization)

**User Flow**:
1. User opens app without account
2. Welcome screen appears with "Log In", "Sign Up", "Browse as Guest"
3. User taps "Browse as Guest"
4. Campus selection screen appears with list of all campuses
5. User selects campus (e.g., "Indiana University Bloomington")
6. Welcome sheet dismisses, user sees listings filtered by selected campus
7. User can change campus later from Guest Profile view → Settings → Campus

### Files Modified
- `/ios-swift/CampusLink/Core/Auth/WelcomeView.swift`
- `/ios-swift/CampusLink/Features/Home/HomeTabView.swift`
- `/ios-swift/CampusLink/Core/Auth/GuestProfileView.swift`

### Files Created
- `/ios-swift/CampusLink/Core/Auth/GuestCampusSelectionView.swift`

### Why This Approach
- **Minimal friction**: Guests can start browsing with just one tap (campus selection)
- **Persistent preference**: AppStorage remembers campus choice across sessions
- **Consistent filtering**: Same campus filter logic applies to guests and authenticated users
- **Easy to change**: Guests can change campus from profile without re-authenticating
- **No backend changes**: All guest campus logic handled client-side
- **Privacy-friendly**: No tracking or account creation required
- **Production-ready**: Uses existing Campus enum and filtering infrastructure

### Future Enhancements
- Could add "Nearby Campuses" detection using location services
- Could show campus-specific stats (e.g., "500 active listings at IU")
- Could save recent campus selections for quick switching
- Could add campus logos/images to selection cards

---

## React Native Build - Complete Implementation

### Session: November 30, 2025

---

## Phase 1: Reusable Components ✅

Created 7 reusable components in `mobile/src/components/`:

| Component | File | Purpose |
|-----------|------|---------|
| Button | `Button.tsx` | Primary/secondary/outline buttons with loading states |
| UserAvatar | `UserAvatar.tsx` | Profile pictures with initials fallback and consistent colors |
| ListingCard | `ListingCard.tsx` | Grid card for marketplace listings |
| ImagePickerComponent | `ImagePickerComponent.tsx` | Photo selection with camera/library support |
| LoadingSpinner | `LoadingSpinner.tsx` | Consistent loading indicators |
| EmptyState | `EmptyState.tsx` | Empty list placeholder with action button |
| OrderStatusBadge | `OrderStatusBadge.tsx` | Status badges with colors for orders |

---

## Phase 2: Create/Edit Listing ✅

Built full listing creation and editing functionality:

- **CreateListingScreen** (`mobile/src/screens/post/CreateListingScreen.tsx`)
  - Photo upload (up to 5 images)
  - Category selection (products/services)
  - Price/budget fields
  - Delivery method picker
  - Quantity selector
  - Accept offers toggle
  - Service-specific fields (duration, location, availability)
  - Seek mode support (I'm Looking For)

- **EditListingScreen** (`mobile/src/screens/post/EditListingScreen.tsx`)
  - Pre-populated form from existing listing
  - Delete listing option
  - Same full feature set as create

- **imageUploadService** (`mobile/src/services/imageUploadService.ts`)
  - Upload to Supabase Storage
  - Base64 conversion
  - Multiple image upload support

---

## Phase 3: Messaging with Real-time ✅

Full chat functionality:

- **ConversationsScreen** (`mobile/src/screens/messages/ConversationsScreen.tsx`)
  - Conversation list with last message preview
  - Unread message indicators
  - Listing context display
  - Real-time updates via Supabase subscriptions

- **ChatScreen** (`mobile/src/screens/messages/ChatScreen.tsx`)
  - Real-time message updates
  - Message bubbles (sent/received styling)
  - Keyboard-aware input
  - Listing info bar
  - Mark as read functionality

- **messagingService** (`mobile/src/services/messagingService.ts`)
  - Get conversations, messages
  - Send messages
  - Mark as read
  - Real-time subscriptions

---

## Phase 4: Orders and Transactions ✅

Complete order lifecycle:

- **OrdersScreen** (`mobile/src/screens/orders/OrdersScreen.tsx`)
  - Tabs for Purchases/Sales
  - Order cards with status badges
  - Action required indicators

- **OrderDetailScreen** (`mobile/src/screens/orders/OrderDetailScreen.tsx`)
  - Status banner
  - Order summary
  - Buyer/seller info
  - PIN verification for services
  - Delivery photo display
  - Action buttons (accept, mark delivered, confirm, cancel)

---

## Phase 5: Wallet and Payouts ✅

Balance management:

- **WalletScreen** (`mobile/src/screens/wallet/WalletScreen.tsx`)
  - Balance card (available + escrow)
  - Transaction history
  - Stripe Connect setup prompt
  - Request payout button

- **PayoutRequestScreen** (`mobile/src/screens/wallet/PayoutRequestScreen.tsx`)
  - Amount input with max button
  - Balance validation
  - Processing info

---

## Phase 6: Offers System ✅

Make/accept/counter offers:

- **OffersScreen** (`mobile/src/screens/offers/OffersScreen.tsx`)
  - Tabs for Received/Sent
  - Offer cards with status badges
  - Pending action indicators

- **offerService** (`mobile/src/services/offerService.ts`)
  - Create, accept, decline, counter offers
  - Get offers for listing

---

## Phase 7: Profile and Settings ✅

User management:

- **ProfileScreen** (`mobile/src/screens/profile/ProfileScreen.tsx`)
  - Profile header with avatar and info
  - Trust score badge
  - Listing stats
  - Quick action menu items
  - Sign out button

- **SettingsScreen** (`mobile/src/screens/profile/SettingsScreen.tsx`)
  - Notification toggles
  - Account settings
  - Support links
  - Delete account option

---

## Phase 8: Third-Party Integrations ✅

- **stripeService** (`mobile/src/services/stripeService.ts`)
  - Payment intent creation
  - Connect account management
  - Payout processing

- **notificationService** (`mobile/src/services/notificationService.ts`)
  - OneSignal initialization
  - Permission requests
  - Device registration
  - External user ID linking

---

## Technical Details

### Files Created/Modified:

**Components (7 files):**
- `mobile/src/components/Button.tsx`
- `mobile/src/components/UserAvatar.tsx`
- `mobile/src/components/ListingCard.tsx`
- `mobile/src/components/ImagePickerComponent.tsx`
- `mobile/src/components/LoadingSpinner.tsx`
- `mobile/src/components/EmptyState.tsx`
- `mobile/src/components/OrderStatusBadge.tsx`
- `mobile/src/components/index.ts`

**Screens (14 files):**
- `mobile/src/screens/post/CreateListingScreen.tsx`
- `mobile/src/screens/post/EditListingScreen.tsx`
- `mobile/src/screens/messages/ConversationsScreen.tsx`
- `mobile/src/screens/messages/ChatScreen.tsx`
- `mobile/src/screens/orders/OrdersScreen.tsx`
- `mobile/src/screens/orders/OrderDetailScreen.tsx`
- `mobile/src/screens/wallet/WalletScreen.tsx`
- `mobile/src/screens/wallet/PayoutRequestScreen.tsx`
- `mobile/src/screens/offers/OffersScreen.tsx`
- `mobile/src/screens/profile/ProfileScreen.tsx`
- `mobile/src/screens/profile/SettingsScreen.tsx`

**Services (5 files):**
- `mobile/src/services/imageUploadService.ts`
- `mobile/src/services/messagingService.ts`
- `mobile/src/services/offerService.ts`
- `mobile/src/services/stripeService.ts`
- `mobile/src/services/notificationService.ts`

**Types Updated:**
- `mobile/src/types/product.ts` - Added 'both' to DeliveryMethod, simplified ListingCreate
- `mobile/src/types/order.ts` - Added computed fields and status alias
- `mobile/src/types/messaging.ts` - Added MessageCreate interface

**Services Updated:**
- `mobile/src/services/orderService.ts` - Added getOrder, getMyOrders aliases
- `mobile/src/services/walletService.ts` - Added getWalletBalance, getTransactionHistory aliases

### Dependencies Added:
- `expo-file-system` - For image upload
- `base64-arraybuffer` - For base64 conversion

### TypeScript Status:
✅ All files compile without errors (`npx tsc --noEmit` passes)

---

## Next Steps for Production:

1. **Install Stripe SDK:**
   ```bash
   npx expo install @stripe/stripe-react-native
   ```
   Configure in `app.json` and uncomment SDK calls in stripeService.

2. **Install OneSignal SDK:**
   ```bash
   npx expo install react-native-onesignal
   ```
   Configure in `app.json` and uncomment SDK calls in notificationService.

3. **Test on Devices:**
   - iOS Simulator: `npx expo run:ios`
   - Android Emulator: `npx expo run:android`

4. **Build for Production:**
   - `eas build --platform ios`
   - `eas build --platform android`

---

## Repository Structure:

```
CampusLink/
├── ios-swift/           # Original iOS Swift codebase
├── mobile/              # React Native (Expo) codebase
│   ├── src/
│   │   ├── components/  # Reusable UI components
│   │   ├── config/      # Supabase, secrets, app config
│   │   ├── navigation/  # React Navigation setup
│   │   ├── screens/     # All screen components
│   │   ├── services/    # API and business logic
│   │   ├── types/       # TypeScript interfaces
│   │   └── utils/       # Colors and helpers
│   ├── App.tsx          # Entry point
│   └── package.json
├── docs/                # Documentation
└── log.md               # This file
```

---

## Fee Structure Update - Removed Platform Fee

### Session: December 1, 2025

---

## Change Summary

**Removed platform fee entirely** - CampusLink no longer takes a cut of transactions. Only Stripe's processing fee (2.9% + $0.30) is charged to the buyer.

### Old Pricing Model (Round-up):
- Seller price: $20.00
- Stripe fee: $0.88 (2.9% + $0.30)
- Subtotal: $20.88
- **Buyer paid: $21.00** (rounded up to next dollar)
- **Platform cut: $0.12** (the round-up amount)

### New Pricing Model (No Platform Fee):
- Seller price: $20.00
- Stripe processing fee: $0.88 (2.9% + $0.30)
- **Buyer pays: $20.88** (exact amount, no rounding)
- **Platform cut: $0** (no platform fee)

### Files Modified:

1. **`ios-swift/CampusLink/Core/Services/FeeCalculationService.swift`**
   - `calculateBuyerPrice()`: Returns exact `sellerPrice + stripeFee` instead of rounding up
   - `calculateCampusLinkCut()`: Now always returns 0
   - Updated comments to reflect no platform fee model

2. **`supabase/functions/create_payment_intent/index.ts`**
   - Removed round-up logic: `buyerPriceCents = sellerPriceCents + stripeFeeCents`
   - `campusLinkCutCents = 0` (no platform fee)
   - `applicationFeeCents = stripeFeeCents` (only covers Stripe processing)
   - Updated console logs to reflect new pricing

3. **`supabase_functions/create_payment_intent/index.ts`**
   - Same changes as above for the duplicate function
   - Handles both `listing_id` (new purchase) and `order_id` (accepted offer) cases

4. **`ios-swift/CampusLink/Core/Services/UnifiedOfferService.swift`**
   - Updated comment to reflect new pricing model

### Impact:

- **Buyers**: Pay less (exact seller price + Stripe fee, no rounding)
- **Sellers**: Receive exactly their listing price (no change)
- **Platform**: No revenue from transaction fees

---

## UIUC Campus Launch

### Session: December 1, 2025

---

## Change Summary

**Added University of Illinois Urbana-Champaign (UIUC)** as a new campus option for users during signup.

### Files Modified:

1. **`ios-swift/CampusLink/Core/Models/Campus.swift`**
   - Added new case `uiuc = "UIUC"` to the `Campus` enum
   - Updated `displayName` property to show "University of Illinois Urbana-Champaign" for UIUC
   - Added "UIUC" abbreviation

2. **`mobile/src/types/campus.ts`**
   - Added `'UIUC'` to the `Campus` type union
   - Added UIUC to `CampusList` array
   - Added UIUC to `CampusShortName` record
   - Added new `CampusFullName` record for full university names
   - Added `'illinois.edu': 'UIUC'` to `DomainToCampus` mapping for automatic campus detection

### How It Works:

- **iOS App**: Users see "University of Illinois Urbana-Champaign" in the campus picker during signup. Stored as "UIUC" in the database.
- **React Native App**: Users with `@illinois.edu` emails are automatically detected as UIUC students. The campus is stored as "UIUC".
- **Database**: Campus is stored as the string "UIUC" in the users table.

### Email Domain:
- `illinois.edu` → UIUC

---

## User Interests Backward Compatibility Fix

### Session: December 1, 2025

---

## Problem

Users who signed up before the user_interests feature was added don't have any interests selected, which could cause issues in the app:
- The "For You" feed couldn't personalize recommendations
- No way for existing users to set their interests

## Solution

### 1. Verified Graceful Handling (Already in Place)

The `UserInterestService.prioritizeListings()` already handles empty interests gracefully:
- Returns the original listing order if no interests found
- Wraps database calls in try/catch to prevent crashes
- Logs informative messages for debugging

### 2. Created EditInterestsView for Existing Users

**New File: `ios-swift/CampusLink/Features/Profile/EditInterestsView.swift`**

Allows users to set or update their interests from Settings:
- Loads existing interests from database on appear
- Shows all available interest categories (Products + Services)
- Allows toggling interests on/off
- Saves by deleting existing interests and inserting new selections
- Clears the UserInterestService cache after save so changes take effect immediately

### 3. Added Manage Interests to Settings

**Modified File: `ios-swift/CampusLink/Features/Profile/SettingsView.swift`**

Added new "Preferences" section with:
- "Manage Interests" row with subtitle "Personalize your For You feed"
- Opens EditInterestsView as a sheet
- Uses the app's theme color for the icon

### User Flow

1. User goes to Profile → Settings
2. Scrolls to "Preferences" section
3. Taps "Manage Interests"
4. Selects their preferred categories
5. Taps "Save Interests"
6. Interests are now used to prioritize their "For You" feed

### Impact

- **Existing users**: Can now set interests they never had the chance to select
- **New users**: Can update their interests if their preferences change
- **Feed personalization**: Works for all users who have set interests
- **No breaking changes**: Users without interests continue to see listings in default order

---

## Infinite Scroll Feature

### Session: December 1, 2025

---

## Change Summary

**Implemented infinite scroll** - When users reach the end of the feed, listings now loop back and repeat infinitely so the user always has content to scroll through.

### Implementation:

1. **New State Variables**:
   - `originalListings`: Stores all unique listings loaded from the database
   - `isLooping`: Tracks whether we're in "looping mode" (repeating past content)

2. **Looping Logic** (in `loadMoreListings()`):
   - When `hasMorePages` is false and the user continues scrolling, we append a shuffled version of the original listings
   - A small delay (0.2s) provides smooth UX feedback
   - Listings are shuffled each time they loop for variety

3. **Reset on Refresh/Filter Change**:
   - `originalListings` and `isLooping` reset when:
     - Pull-to-refresh is triggered
     - User switches between filter tabs (For You, All, Selling, Wanted)

### Files Modified:

1. **`ios-swift/CampusLink/Features/Home/HomeTabView.swift`**
   - Added `originalListings` and `isLooping` state variables
   - Updated `loadMoreListings()` with looping logic
   - Updated `loadAllListings()`, `loadOfferListings()`, `loadSeekListings()`, `loadCategoryListings()` to store originals
   - Updated `refreshListings()` and filter change logic to reset looping state
   - Removed "You've reached the end" message (no longer applicable)

### User Experience:

- Users can scroll infinitely through the feed
- When original content is exhausted, it loops with shuffled order for variety
- Pull-to-refresh returns to fresh content from the beginning
- Switching tabs resets the loop cycle

---

## Jobs Section Added to Settings

### Session: December 1, 2025

---

## Change Summary

**Added Jobs section** to the Settings view displaying contact email for job inquiries.

### Implementation:

Added a new "Jobs" section in `SettingsView.swift` with:
- Briefcase icon in theme color
- "Join Our Team" title with email subtitle
- Tapping opens email client to `darragh.b3272@gmail.com`
- Placed after the "About" section in Settings

### Files Modified:

1. **`ios-swift/CampusLink/Features/Profile/SettingsView.swift`**
   - Added "Jobs" section after "About" section
   - Uses Link component to open mail client
   - Displays email address as subtitle

---

## Removed "Become a Verified Student" Section

### Session: December 1, 2025

Removed the entire "Verification" section from the Settings screen in the iOS Swift app.

### Changes Made:

1. **Removed State Variables:**
   - `@State private var showVerification = false`
   - `@State private var verificationStatus: String = "unverified"`

2. **Removed Verification Section UI:**
   - The entire "Verification" VStack that displayed "Become a Verified Student" or verification status

3. **Removed Sheet Presentation:**
   - The `.sheet(isPresented: $showVerification)` that presented `StudentVerificationView`

4. **Removed onAppear Task:**
   - The `loadVerificationStatus()` async call on view appear

5. **Removed Computed Properties & Functions:**
   - `verificationStatusTitle` computed property
   - `verificationStatusSubtitle` computed property
   - `loadVerificationStatus()` async function

### Files Modified:

1. **`ios-swift/CampusLink/Features/Profile/SettingsView.swift`**
   - Cleaned removal of all verification-related code while preserving other settings functionality

---

## Price Display Simplification - Show Seller Price Everywhere

### Session: December 2, 2025

---

## Change Summary

**Simplified pricing display** - All users now see the seller's posted price everywhere in the app. The Stripe processing fee is only shown at checkout, not in listing previews.

### Previous Behavior:
- Buyers saw price with Stripe fee included (e.g., $20.88 for a $20 item)
- Sellers saw their original price ($20)
- This was confusing and created price discrepancy between what buyers/sellers saw

### New Behavior:
- Everyone sees the seller's posted price everywhere ($20)
- Stripe processing fee (2.9% + $0.30) is shown only at checkout in the PaymentMethodSheet
- Cleaner, more transparent pricing model

### Files Modified:

1. **`ios-swift/CampusLink/Features/Home/HomeTabView.swift`** (ListingCard)
   - Removed `feeService` dependency
   - Removed buyer price calculation (`calculateBuyerPrice`)
   - Now shows `listing.price` for everyone
   - Color still distinguishes own listings (blue) from others (green)

2. **`ios-swift/CampusLink/Features/Marketplace/Views/ListingDetailView.swift`**
   - Removed buyer/seller role-based price display
   - Simplified to show `displayedListing.price` for everyone
   - Removed "Your price" / "Total price" labels

3. **`ios-swift/CampusLink/Features/Profile/PublicProfileView.swift`** (ProfileListingCard)
   - Removed `feeService` dependency
   - Removed buyer price calculation
   - Now shows `listing.price` for everyone

4. **`ios-swift/CampusLink/Features/Marketplace/Views/MakeOfferSheet.swift`**
   - Removed `feeService` dependency
   - Removed `buyerPriceCents` computed property
   - Listing preview now shows seller's price (`sellerPrice`) instead of calculated buyer price

### Unchanged (Already Correct):

- **`ios-swift/CampusLink/Features/Payments/Views/PaymentMethodSheet.swift`**
  - Still correctly shows fee breakdown at checkout:
    - Offer Amount (seller price)
    - Stripe Processing Fee
    - Total to Pay (buyer price)

- **`ios-swift/CampusLink/Features/Search/Views/SearchResultsView.swift`**
  - Already showed seller price only

- **`ios-swift/CampusLink/Core/Navigation/TabViews.swift`**
  - Already showed seller price only

### Impact:

- **Clarity**: Same price shown to all users when browsing
- **Transparency**: Fees are clearly itemized at checkout
- **Consistency**: No more confusing price differences between buyer/seller views
- **Simplicity**: Removed unnecessary fee calculations from listing display code

---

## Automatic Push Notification Trigger Fix

### Session: December 2, 2025

---

## Problem

Push notifications were not being delivered automatically. Users had to manually run a curl command to process the notification queue:
```bash
curl -L -X POST 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue' ...
```

**Root Cause**: The `push_notification_queue` table queued notifications, and the `process-push-queue` edge function processed them, but there was **no automatic trigger** connecting them.

## Solution

Created a database trigger using the `pg_net` extension that automatically calls the edge function whenever a notification is inserted into the queue.

### Files Created:

1. **`docs/sql/auto_push_notifications.sql`**
   - Complete SQL to set up automatic notification delivery
   - Option A: Cron job (every minute) - reliable fallback
   - Option B: Instant trigger - recommended for near-instant delivery

### How It Works:

1. Notification is inserted into `push_notification_queue` table
2. Database trigger `on_push_notification_insert` fires
3. Trigger function `trigger_process_push_queue()` uses `pg_net` to call the edge function
4. Edge function processes the queue and sends APNs notifications
5. User receives push notification within seconds

### Setup Steps:

1. Go to Supabase Dashboard > Database > Extensions
2. Enable `pg_net` extension
3. Go to SQL Editor
4. Copy and paste the OPTION B code from `docs/sql/auto_push_notifications.sql`
5. Run it
6. Test by triggering a notification action in the app

---

## Mandatory Photos for Listings

### Session: December 3, 2025

---

## Change Summary

**Made photos mandatory for posting listings** - Users must now add at least one photo before they can post a listing.

### Implementation:

1. **Validation in `isDisabled` computed property**:
   - Added `listingImages.isEmpty` check to disable the Post button when no photos are selected
   - This applies to both "Offer" (selling) and "Seek" (looking for) listings

2. **Visual indicator**:
   - Added "Photos" label with "(Required)" text in red
   - Makes it clear to users that photos are mandatory

### Files Modified:

1. **`ios-swift/CampusLink/Core/Navigation/TabViews.swift`**
   - Added `listingImages.isEmpty` validation check in `isDisabled` computed property
   - Added "Photos (Required)" label to the photo section UI

### User Experience:

- Post button is disabled (grayed out) until at least one photo is added
- Clear visual indicator shows photos are required
- Same requirement for both selling items and posting "looking for" requests

---

## Critical Payment Bug - Orders Created Without Stripe Payment

### Session: December 10, 2025

---

## Problem Discovery

Found an order in Supabase database with:
- `stripe_payment_intent_id: null`
- `payment_status: "succeeded"`
- `order_status: "completed"`
- `stripe_escrow_account_id: "escrow_pending_6FA64C26_222F6121"` (placeholder, not real Stripe account)
- `price_cents: 1900` ($19)

**This means the order was completed without any actual Stripe payment being processed.**

## Root Cause

### Issue #1: OrderService.swift Creates "Succeeded" Orders Without Payment

**File: `ios-swift/CampusLink/Core/Services/OrderService.swift` (lines 68-69)**

```swift
orderStatus: "placed",
paymentStatus: "succeeded",  // ❌ WRONG - no payment has been made!
```

The iOS app creates orders and immediately marks them as "succeeded" without:
1. Creating a Stripe PaymentIntent
2. Processing payment through Stripe
3. Receiving webhook confirmation from Stripe

### Issue #2: Placeholder Escrow Account IDs

**File: `ios-swift/CampusLink/Core/Services/EscrowService.swift` (lines 46-52)**

When a seller hasn't completed Stripe Connect onboarding, the system creates a placeholder:
```swift
escrowAccountId = "escrow_pending_\(sellerId.uuidString.prefix(8))_\(UUID().uuidString.prefix(8))"
```

This is not a real Stripe account ID, it's just a placeholder string.

### Issue #3: Mobile App Also Creates "Succeeded" Orders

**File: `mobile/src/services/orderService.ts` (line 56)**

```typescript
payment_status: 'succeeded',  // ❌ Same issue as iOS
```

## How This Should Work

### Correct Flow (UnifiedOfferService has it right):

1. **Create order with `payment_status: "pending"`**
   ```swift
   paymentStatus: "pending",  // ✅ Correct - buyer hasn't paid yet
   stripePaymentIntentId: nil  // ✅ Correct - no payment yet
   ```

2. **Buyer initiates payment:**
   - App calls `create_payment_intent` edge function
   - Edge function creates Stripe PaymentIntent
   - Returns `client_secret` to app

3. **Buyer completes payment in Stripe SDK:**
   - Payment processed through Stripe
   - Stripe sends webhook event `payment_intent.succeeded`

4. **Webhook handler updates order:**
   - Finds order by `listing_id` and `buyer_id`
   - Updates with `stripe_payment_intent_id`
   - Updates `payment_status: "succeeded"`

### What's Actually Happening (OrderService):

1. **Order created with `payment_status: "succeeded"`** ❌
2. No Stripe payment ever created ❌
3. Order can be completed without any money changing hands ❌

## Impact

**High Severity** - This is a critical payment bypass bug:

1. **Revenue Loss**: Orders completed without payment processing
2. **Fraud Risk**: Users can get items/services without paying
3. **Accounting Issues**: Database shows "succeeded" payments that don't exist in Stripe
4. **Data Integrity**: Impossible to reconcile Supabase orders with Stripe transactions

## Solution Required

### Fix OrderService.swift

Change line 69 from:
```swift
paymentStatus: "succeeded",
```

To:
```swift
paymentStatus: "pending",
```

And ensure the payment flow:
1. Create order as "pending"
2. Show payment UI to buyer
3. Process payment through Stripe
4. Wait for webhook to update order to "succeeded"

### Fix mobile/src/services/orderService.ts

Same change - line 56 should be:
```typescript
payment_status: 'pending',
```

### Database Cleanup

Run query to find all affected orders:
```sql
SELECT 
  id, 
  stripe_payment_intent_id, 
  stripe_escrow_account_id, 
  payment_status, 
  order_status, 
  price_cents, 
  created_at,
  buyer_id,
  seller_id
FROM orders 
WHERE stripe_payment_intent_id IS NULL 
  AND payment_status = 'succeeded'
ORDER BY created_at DESC;
```

These orders need manual review to determine:
- Were they test orders?
- Were they actually paid through some other means?
- Should they be refunded/cancelled?

## The Complete Money-Printing Bug Chain

### What Actually Happened:

**Step 1: Order Created Without Payment**
- `OrderService.swift` line 69 sets `payment_status: "succeeded"` immediately
- No Stripe PaymentIntent created
- No actual payment processed
- Buyer never charged

**Step 2: Order Lifecycle Continues Normally**
- Seller marks as delivered
- Buyer confirms delivery
- Order status → "completed"

**Step 3: Phantom Money Created**
- `confirmDelivery()` calls `releaseEscrowFunds()`
- Line 563: `available_cents: sellerWallet.availableCents + netAmountCents`
- **NO CHECK** that `stripe_payment_intent_id` exists
- **NO VERIFICATION** that real payment succeeded
- Seller's wallet credited with $19 that was never paid

### Can Seller Withdraw Phantom Money?

**NO** - The payout will fail:
1. Seller requests payout from their wallet
2. System calls `process-payout` edge function
3. Edge function tries to create Stripe payout from seller's Connect account
4. **Stripe rejects** - Connect account has $0 (no real payment went through)
5. Payout fails, money refunded to seller's wallet

**BUT** - Seller's app shows fake balance they think they can cash out.

### Impact Assessment

**CRITICAL SEVERITY:**

1. **Revenue Loss Potential**: Orders completed without payment processing
2. **Accounting Corruption**: Database shows "succeeded" payments that don't exist in Stripe
3. **User Trust**: Sellers see balances they can't withdraw
4. **Data Integrity**: Impossible to reconcile Supabase vs Stripe transactions
5. **Fraud Vector**: Users can get items/services without paying

### How Many Orders Are Affected?

Need to run this query:
```sql
SELECT 
  COUNT(*) as total_phantom_orders,
  SUM(price_cents) as total_phantom_money,
  order_status,
  payment_status
FROM orders 
WHERE stripe_payment_intent_id IS NULL 
  AND payment_status = 'succeeded'
GROUP BY order_status, payment_status;
```

## December 10 Update: Buyer Stripe Account Restricted

### New Discovery

The buyer's Stripe Connect account shows:
- Status: "Restricted"  
- "Payouts paused" and "Payments paused"
- 6 actions required (past due)
- Total balance: $0.00

### Key Questions

1. **Is this person BOTH a buyer and seller?**
   - If yes, their restricted Connect account might be blocking ALL Stripe activity
   - Stripe may reject payments from restricted account holders

2. **Direct purchase vs Offer acceptance?**
   - Order created Dec 3, completed Dec 10 (7 day gap)
   - Suggests this might be from offer acceptance, not direct "Buy Now"

3. **Why did payment fail silently?**
   - Stripe might return `.canceled` for restricted accounts
   - App treats `.canceled` as user cancellation, doesn't show error
   - But order still got created somehow

### Theory

When a user's Stripe Connect account is restricted with "Payments paused":
- Stripe blocks ALL payment activity for that identity
- Including purchases as a buyer (not just receiving payouts as seller)
- Payment fails with `.canceled` instead of `.failed`
- App doesn't properly handle this edge case

## Emergency Fixes Required

### Fix #1: Stop Creating Phantom Orders (IMMEDIATE)

**File: `ios-swift/CampusLink/Core/Services/OrderService.swift`**
- Line 69: Change `paymentStatus: "succeeded"` → `paymentStatus: "pending"`
- Require actual Stripe payment before marking succeeded

**File: `mobile/src/services/orderService.ts`**
- Line 56: Change `payment_status: 'succeeded'` → `payment_status: 'pending'`

### Fix #2: Add Payment Validation to Escrow Release

**File: `ios-swift/CampusLink/Core/Services/OrderService.swift`**

Add this check BEFORE line 376:
```swift
// CRITICAL: Only release escrow if actual payment was received
guard order.stripePaymentIntentId != nil else {
    print("❌ Cannot release escrow - no Stripe payment processed")
    throw OrderServiceError.noPaymentIntent
}

// Verify payment status in Stripe before releasing funds
if order.paymentMethod == .card {
    // TODO: Call Stripe API to verify payment_intent status is "succeeded"
    // Don't trust database value alone
}
```

### Fix #3: Database Constraints (PREVENT FUTURE BUGS)

```sql
-- Prevent orders from being marked "succeeded" without payment intent
ALTER TABLE orders 
ADD CONSTRAINT payment_succeeded_requires_intent 
CHECK (
  payment_status != 'succeeded' OR 
  stripe_payment_intent_id IS NOT NULL OR 
  payment_method = 'wallet'
);

-- Prevent phantom escrow account IDs
ALTER TABLE orders 
ADD CONSTRAINT escrow_account_valid 
CHECK (
  stripe_escrow_account_id IS NULL OR 
  stripe_escrow_account_id !~ '^escrow_pending_'
);
```

### Fix #4: Data Cleanup

For existing phantom orders, need to:
1. Identify all affected orders
2. Reverse phantom wallet credits
3. Cancel or properly process orders
4. Notify affected users

## Prevention Going Forward

1. **Never set `payment_status: "succeeded"` without `stripe_payment_intent_id`**
2. **Always verify payment in Stripe before releasing funds**
3. **Add database constraints** to prevent invalid states
4. **Code review** all payment-related code for security
5. **Add integration tests** that verify actual Stripe payment occurs
6. **Monitor for discrepancies** between Supabase orders and Stripe payments

---

## Critical Fix: Payment Intent ID Not Saved to Orders

### Session: December 10, 2025

---

## Root Cause Discovery

Payments were being authorized in Stripe (via `capture_method: "manual"`) but never captured because the `stripe_payment_intent_id` was never saved to the order.

### The Problem Chain:

1. **`create_payment_intent` edge function** creates PaymentIntent and returns `payment_intent_id`
2. **`PaymentService.swift`** decodes the response BUT the struct was **missing `payment_intent_id` field**
3. Order is created without the payment intent ID
4. When `confirmDelivery()` runs, it checks `if let paymentIntentId = order.stripePaymentIntentId`
5. Since it's `nil`, the capture is skipped
6. Payment authorization expires after 7 days without capture
7. Seller gets credited in wallet but money was never actually captured from buyer

### Where Money Goes When Captured:

- **With `canUseDestinationCharges = true`** (seller has active Stripe Connect with transfers):
  → Money goes **directly to seller's Connect account** minus application fee

- **With `canUseDestinationCharges = false`** (seller not fully onboarded):
  → Money stays in **platform's Stripe account** until manually transferred

## Fixes Applied

### 1. PaymentService.swift - Added `payment_intent_id` to response decoding

**Added property to store payment intent:**
```swift
var currentPaymentIntentId: String?
```

**Updated `ResponseBodyWithPricing` struct to include `payment_intent_id`:**
```swift
struct ResponseBodyWithPricing: Decodable {
    let client_secret: String
    let seller_price_cents: Int
    let buyer_price_cents: Int
    let stripe_fee_cents: Int
    let campuslink_cut_cents: Int?
    let payment_intent_id: String  // CRITICAL: Needed for payment capture
}
```

**Now stores payment intent ID after decoding:**
```swift
self.currentPaymentIntentId = decoded.payment_intent_id
```

### 2. ListingDetailView.swift - Save payment intent ID to order after creation

After order is created in `handleCardPayment`, now updates order with payment intent ID:
```swift
if let paymentIntentId = paymentService.currentPaymentIntentId {
    _ = try await orderService.updateOrderWithPaymentIntent(order.id, paymentIntentId: paymentIntentId)
    paymentService.currentPaymentIntentId = nil  // Clear after use
}
```

### 3. OffersListView.swift - Same fix for offer payment flow

- Added `@State private var currentPaymentIntentId: String?`
- Updated `createOfferPaymentIntent` to return and store `payment_intent_id`
- Updated `handleStripePaymentResult` to save payment intent ID to order

### 4. create_payment_intent/index.ts - Updated deployed function to support order_id

The deployed edge function now matches the `supabase_functions` version:
- Supports both `listing_id` (new purchase) and `order_id` (accepted offer)
- Always returns `payment_intent_id` in response

## Flow After Fix

### Direct Purchase Flow:
1. Buyer taps "Buy Now" 
2. `configurePaymentSheet()` calls edge function, saves `currentPaymentIntentId`
3. Stripe PaymentSheet presented
4. Payment authorized (not captured yet)
5. Order created with `payment_status: "succeeded"`
6. **NEW:** Order updated with `stripe_payment_intent_id`
7. Seller confirms delivery → buyer confirms receipt
8. `confirmDelivery()` calls `capturePayment(paymentIntentId)` ✅
9. Money captured from buyer, transferred to seller

### Offer Payment Flow:
1. Seller accepts offer → order created with `payment_status: "pending"`
2. Buyer sees "Pay Now" button
3. `createOfferPaymentIntent()` returns `payment_intent_id`, stored locally
4. Stripe PaymentSheet presented
5. Payment authorized
6. Order created/updated with `stripe_payment_intent_id`
7. Same capture flow as above

## Files Modified

1. `ios-swift/CampusLink/Features/Payments/Managers/PaymentService.swift`
   - Added `currentPaymentIntentId` property
   - Updated two `ResponseBodyWithPricing` structs to include `payment_intent_id`
   - Now stores payment intent ID when decoding responses

2. `ios-swift/CampusLink/Features/Marketplace/Views/ListingDetailView.swift`
   - After order creation, now saves payment intent ID to order

3. `ios-swift/CampusLink/Features/Marketplace/Views/OffersListView.swift`
   - Added `currentPaymentIntentId` state
   - Updated `createOfferPaymentIntent` to return payment intent ID
   - Updated `handleStripePaymentResult` to save payment intent ID

4. `supabase/functions/create_payment_intent/index.ts`
   - Now supports both `listing_id` and `order_id` parameters
   - Always returns `payment_intent_id` in response

## Deployment Required

Need to redeploy the `create_payment_intent` edge function:
```bash
supabase functions deploy create_payment_intent
```

---

## Legal Documents Website Deployment

### Session: December 12, 2025

---

## Problem

Legal documents (privacy.html, terms.html, community-guidelines.html) were showing 404 errors on https://campusconnect.services/ because the `web/` directory was never added to git or deployed.

### Root Cause

- The `web/` directory exists locally with all HTML files properly formatted
- However, the directory was untracked in git (never committed or pushed)
- Therefore, the files were never deployed to the web server at campusconnect.services
- Users visiting the legal document URLs received 404 errors

### Files Affected

The `web/` directory contains:
- `privacy.html` - CampusLink Privacy Policy (effective Jan 29, 2025, updated Oct 28, 2025)
- `terms.html` - Terms of Service (effective Sep 22, 2025, updated Nov 12, 2025)
- `community-guidelines.html` - Community Guidelines (effective Sep 22, 2025, updated Nov 12, 2025)
- `index.html` - Homepage
- `stripe-refresh.html` - Stripe Connect refresh handler
- `stripe-return.html` - Stripe Connect return handler

### Solution Applied

1. **Added web directory to git tracking**
   - All 6 HTML files in the `web/` directory
   - These files are production-ready with proper styling and content

2. **Committed to repository**
   - Prepared for deployment to web server
   - Ready to be pushed to origin

### Next Steps Required

After pushing to git:
- Verify files are accessible at:
  - https://campusconnect.services/privacy.html
  - https://campusconnect.services/terms.html
  - https://campusconnect.services/community-guidelines.html
- Ensure web hosting (Netlify/Vercel/similar) is configured to serve from `web/` directory
- Test all links in the mobile app and website

### Why This Happened

The web files were created at some point but never committed to version control, possibly because:
- They were created locally for testing
- Developer forgot to `git add web/`
- Files were overlooked in previous commits

### Prevention

- Always verify new directories are tracked: `git status`
- Check deployment before announcing URLs to users
- Add web deployment to CI/CD pipeline if available

---

*Log maintained by AI Assistant*
