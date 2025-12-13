---
name: Transaction Alert & Visibility Features
overview: ""
todos:
  - id: 055a97ed-53bd-433c-b41e-2e42db62f748
    content: Add 'What Happens Next' section to PurchaseConfirmationView with step-by-step transaction verification process
    status: completed
  - id: 38bcd411-138e-4333-8078-10e605681d48
    content: Create ActiveOrderMonitor service for background polling and repeated notifications
    status: completed
  - id: 158ee27f-e02d-4e8f-b97c-7a2a4f2e73cb
    content: Add flashing 'Active Post' button to HomeTabView header that shows when orders need attention
    status: completed
  - id: 36fe73b9-4e49-4f0c-a962-e2a626fc8468
    content: Add red badge icon with count in MyTransactionsView toolbar when orders require user action
    status: completed
  - id: e285f5cc-301d-41ad-a8a6-e7b00bea7587
    content: Add 'What Happens Next' section to PurchaseConfirmationView with step-by-step transaction verification process
    status: completed
  - id: 0bb10100-39e9-4441-9ada-2bee08e5e9c1
    content: Add 'What Happens Next' section to PurchaseConfirmationView with step-by-step transaction verification process
    status: completed
  - id: fb381553-ebbb-451f-9c46-c80f2325c438
    content: Create ActiveOrderMonitor service for background polling and repeated notifications
    status: completed
  - id: 5ce7e7d4-68d8-4276-8ef1-1f49d42ce8e4
    content: Add flashing 'Active Post' button to HomeTabView header that shows when orders need attention
    status: completed
  - id: 557f6dfb-0a79-4294-aa14-614636254a88
    content: Add red badge icon with count in MyTransactionsView toolbar when orders require user action
    status: completed
  - id: 506bdd85-89df-4ad6-ac4e-5eda932c32d8
    content: Add 'What Happens Next' section to PurchaseConfirmationView with step-by-step transaction verification process
    status: completed
  - id: ff29aca2-b02e-4f50-9c85-e6a651363a5a
    content: Add 'What Happens Next' section to PurchaseConfirmationView with step-by-step transaction verification process
    status: completed
  - id: d0abdbef-135d-468c-bada-acc4d09b8b5f
    content: Add 'What Happens Next' section to PurchaseConfirmationView with step-by-step transaction verification process
    status: completed
---

# Transaction Alert & Visibility Features

## Overview

Implement 4 key features to improve transaction visibility and user awareness for active orders requiring attention.

## Features to Implement

### 1. Order Confirmed Page - Add Transaction Verification Steps

**File:** `CampusLink/Features/Payments/Views/PurchaseConfirmationView.swift`

Add a new "What Happens Next" section that shows clear step-by-step verification process:

- Step 1: Seller prepares and delivers the item
- Step 2: Seller uploads delivery photo and marks as delivered
- Step 3: You receive notification to confirm receipt
- Step 4: You verify and confirm receipt to release payment
- Include estimated timeline and escrow protection details

### 2. Repeated Notifications for Sales in Process

**Files:**

- `CampusLink/Core/Services/NotificationService.swift`
- New: `CampusLink/Core/Services/ActiveOrderMonitor.swift`

Implement background polling system:

- Create `ActiveOrderMonitor` service that checks for orders in `seller_confirmed` status every 5 minutes
- For sellers: Check if buyer hasn't confirmed receipt after 24 hours → send reminder notification
- For buyers: Check if they have orders waiting for confirmation → send reminder
- Use iOS background task capabilities for notifications even when app is backgrounded
- Add notification preferences to allow users to control frequency

### 3. "Active Post" Button on Home Page

**File:** `CampusLink/Features/Home/HomeTabView.swift`

Add prominent button in header:

- Position: Next to "Sell now" button in header
- Style: Red background when active orders exist, flashing animation
- Logic: Query orders where user is seller AND `order_status = 'seller_confirmed'` OR user is buyer AND `order_status = 'seller_confirmed'`
- Action: Navigate directly to `MyTransactionsView` and auto-select appropriate tab (Sales/Purchases)
- Badge showing count of orders requiring attention
- Auto-refresh count every 30 seconds when app is active

### 4. Red Icon in Transactions View

**File:** `CampusLink/Features/Payments/Views/MyTransactionsView.swift`

Add visual indicator in navigation bar:

- Create computed property `hasOrdersRequiringAction` that checks:
  - For Sales tab: Count orders in `placed` or `in_progress` status (seller needs to deliver)
  - For Purchases tab: Count orders in `seller_confirmed` status (buyer needs to confirm)
- Add red badge icon in top-right toolbar next to filter button
- Show count bubble with number of orders requiring action
- Pulse animation when count > 0

## Implementation Details

### Key Order States to Monitor

```swift
// Seller waiting for delivery
orderStatus == .placed || orderStatus == .inProgress

// Buyer waiting to confirm receipt
orderStatus == .sellerConfirmed && paymentStatus == .requiresCapture
```

### Database Queries Needed

1. Check active orders requiring user action
2. Filter by current user as buyer or seller
3. Exclude completed, cancelled, or disputed orders

### UI Components

- Flashing red button with SF Symbol icon
- Navigation badge overlay
- Timeline component for verification steps
- Custom notification banner

## Testing Checklist

- [ ] Seller marks order as delivered → Buyer sees red indicator
- [ ] Buyer has pending confirmation → "Active Post" button appears and flashes
- [ ] Notifications trigger every 5 minutes for pending orders
- [ ] Clicking "Active Post" navigates to correct tab
- [ ] Red icon count updates in real-time
- [ ] Works for both buyer and seller perspectives