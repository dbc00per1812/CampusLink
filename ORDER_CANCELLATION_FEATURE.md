# Order Cancellation Feature

## Overview
Buyers can now cancel orders and receive automatic refunds **if the seller hasn't confirmed the order yet**.

## How It Works

### For Buyers
1. **When you can cancel**: Only when the order status is "Order Placed" (seller hasn't confirmed yet)
2. **Where to cancel**: Go to the order details screen and tap the red "Cancel Order" button
3. **What happens**: 
   - Order status changes to "Cancelled"
   - Full amount (including all fees) is immediately refunded to your Campus Wallet
   - Seller receives a notification about the cancellation
   - This action **cannot be undone**

### For Sellers
- You'll receive a notification if a buyer cancels their order
- Once you've confirmed an order, the buyer can no longer cancel it
- This protects you from last-minute cancellations after you've started preparing the order

## Business Rules

| Condition | Can Cancel? |
|-----------|-------------|
| Order status is "Placed" | ✅ Yes |
| Seller has confirmed | ❌ No |
| Order is in progress | ❌ No |
| Order is completed | ❌ No |
| Order is already cancelled | ❌ No |

## Refund Details

- **Refund Amount**: Full buyer price (includes all fees paid)
- **Refund Destination**: Campus Wallet (available immediately)
- **Processing Time**: Instant
- **Verification**: System verifies wallet balance update was successful

## User Interface

### Cancel Button Location
- Appears in the "Actions" section of the Order Detail screen
- Red button with "Cancel Order" text
- Only visible to buyers when order is cancellable

### Confirmation Dialog
```
Cancel Order?

This will cancel the order and refund the full amount to 
your wallet. This action cannot be undone.

[No]  [Yes, Cancel]
```

### Success Message
```
Order has been cancelled. The full amount has been 
refunded to your wallet.
```

## Error Handling

The system prevents:
- Non-buyers from cancelling orders
- Cancelling orders that have progressed past "placed" status
- Double-cancellation attempts
- Wallet update failures (with detailed error messages)

## Technical Implementation

### New Methods
- `OrderService.cancelOrder(_:)` - Main cancellation logic
- `OrderService.refundBuyer(order:)` - Handles refund to buyer's wallet
- `OrderDetailView.cancelOrder()` - UI handler for cancellation

### Database Updates
When an order is cancelled:
- `order_status` → "cancelled"
- `payment_status` → "refunded"
- `cancelled_at` → current timestamp
- `refunded_at` → current timestamp
- `updated_at` → current timestamp

### Notifications
- Seller receives notification of type `.cancelled`
- Notification includes order ID and listing title

## Security
- Only the buyer (order creator) can cancel their own orders
- Session verification ensures authenticated requests
- Order status validation prevents cancellation at wrong stages
- Wallet updates include verification to ensure funds were properly credited

