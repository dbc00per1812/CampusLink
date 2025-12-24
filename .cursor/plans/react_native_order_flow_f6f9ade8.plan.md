---
name: React Native Order Flow
overview: Implement the complete order flow for the React Native app to match the iOS version, including purchase flow, payment integration, escrow, active order monitoring, realtime updates, and deadline tracking.
todos:
  - id: stripe-sdk
    content: Install and configure @stripe/stripe-react-native SDK
    status: completed
  - id: stripe-service
    content: Enhance stripeService.ts with PaymentSheet configuration
    status: completed
  - id: buy-now-flow
    content: Implement Buy Now purchase flow in ListingDetailScreen
    status: completed
  - id: order-escrow
    content: Update orderService.ts with escrow account creation and wallet deduction
    status: completed
  - id: active-monitor
    content: Create activeOrderMonitor.ts service with deadline tracking
    status: completed
  - id: order-context
    content: Create OrderMonitorContext for sharing order state
    status: completed
  - id: order-timeline
    content: Add order timeline section to OrderDetailScreen
    status: completed
  - id: deadline-indicator
    content: Add deadline indicator with countdown to OrderDetailScreen
    status: completed
  - id: escrow-status
    content: Add escrow status section to OrderDetailScreen
    status: completed
  - id: delivery-photo
    content: Add delivery photo upload for sellers
    status: completed
  - id: realtime-updates
    content: Add Supabase realtime subscription for order updates
    status: completed
  - id: pay-from-detail
    content: Add Confirm & Pay flow for pending orders
    status: completed
  - id: contact-integration
    content: Implement Contact Seller/Buyer with conversation creation
    status: completed
---

# React Native Order Flow Implementation

This plan aligns the React Native order flow with the iOS implementation, covering purchase/payment, escrow, monitoring, and UI features.

---

## Phase 1: Stripe Payment Integration

The iOS app has full Stripe PaymentSheet integration. React Native needs this implemented.

### 1.1 Install and Configure Stripe SDK

- Install `@stripe/stripe-react-native` package
- Configure Stripe provider in `App.tsx`
- Update [`mobile/src/config/secrets.example.ts`](mobile/src/config/secrets.example.ts) with Stripe keys

### 1.2 Enhance Stripe Service

Update [`mobile/src/services/stripeService.ts`](mobile/src/services/stripeService.ts) to match iOS `PaymentService`:

- `configurePaymentSheet(listingId)` - Calls edge function to get client secret
- `presentPaymentSheet()` - Shows Stripe payment UI
- Handle payment results (completed, cancelled, failed)

### 1.3 Create Payment Intent Edge Function Integration

Ensure the React Native app correctly calls `create_payment_intent` edge function with:

- `listingId`, `buyerId`, `sellerId`, `amount`

---

## Phase 2: Purchase Flow (Buy Now)

The iOS purchase flow creates orders with escrow. React Native has placeholders.

### 2.1 Implement Purchase Flow in ListingDetailScreen

Update [`mobile/src/screens/home/ListingDetailScreen.tsx`](mobile/src/screens/home/ListingDetailScreen.tsx):

```typescript
const handleBuyNow = async () => {
  // 1. Check wallet balance for wallet payments
  // 2. Configure Stripe PaymentSheet
  // 3. Present payment UI
  // 4. On success, create order via orderService.createOrder()
  // 5. Navigate to OrderDetailScreen
};
```

### 2.2 Update Order Creation with Escrow

Update [`mobile/src/services/orderService.ts`](mobile/src/services/orderService.ts):

- Add escrow account creation via edge function before order insert
- Match iOS logic for `stripeEscrowAccountId` handling
- Deduct wallet balance for wallet payments (matching iOS)

Key iOS logic to port from `OrderService.swift:15-188`:

- Get/create escrow account for seller
- Generate verification PIN for services
- Deduct buyer wallet on wallet payments

---

## Phase 3: Active Order Monitoring

iOS has `ActiveOrderMonitor` for tracking orders requiring action. React Native needs this.

### 3.1 Create ActiveOrderMonitor Service

Create new file `mobile/src/services/activeOrderMonitor.ts`:

```typescript
// Constants
const ORDER_DEADLINE_SECONDS = 5 * 24 * 60 * 60; // 5 days
const DEADLINE_WARNING_SECONDS = 4 * 24 * 60 * 60; // 24 hours before

// Functions
- startMonitoring(userId)
- stopMonitoring()
- checkActiveOrders(userId)
- timeUntilDeadline(order)
- isNearDeadline(order)
- isPastDeadline(order)
- formattedTimeRemaining(order)
```

### 3.2 Integrate with Tab Bar

- Add order count badge to Orders tab
- Show count on home screen via `ActiveOrderBanner` component (already exists)

### 3.3 Use React Context for State

Create `OrderMonitorContext` to share state across screens

---

## Phase 4: Order Detail Screen Enhancements

Match iOS `OrderDetailView` features.

### 4.1 Add Order Timeline Section

Update [`mobile/src/screens/orders/OrderDetailScreen.tsx`](mobile/src/screens/orders/OrderDetailScreen.tsx):

- Add visual timeline with steps: Placed -> Seller Confirmed -> Buyer Confirmed -> Completed
- Show dates for each completed step

### 4.2 Add Deadline Indicator

Match iOS `deadlineIndicatorView`:

- Show remaining time (e.g., "3d 12h left")
- Color coding: blue (normal), orange (near deadline), red (expired)
- Circular progress indicator

### 4.3 Add Escrow Status Section

Show escrow protection status:

- "Held in Escrow" for active orders
- "Released" for completed orders

### 4.4 Add Delivery Photo Upload

For sellers marking products as delivered:

- Image picker for proof of delivery
- Upload to Supabase storage
- Pass URL to `markDelivered()`

### 4.5 Realtime Order Updates

Add Supabase realtime subscription:

```typescript
supabase.channel(`order:${orderId}`)
  .on('postgres_changes', { event: 'UPDATE', table: 'orders' }, (payload) => {
    setOrder(payload.new);
  })
  .subscribe();
```

---

## Phase 5: Payment on Order Detail

iOS allows paying for pending orders from OrderDetailScreen.

### 5.1 Add "Confirm & Pay" Button

For orders where `payment_status === 'pending'`:

- Show payment required banner
- "Confirm Order & Pay" button triggers Stripe PaymentSheet

### 5.2 Handle Payment Result

- On success: Update order, show success overlay
- On failure: Show error alert

---

## Phase 6: Conversation Integration

Match iOS order-to-chat flow.

### 6.1 "Contact Seller/Buyer" Button

- Create or find existing conversation for the listing
- Navigate to ChatScreen with conversation

### 6.2 Conversation Creation

Match iOS logic in `OrderDetailView.loadConversation()`:

- Check both directions (buyer/seller IDs)
- Include buyer/seller user profiles

---

## Key Files to Modify

| File | Changes |

|------|---------|

| `mobile/src/services/stripeService.ts` | Add PaymentSheet config/present |

| `mobile/src/services/orderService.ts` | Add escrow, wallet deduction |

| `mobile/src/screens/home/ListingDetailScreen.tsx` | Implement Buy Now flow |

| `mobile/src/screens/orders/OrderDetailScreen.tsx` | Timeline, deadline, escrow, realtime |

| `mobile/src/services/activeOrderMonitor.ts` | NEW: Order monitoring service |

| `mobile/src/context/OrderMonitorContext.tsx` | NEW: Context for order counts |

---

## Dependencies to Add

```json
{
  "@stripe/stripe-react-native": "^0.37.0"
}
```

---

## Database Interactions (No Changes Needed)

The React Native app uses the same Supabase backend as iOS. All tables and RPC functions are already in place:

- `orders` table
- `wallets` table  
- `verify_service_pin` RPC
- Stripe edge functions