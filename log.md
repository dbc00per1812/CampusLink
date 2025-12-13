# CampusLink Development Log

## December 12, 2025 - Fixed Multiple Navigation Errors in ProfileScreen ✅

### Problem
Multiple navigation errors when clicking buttons in the Profile screen:
1. "Orders" navigation error - trying to navigate to non-existent screen
2. "NotificationSettings" navigation error - screen doesn't exist
3. "EditProfile" navigation error - screen doesn't exist

### Root Cause
ProfileScreen was trying to navigate to screens that either:
- Don't exist in the React Native app
- Are registered under different names in different navigator stacks
- Were defined in types but never implemented

### Solution
1. **Orders Navigation** - Fixed by using nested navigation:
   - Changed from `navigation.navigate('Orders')` 
   - To `navigation.navigate('Wallet', { screen: 'OrdersList' })`
   - The OrdersScreen exists but is registered as "OrdersList" in the WalletStack

2. **NotificationSettings & EditProfile** - Replaced with "Coming Soon" alerts:
   - Changed navigation calls to show Alert dialogs
   - Prevents crashes while features are under development
   - Better UX than hidden errors

### Files Modified
1. **`mobile/src/screens/profile/ProfileScreen.tsx`**:
   - Fixed "My Orders" button navigation to use nested navigation to WalletStack
   - Changed "Edit Profile" button to show "Coming Soon" alert
   - Changed "Notifications" button to show "Coming Soon" alert

**Status**: ✅ COMPLETE - All navigation errors in ProfileScreen resolved

---

## December 12, 2025 - Fixed "MyListings" Navigation Error ✅

### Problem
When clicking "My Listings" button in the Profile screen, the app showed a navigation error:
```
The action 'NAVIGATE' with payload {"name":"MyListings"} was not handled by any navigator.
```

### Root Cause
The `MyListings` screen was defined in the navigation types (`ProfileStackParamList`) and referenced in `ProfileScreen.tsx` (line 159), but:
1. No `MyListingsScreen` component existed
2. The screen was not registered in the `ProfileStack` navigator in `TabNavigator.tsx`

### Solution
1. **Created `MyListingsScreen.tsx`**:
   - Full-featured screen for viewing and managing user's listings
   - Filter tabs: All / Active / Sold with counts
   - Action buttons on each listing: Mark Sold/Available, Archive
   - Pull-to-refresh support
   - Empty state with "Create Listing" button
   - Uses existing `getMyListings`, `updateListing`, and `archiveListing` services
   - Navigation to listing detail when tapping a listing card

2. **Registered screen in navigation**:
   - Added import for `MyListingsScreen` in `TabNavigator.tsx`
   - Added `ProfileStack.Screen` for "MyListings" route with title "My Listings"

### Files Modified
1. **Created: `mobile/src/screens/profile/MyListingsScreen.tsx`**
   - New dedicated screen for viewing user's listings
   - Features: filtering, refresh, mark sold/available, archive
   - Clean UI with action buttons and empty states

2. **Modified: `mobile/src/navigation/TabNavigator.tsx`**
   - Added `MyListingsScreen` import
   - Registered `MyListings` screen in `ProfileStack.Navigator`

**Status**: ✅ COMPLETE - Navigation error fixed, screen created and registered

---

## December 12, 2025 - Added Edit and Delete Buttons to React Native Listing Detail Screen ✅

### Changes Made
Added Edit and Delete functionality to the listing detail screen in the React Native app. When viewing your own post, Edit and Delete buttons now appear instead of the Message and Buy Now buttons.

**Status**: ✅ COMPLETE - Tested and working

**Update**: Added color-coded pricing
- **Your own posts**: Blue price
- **Other people's posts**: Green price (#34C759)

**Files Modified**:
1. **`mobile/src/screens/home/HomeScreen.tsx`**:
   - Imported `getCurrentUserId` from authService
   - Added `currentUserId` state to track logged-in user
   - Modified `useEffect` to load current user ID on mount
   - Updated `renderListingCard` to check ownership: `item.user_id === currentUserId`
   - Applied conditional price styling:
     - `priceOwn`: Blue (Colors.primary) for your own listings
     - `priceOther`: Green (#34C759) for other people's listings
   - Price color changes visible on home feed grid cards

2. **`mobile/src/screens/home/ListingDetailScreen.tsx`**:
   - Imported `getCurrentUserId` from authService and `deleteListing` from listingService
   - Added `Alert` import for confirmation dialogs
   - Added `currentUserId` state to track the logged-in user
   - Modified useEffect to load both listing and current user ID in parallel
   - Added `isOwnListing` check: `currentUserId && listing.user_id === currentUserId`
   
   - Added `handleEdit()` function:
     - Navigates to EditListing screen with listingId parameter
   
   - Added `handleDelete()` function:
     - Shows confirmation alert before deletion
     - Calls `deleteListing(listing.id)` from service
     - Shows success message and navigates back
     - Shows error alert if deletion fails
   
   - Updated bottom bar UI:
     - Shows Edit (blue) and Delete (red) buttons when `isOwnListing` is true
     - Shows Message and Buy Now buttons when viewing other users' posts
     - Both buttons have icon + text layout
   
   - Added new styles:
     - `editButton`: Blue background with white text and edit icon
     - `deleteButton`: Red background (#FF3B30) with white text and trash icon
     - Both buttons are equal width (flex: 1) and have rounded corners

**User Flow**:
1. User taps on their own post from home feed
2. Detail screen loads and detects ownership
3. Bottom bar shows **Edit** and **Delete** buttons instead of Message/Buy Now
4. **Edit**: Opens EditListing screen to modify the post
5. **Delete**: Shows confirmation → deletes post → navigates back to home

**Technical Details**:
- Ownership check uses exact string match: `listing.user_id === currentUserId`
- Delete requires confirmation to prevent accidental deletion
- Edit navigates to existing EditListingScreen
- Parallel loading of listing data and user ID for better performance

---

## December 12, 2025 - Added Edit and Delete Buttons to Profile Listings (iOS Swift - NOT USED)

### Changes Made
Added Edit and Delete functionality to listings displayed in the ProfileTabView. Previously, the listing items in the profile tab showed placeholder "Mark Delivered" and "Report Problem" buttons, but no edit or delete functionality for the user's own posts.

**Files Modified**:
1. **`ios-swift/CampusLink/Features/Profile/ProfileTabView.swift`**:
   - Added state variables for edit/delete operations:
     - `listingToEdit: ListingWithUser?` - tracks which listing is being edited
     - `listingToDelete: String?` - stores the ID of the listing to delete
     - `showDeleteAlert: Bool` - controls delete confirmation alert
     - `isDeleting: Bool` - tracks deletion in progress
   
   - Added `.sheet(item: $listingToEdit)` to show EditListingView when editing
   - Added `.alert("Delete Listing")` with confirmation dialog before deletion
   
   - Updated `listingRowItem()` function:
     - Replaced placeholder "Mark Delivered" and "Report Problem" buttons
     - Added **Edit** button that opens EditListingView for the listing
     - Added **Delete** button that shows confirmation alert
     - Both buttons use `.buttonStyle(PlainButtonStyle())` to prevent navigation conflicts
   
   - Added `deleteListing(_ listingId: String)` function:
     - First attempts hard-delete via `delete_listing_cascade` RPC (cascades related rows)
     - Falls back to soft-delete (sets status to "archived") if RPC unavailable
     - Refreshes the listings list after successful deletion
     - Proper error handling and loading states

**User Flow**:
1. User views their profile → sees their listings with Edit/Delete buttons
2. **Edit**: Tap Edit → EditListingView sheet appears → make changes → save → list refreshes
3. **Delete**: Tap Delete → confirmation alert appears → confirm → listing deleted → list refreshes

**Technical Details**:
- Edit button styled with ThemeColor background
- Delete button styled with facebookBlue background
- Deletion uses same RPC function as ListingDetailView for consistency
- Proper state management ensures UI updates after operations complete

---

## December 12, 2025 - Updated React Native Wallet Screen Layout to Match iOS

### Update: Added Missing Payout Screens to Navigator
Fixed navigation issue where Quick Action buttons weren't working.

**Files Created**:
1. **`mobile/src/screens/wallet/PayoutHistoryScreen.tsx`** (NEW):
   - Complete payout history screen with list of past payouts
   - Shows payout status (pending, processing, completed, failed)
   - Color-coded status badges and icons
   - Pull-to-refresh functionality
   - Empty state when no payouts exist
   - Displays requested and completed dates
   
   **Bug Fix**: Fixed "Cannot read property 'toFixed' of undefined" error:
   - Added optional chaining to `formatCurrency` function (handles undefined/null amounts)
   - Updated Payout interface to allow `amount` and `amount_cents` to be optional
   - Added data mapping in `loadPayouts` to convert `amount_cents` to dollars
   - Added fallback to empty array if data is null/undefined
   - Proper error handling with empty state

**Files Modified**:
2. **`mobile/src/navigation/TabNavigator.tsx`**:
   - Imported PayoutRequestScreen and PayoutHistoryScreen
   - Added PayoutRequest and PayoutHistory to WalletNavigator stack
   - Set WalletMain header to hidden (headerShown: false)
   - Screens now properly registered for navigation

**Navigation Flow**:
- Wallet tab → WalletMain (no header)
- "Request Payout" button → PayoutRequest screen
- "History" button → PayoutHistory screen
- "See All" → OrdersList screen
- Order item → OrderDetail screen

---

### Changes Made
Redesigned the Wallet screen in the React Native app to match the iOS version's layout and visual hierarchy.

**New Layout Order** (matches iOS):
1. Balance Card (with Total Balance footer)
2. Quick Action Buttons (Request Payout / History or Setup button)
3. Compact Stripe Setup Banner (if needed)
4. Recent Transactions

**Previously**:
1. Balance Card
2. Large Stripe Setup Card
3. Transaction History
4. Quick Actions (at bottom)

**Files Modified**:

1. **`mobile/src/screens/wallet/WalletScreen.tsx`**:

   **Balance Card Updates**:
   - Removed "Pending" balance row (simplified to only show Escrow)
   - Added Total Balance footer section with gray background (matches iOS)
   - Changed Escrow text color to warning/orange (matches iOS escrow styling)
   - Footer displays: `Available + Escrow = Total Balance`

   **Quick Actions Moved Up**:
   - Created `actionButtonsRow` with horizontal button layout
   - Primary button: "Request Payout" (blue) or "Complete Payout Setup" (if no Stripe)
   - Secondary button: "History" (gray background, only shows when Stripe is connected)
   - Buttons now appear immediately below balance card (matches iOS)
   - Use TouchableOpacity for better control over styling

   **Stripe Setup Compact**:
   - Replaced large setup card with compact banner design
   - Banner shows only icon + short message
   - Left border accent color (blue for setup, yellow for pending)
   - Much smaller footprint (from ~150px to ~45px height)
   - Still shows when Stripe not connected or pending verification

   **Transaction History**:
   - Renamed "Transaction History" to "Recent Transactions" (matches iOS)
   - Limited display to 5 transactions (previously 10)
   - "See All" button navigates to OrdersList (renamed from TransactionHistory)
   - Removed old Quick Actions section at bottom

   **Styling Updates**:
   - Added `totalBalanceFooter` with gray background matching iOS
   - Added `actionButton`, `actionButtonPrimary`, `actionButtonSecondary` styles
   - Added `setupBanner` for compact Stripe prompts
   - Removed old `setupCard`, `actionsGrid`, `actionCard` styles
   - Updated spacing to match iOS visual hierarchy

**Rationale**:
- **Better UX**: Action buttons immediately accessible after viewing balance
- **Cleaner Design**: Compact Stripe banner doesn't dominate screen
- **iOS Parity**: Identical layout and flow across both platforms
- **Reduced Clutter**: Eliminated redundant Quick Actions section
- **Visual Hierarchy**: Balance → Actions → History matches user mental model

---

## December 12, 2025 - Updated React Native Tab Bar Order to Match iOS

### Changes Made
Reorganized the bottom navigation bar in the React Native app to match the iOS version's layout.

**Tab Order (New)**:
1. Home
2. Messages
3. Post (Sell)
4. Wallet
5. Profile

**Previously**:
1. Home
2. Post (Sell)
3. Messages
4. Orders
5. Profile

**Files Modified**:

1. **`mobile/src/navigation/types.ts`**:
   - Replaced `OrdersStackParamList` with `WalletStackParamList` as a top-level tab
   - Moved Orders screens into WalletStackParamList (OrdersList, OrderDetail, PurchaseConfirmation)
   - Added WalletMain screen to WalletStackParamList
   - Removed Wallet screens from ProfileStackParamList (now top-level)
   - Updated MainTabParamList to replace Orders with Wallet
   - Reordered MainTabParamList to match iOS: Home, Messages, Post, Wallet, Profile
   - Renamed `OrdersScreenProps` to `WalletScreenProps`

2. **`mobile/src/navigation/TabNavigator.tsx`**:
   - Replaced OrdersNavigator with WalletNavigator
   - WalletNavigator includes: WalletMain, OrdersList, OrderDetail screens
   - Removed Wallet screen from ProfileNavigator
   - Updated tab icon mappings (replaced 'receipt' icons with 'wallet' icons)
   - Reordered Tab.Screen components: Home → Messages → Post → Wallet → Profile
   - All screens properly configured with headers and navigation

**Rationale**:
- Provides consistent user experience across iOS and React Native platforms
- Wallet is a primary feature that deserves top-level navigation access
- Orders are accessible through Wallet tab (similar to iOS architecture)
- Post button remains central for quick access to selling functionality

---

## December 12, 2025 - Fixed Ticket Auto-Archiving for iOS & Mobile Apps

### Issue Found
Tickets were NOT auto-archiving after events passed on BOTH platforms:

**iOS App Issues (Fixed)**:
- ❌ Timer not properly retained in async context
- ❌ Timer not added to common run loop mode (would pause during scrolling)
- ❌ Query didn't explicitly filter NULL values
- ❌ Insufficient logging to debug issues
- ❌ Used `await` on non-async function

**Mobile App Issues (Fixed)**:
- ❌ No event date picker in CreateListingScreen.tsx
- ❌ No event date field in EditListingScreen.tsx
- ❌ Never set `expires_at` for tickets

### Implementation

**Files Modified**:

**iOS Swift:**
1. `ios-swift/CampusLink/Core/Services/ExpiredListingArchiver.swift` - Fixed timer retention and query
2. `ios-swift/CampusLink/Core/Navigation/MainTabView.swift` - Fixed async call

**React Native:**
3. `mobile/src/screens/post/CreateListingScreen.tsx` - Added event date picker and logic
4. `mobile/src/screens/post/EditListingScreen.tsx` - Added event date picker and logic
5. `mobile/src/types/product.ts` - Added `expires_at` field to ListingCreate type
6. `mobile/package.json` - Added DateTimePicker dependency

**Changes Made**:

#### iOS: ExpiredListingArchiver.swift
- **Fixed Timer Creation**: Wrapped timer creation in `DispatchQueue.main.async` to ensure it runs on main thread
- **Added to Common Run Loop**: Timer now added to `.common` mode so it fires even during UI scrolling
- **Enhanced Query**: Added explicit `.not("expires_at", operator: .is, value: "null")` filter
- **Better Logging**: Added detailed logging including current time, listing details, and error messages
- **Fixed ISO Date Formatting**: Reuse single formatter instance for consistency

#### iOS: MainTabView.swift
- **Removed await**: Changed `await expiredListingArchiver.startAutoArchiving()` to just `expiredListingArchiver.startAutoArchiving()` since it's not async

#### Mobile: CreateListingScreen.tsx
- Added `eventDate` state (default: 24 hours from now)
- Added `expiresDate` state for seek posts (default: 7 days from now)
- Added DateTimePicker component for event date when category is "Tickets"
- Added logic to set `expires_at` in listing data:
  - For seek posts: use `expiresDate`
  - For ticket listings: use `eventDate`
  - For other listings: null (no expiration)
- UI displays event date picker only when "Tickets" category is selected
- Required field indicator (red asterisk) on event date

#### EditListingScreen.tsx  
- Added `eventDate` state
- Added `expiresDate` state
- Load existing `expires_at` value when editing
- Added DateTimePicker for tickets
- Update `expires_at` when saving changes

#### product.ts
- Added `expires_at?: string | null` to `ListingCreate` interface

### How It Works Now

**Creating Tickets:**
1. User selects "Tickets" category → Event date picker appears (both iOS & mobile)
2. User picks event date/time (required field)
3. When posting, `expires_at` is set to the event date
4. Listing is saved to database with expiration date

**Auto-Archiving Process:**
1. `ExpiredListingArchiver` starts when app launches
2. Runs immediate check on startup
3. Sets up timer to check every 30 minutes
4. Timer fires on common run loop (won't pause during scrolling)
5. Query finds listings where `expires_at IS NOT NULL AND expires_at < NOW()`
6. Updates matching tickets: sets `archived = true`
7. Detailed logs print to console for debugging

### Console Logs to Look For

**On App Launch:**
```
📦 ExpiredListingArchiver: Started auto-archiving (checks every 30 minutes)
```

**Every 30 Minutes (or on manual trigger):**
```
📦 ExpiredListingArchiver: Checking for expired listings (current time: 2025-12-12T10:30:00Z)
📦 ExpiredListingArchiver: Found 2 expired listing(s)
📦 Archiving: 'Basketball Game Tickets' (Category: Tickets, Expires: 2025-12-12T09:00:00Z)
✅ Archived expired listing: Basketball Game Tickets (ID: abc-123)
✅ ExpiredListingArchiver: Archived 2 expired listing(s)
```

**If No Expired Listings:**
```
📦 ExpiredListingArchiver: No expired listings found
```

### Testing Recommendations

**Quick Test (iOS):**
1. Open Xcode console to see logs
2. Create ticket with event date 2 minutes in future
3. Look for: `📦 ExpiredListingArchiver: Started auto-archiving`
4. Wait 2 minutes for event to pass
5. Wait up to 30 minutes OR restart app to trigger immediate check
6. Look for archiving logs
7. Verify ticket is archived in database

**Database Verification:**
```sql
-- Check if tickets have expires_at set
SELECT id, title, category, expires_at, archived, created_at 
FROM listings 
WHERE category = 'Tickets' 
ORDER BY created_at DESC 
LIMIT 10;

-- Find expired tickets that should be archived
SELECT id, title, expires_at, archived
FROM listings 
WHERE category = 'Tickets' 
  AND expires_at < NOW() 
  AND archived = false;
```

**Manual Trigger for Testing:**
You can call `ExpiredListingArchiver.shared.manualArchive()` from anywhere in the code to trigger an immediate check without waiting 30 minutes.

---

## December 12, 2025 - Added Required Field Indicators (Red Asterisks)

### Overview
Added red asterisks (*) next to the Category and Photos fields in both Create and Edit Listing screens to clearly indicate that these fields are required for creating/editing a listing.

### Implementation Details

**Files Modified**:
1. `mobile/src/screens/post/CreateListingScreen.tsx` (React Native)
2. `mobile/src/screens/post/EditListingScreen.tsx` (React Native)
3. `ios-swift/CampusLink/Core/Navigation/TabViews.swift` (iOS Swift - Create Listing)
4. `ios-swift/CampusLink/Features/Marketplace/Views/EditListingView.swift` (iOS Swift - Edit Listing)

### Changes Made

#### React Native (TypeScript)
- **Photos Label**: Added inline red asterisk using `<Text style={{color: '#FF0000'}}>*</Text>` within the label Text component
- **Category Label**: Same approach - inline red asterisk for visual indication of required field
- Applied to both CreateListingScreen and EditListingScreen for consistency

#### iOS Swift (SwiftUI)
- **Photos Label**: Used SwiftUI's Text concatenation operator (`+`) to combine "Photos" text with red asterisk
  - Main text: `.foregroundColor(.secondary)`
  - Asterisk: `.foregroundColor(.red)`
- **Category Label**: Same concatenation approach
  - Applied in TabViews.swift (create listing) - both offer and seek modes
  - Applied in EditListingView.swift (edit listing) - replaced LabeledField with VStack for custom styling

### Why These Changes
- **User Experience**: Makes it immediately clear which fields are mandatory before attempting to submit
- **Reduces Errors**: Users won't try to submit incomplete forms, reducing validation error messages
- **Industry Standard**: Red asterisks are a universally recognized pattern for required fields
- **Consistency**: Applied across all platforms (React Native and iOS) and all screens (Create and Edit)

### Testing Recommendations
- Verify red asterisks appear correctly on both Create Listing and Edit Listing screens
- Confirm color is visible and distinct (red #FF0000)
- Check both iOS Swift app and React Native versions
- Test in both light and dark mode if applicable

---

## December 12, 2025 - Snapchat & Instagram Story Sharing Implementation (Reddit-Style)

### Overview
Implemented native Snapchat and Instagram story sharing functionality using Snap Kit SDK (via CocoaPods). Users can now share their CampusLink listings directly to Snapchat Stories with a visual sticker - exactly like Reddit does it.

### Implementation Approach

**Snap Kit SDK via CocoaPods**: Snap Kit only supports CocoaPods (not SPM). Added CocoaPods to the project while maintaining existing Swift Package Manager dependencies for Supabase and Stripe. Both package managers work together seamlessly.

### Changes Made

#### 1. Installed CocoaPods and Snap SDK
- **Installed CocoaPods**: via Homebrew (`brew install cocoapods`)
- **Created Podfile**: `ios-swift/Podfile` with SnapSDK dependency
- **Installed Pod**: `pod install` - installed SnapSDK 2.6.0
- **Created Workspace**: `CampusLink.xcworkspace` (CocoaPods standard)
- **Integration**: CocoaPods works alongside existing Swift Package Manager dependencies

#### 2. Updated Info.plist with Snap Kit Configuration
- **File Modified**: `ios-swift/CampusLink/Info.plist`
- Added `SCSDKClientId`: `285cc4d0-6ab5-4a1b-8929-75d050749639`
- Added URL scheme for Snapchat callback: `campuslink`
- Added query schemes: `bitmoji-sdk`, `itms-apps`
- Configured `CFBundleURLTypes` for Snap Kit integration

#### 3. Implemented Native Snapchat Sharing with Snap SDK
- **File Modified**: `ios-swift/CampusLink/Core/Components/ShareListingSheet.swift`
- Added `import SCSDKCreativeKit`
- Implemented `shareToSnapchatStory()` using Snap Kit SDK
- Uses `SCSDKSnapPhoto`, `SCSDKSnapSticker`, and `SCSDKPhotoSnapContent`
- Uses `SCSDKSnapAPI().startSending()` for direct Snapchat launch
- Generates sticker image asynchronously before sharing
- Opens Snapchat directly with sticker ready in camera (Reddit-style)

#### 4. Updated Share UI with Dedicated Snapchat Button
- **File Modified**: `ios-swift/CampusLink/Core/Components/ShareListingSheet.swift`
- Replaced generic "Share Sticker" button with dedicated "Snapchat Stories" button
- Updated icon to `camera.fill`
- Changed color to Snapchat yellow (#FFFC00)
- Added `Color` extension to support hex color codes
- Button calls new `shareToSnapchatStory()` function

#### 5. Improved Sticker Design for Better Story Visibility
- **File Modified**: `ios-swift/CampusLink/Core/Components/ListingStickerView.swift`
- Enhanced visual design with improved typography (larger title, bolder price)
- Added gradient background for listings without images
- Increased padding and spacing for better readability
- Added shadow effect (`radius: 12, opacity: 0.15`) for depth
- Added subtle border overlay for definition
- Updated footer with "Tap to Open" call-to-action
- Better contrast for use on story backgrounds

#### 6. Synced Changes to Duplicate Files
- **Files Updated**:
  - `CampusLink/Core/Components/ShareListingSheet.swift`
  - `CampusLink/Core/Components/ListingStickerView.swift`
- Ensured both file locations have identical implementations

### Technical Implementation Details

**Snap Kit SDK Integration**:
- Uses native Snap Kit SDK (v2.6.0) via CocoaPods
- Configured with Client ID: `285cc4d0-6ab5-4a1b-8929-75d050749639`
- Direct API calls to Snapchat - no intermediary share sheets
- Generates UIImage from SwiftUI view (`ListingStickerView`)
- Creates `SCSDKPhotoSnapContent` with sticker overlay
- Attachment URL links back to CampusLink App Store page

**Sticker Generation**:
- Downloads listing image asynchronously if available
- Renders SwiftUI view to UIImage using `ImageRenderer`
- 300x250pt image area + details section
- Optimized for Instagram and Snapchat story dimensions

**User Flow**:
1. User creates listing → Share sheet appears
2. User taps "Snapchat Stories" button
3. App generates visual sticker with listing details
4. iOS share sheet appears with sharing options
5. User selects Snapchat (or any other app)
6. Selected app opens with image ready to share
7. Works with Snapchat, Instagram, Messages, WhatsApp, etc.

### Instagram Stories Status
- **Deferred**: Meta Developer Portal currently inaccessible
- **Required**: Facebook App ID for `source_application` parameter
- **Implementation**: Ready to complete when Meta portal is available

### Benefits of Share Sheet Approach
- ✅ No SDK dependencies (keeps project clean)
- ✅ Works with ALL sharing apps (Snapchat, Instagram, WhatsApp, etc.)
- ✅ No CocoaPods required (stays with SPM)
- ✅ Simpler code, easier to maintain
- ✅ No API registration required
- ✅ Users can share anywhere they want

### Limitations vs SDK Approach
- ❌ Requires one extra tap (user selects app from share sheet)
- ❌ Not direct-to-Snapchat like Reddit
- ❌ Can't pre-position sticker in Snapchat camera

**Decision**: The share sheet approach is better for this use case because:
1. It's more flexible (works everywhere)
2. No dependency management issues
3. More reliable long-term (no SDK version conflicts)
4. One extra tap is acceptable trade-off

### Next Steps
1. Test on physical device
2. Monitor share metrics
3. Consider deep linking when user returns from share

---

## December 12, 2025 - 5-Day Order Completion Deadline for Sellers

### Overview
Implemented a 5-day deadline for sellers to complete orders. If an order isn't completed within 5 days, it's automatically cancelled and the buyer is refunded. This protects buyers from unresponsive sellers.

### Changes Made

#### 1. Created Edge Function for Auto-Cancellation
**File Created**: `supabase/functions/process-expired-orders/index.ts`

This edge function runs hourly via cron and:
- Finds orders older than 5 days that aren't completed
- Cancels/voids Stripe payment authorizations
- Refunds captured payments or wallet payments
- Updates order status to "cancelled"
- Notifies both buyer and seller via push notifications
- Restores listing availability (unmarks as sold)

#### 2. Created SQL for Cron Job Setup
**File Created**: `docs/sql/auto_cancel_expired_orders.sql`

Complete SQL setup for:
- Enabling pg_net and pg_cron extensions
- Scheduling hourly job to call the edge function
- Verification queries
- Alternative database-only approach (without edge function)

#### 3. Updated ActiveOrderMonitor with Deadline Tracking
**File Modified**: `ios-swift/CampusLink/Core/Services/ActiveOrderMonitor.swift`

Added:
- `ordersNearDeadline` and `expiredOrders` published properties
- `orderDeadlineSeconds` constant (5 days)
- `deadlineWarningSeconds` constant (4 days - 24hr warning)
- Static utility methods:
  - `timeUntilDeadline(for:)` - returns TimeInterval
  - `isNearDeadline(order:)` - true if within 24hrs of deadline
  - `isPastDeadline(order:)` - true if past 5 days
  - `formattedTimeRemaining(for:)` - human-readable string
  - `deadlineDate(for:)` - returns the deadline Date
- `sendDeadlineWarnings()` function for local notifications

#### 4. Added Deadline Display in OrderDetailView
**File Modified**: `ios-swift/CampusLink/Features/Payments/Views/OrderDetailView.swift`

Added visual deadline indicator showing:
- Time remaining until deadline
- Deadline date
- Circular progress indicator (% of time elapsed)
- Color coding:
  - Blue: >24 hours remaining
  - Orange: <24 hours remaining (urgent)
  - Red: Past deadline (will be cancelled)
- Warning messages for sellers to complete orders

#### 5. Created CircularProgressView Component
Added helper view for displaying deadline progress visually.

### Technical Details

**5-Day Deadline Logic**:
```
Order Created → 5 days → Auto-Cancel
              ↑
              └── 24hr warning sent at 4 days
```

**Edge Function Flow**:
1. Query orders with `order_status IN ('placed', 'seller_confirmed', 'in_progress')` AND `created_at < NOW() - 5 days`
2. For each expired order:
   - If has `stripe_payment_intent_id`:
     - Status `requires_capture` → Cancel authorization
     - Status `succeeded` → Create refund
   - If wallet payment → Credit buyer's wallet
   - Update order status to 'cancelled'
   - Queue notifications for buyer and seller
   - Restore listing availability

**Cron Schedule**: `0 * * * *` (hourly at minute 0)

### Deployment Required

1. **Deploy the edge function**:
```bash
supabase functions deploy process-expired-orders
```

2. **Run the SQL in Supabase Dashboard**:
- Go to SQL Editor
- Paste contents of `docs/sql/auto_cancel_expired_orders.sql`
- Run to enable cron job

### User Experience

**For Sellers**:
- See deadline countdown on order detail page
- Receive push notification 24 hours before deadline
- Clear warning if order is at risk of cancellation

**For Buyers**:
- Protected from unresponsive sellers
- Automatic refund if seller doesn't complete
- Listing becomes available again for others

### Benefits

- **Buyer Protection**: No more waiting indefinitely
- **Seller Accountability**: Clear expectations for completion
- **Platform Health**: Reduces stale/abandoned orders
- **Automatic Cleanup**: No manual intervention needed

---

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

### Deployment Completed

Successfully deployed all legal documents to the production website:

1. **Pushed to campusconnect-stripe-redirect repository**
   - Repository: https://github.com/dbc00per1812/campusconnect-stripe-redirect.git
   - All 6 web files deployed via GitHub Pages
   - Commit: fea0472 "Add complete legal documents and update website"

2. **Updated index.html footer**
   - Added Community Guidelines link
   - All three legal document links now functional:
     - Privacy Policy → privacy.html
     - Terms of Service → terms.html
     - Community Guidelines → community-guidelines.html

3. **Live URLs** (should be accessible within 1-2 minutes):
   - https://campusconnect.services/privacy.html
   - https://campusconnect.services/terms.html
   - https://campusconnect.services/community-guidelines.html
   - https://campusconnect.services/ (homepage)

4. **Also committed to main CampusLink repository**
   - Keeping web files synchronized in both repositories
   - Main repo: web/ directory with all legal documents
   - Website repo: root level HTML files for GitHub Pages deployment

---

*Log maintained by AI Assistant*
