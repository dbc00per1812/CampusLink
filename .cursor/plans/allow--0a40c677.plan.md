<!-- 0a40c677-c46e-4192-baea-65f90008c8dd 1aa4cfe8-535e-4985-b4d1-eb302288d3c8 -->
# Allow Guest Browsing to Satisfy Apple Guideline 5.1.1

## Problem

The app currently requires users to authenticate before browsing products, which violates Apple Guideline 5.1.1. Apple requires that browsing (non-account-based features) must be freely accessible without registration.

## Solution Architecture

### Core Changes

**1. Update ContentView.swift** (Lines 17-21)

- **Current**: Shows `WelcomeView` if no session, `MainTabView` if authenticated
- **New**: Always show `MainTabView`, but pass authentication state
- The tab view will handle showing limited functionality for guest users

**2. Update WelcomeView.swift**

- Convert from a blocking screen to an authentication prompt overlay/sheet
- Allow users to dismiss and browse as guest
- Add "Browse as Guest" button that dismisses the sheet

**3. Update MainTabView.swift** (Lines 12-91)

- Accept optional `authManager.session` and handle guest state
- **Home Tab**: Allow full browsing access for guests
- **Messages Tab**: Show "Sign in required" placeholder for guests
- **Post Tab**: Show "Sign in required" placeholder for guests
- **Wallet Tab**: Show "Sign in required" placeholder for guests
- **Profile Tab**: Show guest profile with "Sign In" button for guests

**4. Update HomeTabView.swift** (Lines 1-558)

- Remove authentication requirement for browsing
- Currently loads listings on appear - keep this behavior
- Works fine as-is since it doesn't require `authManager.currentUserId` for browsing

**5. Update ListingDetailView.swift** (Lines 1-988)

- Allow viewing listing details without authentication
- **Guest restrictions**:
- Hide "Contact Seller" button for guests → show "Sign in to contact"
- Hide "Buy Now" button for guests → show "Sign in to purchase"
- Hide "Report" button for guests (requires account)
- Show info banner: "Sign in to interact with this listing"

**6. Create GuestPromptView.swift** (NEW)

- Reusable component for tabs that require authentication
- Shows friendly message: "This feature requires an account"
- Includes "Sign In" and "Sign Up" buttons
- Used in Messages, Post, Wallet, and Profile tabs when not authenticated

**7. Create GuestProfileView.swift** (NEW)

- Shows profile tab for guests
- Display app info, settings (dark mode), legal links
- Prominent "Sign In" and "Sign Up" buttons

## Account-Based Features (Require Auth)

These will show authentication prompts or be disabled for guests:

- Messaging sellers
- Purchasing items
- Creating listings
- Managing wallet/payouts
- Viewing orders
- Making/receiving offers
- Reporting listings/users

## Non-Account Features (Guest Accessible)

These will work without authentication:

- Browse all listings
- View listing details
- Search products
- Filter by category
- View seller profiles (read-only)

## Implementation Steps

1. Update `ContentView.swift` to always show `MainTabView`
2. Update `WelcomeView.swift` to be a dismissable auth prompt sheet
3. Create `GuestPromptView.swift` for restricted tabs
4. Create `GuestProfileView.swift` for guest profile tab
5. Update `MainTabView.swift` to handle guest state in each tab
6. Update `ProfileTabView.swift` to show `GuestProfileView` for guests
7. Update `ListingDetailView.swift` to disable actions for guests with appropriate messaging
8. Optional: Add banner to `HomeTabView.swift` encouraging sign up

## User Flow

**Guest User Launch:**

1. App opens → sees `HomeTabView` with listings immediately
2. Can browse, search, view details freely
3. When trying to message/purchase → shown authentication prompt
4. Can sign in/up at any time via Profile tab or action prompts

**Benefits:**

- Complies with Apple Guideline 5.1.1
- Better user experience (see before you sign up)
- Increased conversions (users see value first)
- Still requires auth for all account-based features

### To-dos

- [ ] Update ContentView.swift to always show MainTabView regardless of auth state
- [ ] Create GuestPromptView.swift reusable component for auth-required tabs
- [ ] Create GuestProfileView.swift for guest profile tab with sign in options
- [ ] Update MainTabView.swift to conditionally show GuestPromptView for Messages, Post, and Wallet tabs when not authenticated
- [ ] Update ProfileTabView.swift to show GuestProfileView when not authenticated
- [ ] Update ListingDetailView.swift to disable Contact/Buy actions for guests and show 'Sign in required' messaging
- [ ] Update WelcomeView.swift to be a dismissable sheet with 'Browse as Guest' option
- [ ] Optional: Add subtle banner to HomeTabView encouraging guests to sign up for full features