# Transaction Guide Feature - Testing Guide

## Overview
Added a comprehensive transaction guide accessible via the help button (question mark icon) on the React Native home screen, matching the iOS implementation.

## How to Test

### 1. Access the Guide
1. Open the CampusLink React Native app
2. Navigate to the Home tab
3. Look at the top header - you'll see a question mark icon (help-circle) next to the brand logo
4. Tap the question mark icon
5. The Transaction Guide screen should open

### 2. Verify Content Sections

The guide should contain the following sections in order:

#### Section 1: Buyer & Seller Protection (Blue)
- **Icon**: Shield checkmark
- **Content**:
  - Escrow Protection explanation
  - Two-Way Verification
  - CampusLink Wallet info

#### Section 2: Product Transactions (Blue)
- **Icon**: Cube
- **Content**:
  - For physical items (textbooks, electronics, furniture)
  - Buyer steps (4 steps with numbered circles)
  - Seller steps (4 steps with numbered circles)
  - Light blue and light green backgrounds for buyer/seller cards

#### Section 3: Service Transactions (Green)
- **Icon**: Person
- **Content**:
  - For services (tutoring, photography, moving)
  - 4-Digit PIN System explanation with keypad icon
  - Buyer steps (4 steps)
  - Seller steps (4 steps)

#### Section 4: Ticket Transactions (Orange)
- **Icon**: Ticket
- **Content**:
  - Special verification for event tickets
  - Accepted transfer methods (Apple Wallet, Ticketing Apps)
  - Buyer steps (5 steps)
  - Seller steps (5 steps)

#### Section 5: Payments & Wallet (Purple)
- **Icon**: Credit card
- **Content**:
  - Payment methods
  - Receiving payments (Stripe Connect)
  - Withdrawing funds
  - Wallet balance
  - First-time seller onboarding (3 steps)

#### Section 6: Need Help? (Primary blue)
- **Icon**: Help circle
- **Content**:
  - Support description
  - "Contact Support" button (opens email)
  - 24-hour response time indicator with clock icon

### 3. Verify Interactions

#### Navigation
- [ ] Help button on home screen navigates to guide
- [ ] Haptic feedback on button press (iOS/Android)
- [ ] "Done" button in top right closes the guide

#### Email Support
- [ ] Tap "Contact Support" button
- [ ] Opens email app with:
  - To: darragh.b3272@gmail.com
  - Subject: CampusLink Support Request

#### Scrolling
- [ ] Smooth scrolling through all sections
- [ ] Content is fully readable (no cut-off text)
- [ ] Proper spacing between sections
- [ ] Dividers between major sections

### 4. Visual Checks

#### Colors
- [ ] Section icons are properly colored (blue, green, orange, purple)
- [ ] Step numbers in colored circles (primary color)
- [ ] Light backgrounds for buyer/seller cards
- [ ] Proper contrast for text readability

#### Typography
- [ ] Large title at top: "How Transactions Work"
- [ ] Subtitle descriptive text
- [ ] Section headers with icons (bold)
- [ ] Step titles (semibold)
- [ ] Step descriptions (regular, readable)

#### Layout
- [ ] Proper padding on all sides
- [ ] Content centered and aligned
- [ ] Icons aligned with text
- [ ] Consistent spacing between elements

### 5. Dark Mode Testing

If your app supports dark mode:
- [ ] Toggle to dark mode
- [ ] Verify text is still readable
- [ ] Backgrounds adapt properly
- [ ] Icons remain visible
- [ ] No color contrast issues

### 6. Responsive Testing

Test on different screen sizes:
- [ ] Small phones (iPhone SE)
- [ ] Regular phones (iPhone 14)
- [ ] Large phones (iPhone 14 Pro Max)
- [ ] Tablets (iPad)

## Files Changed

### New Files
- `mobile/src/screens/home/TransactionGuideScreen.tsx`

### Modified Files
- `mobile/src/screens/home/HomeScreen.tsx` (help button handler)
- `mobile/src/navigation/types.ts` (added route)
- `mobile/src/navigation/HomeNavigator.tsx` (added screen)
- `mobile/src/utils/colors.ts` (added accent colors)

## Comparison with iOS

The React Native version matches the iOS implementation:
- ✅ Same content structure
- ✅ Same color coding for sections
- ✅ Same numbered steps design
- ✅ Same support email
- ✅ Same UI patterns (cards, icons, spacing)

## Known Differences from iOS

Minor platform differences (acceptable):
- React Native uses Ionicons, iOS uses SF Symbols (same visual intent)
- React Native uses View/ScrollView, iOS uses SwiftUI VStack
- Button styles adapted for React Native native feel

## Support Contact

Email: darragh.b3272@gmail.com
Response time: 24 hours

---

**Status**: ✅ Feature Complete
**Date**: December 13, 2025

