# Deploy Order Notification System

## Overview
This guide sets up **automatic database triggers** that send notifications when order status changes. This ensures both buyers and sellers are notified at every step of the order lifecycle.

## What Gets Fixed
- ✅ **Seller notified** when buyer places order
- ✅ **Buyer notified** when seller confirms delivery
- ✅ **Seller notified** when buyer confirms receipt
- ✅ **Both parties notified** when order is cancelled
- ✅ Removes redundant Swift notification calls (database handles it)

## Files Modified

### Swift Code Changes
- `CampusLink/Core/Services/OrderService.swift`
  - Removed 4 redundant `createOrderNotification()` calls
  - Notifications now handled entirely by database triggers
  - Cleaner code, no duplicate notifications

### SQL Files Created
1. **`verify_order_notifications.sql`** - Check current notification setup
2. **`fix_order_notifications.sql`** - Deploy all notification triggers

---

## Step-by-Step Deployment

### STEP 1: Verify Current Setup (Optional)
Run this in **Supabase SQL Editor** to see what's currently deployed:

```sql
-- Copy and run: verify_order_notifications.sql
```

This shows:
- Which triggers currently exist
- Recent orders and their notifications
- Any missing notifications

---

### STEP 2: Deploy Notification Triggers

1. Open **Supabase Dashboard** → SQL Editor
2. Copy entire contents of `fix_order_notifications.sql`
3. Click "Run"
4. Should see: ✅ Success (no errors)

**What this does:**
- Drops any old/conflicting triggers
- Creates 4 notification functions:
  - `notify_new_order()` - When order placed
  - `notify_order_delivered()` - When seller confirms
  - `notify_order_completed()` - When buyer confirms
  - `notify_order_cancelled()` - When order cancelled
- Creates 4 triggers that automatically call these functions
- Grants proper permissions

---

### STEP 3: Test the Triggers

#### Test 1: New Order Notification
```sql
-- Create a test order (replace UUIDs with real ones from your DB)
INSERT INTO orders (
    listing_id, 
    buyer_id, 
    seller_id, 
    price_cents, 
    payment_method, 
    payment_status, 
    order_status
) VALUES (
    '[existing-listing-id]',
    '[buyer-user-id]',
    '[seller-user-id]',
    1000,
    'apple_pay',
    'requires_capture',
    'placed'
);

-- Check if notification was created for SELLER
SELECT * FROM notifications 
WHERE type = 'order_placed' 
ORDER BY created_at DESC 
LIMIT 1;
```

**Expected:** You should see a notification for the seller with:
- `type = 'order_placed'`
- `title = 'New Order!'`
- `user_id` matches seller's ID

---

#### Test 2: Seller Confirms Delivery
```sql
-- Update order to seller_confirmed (replace with real order ID)
UPDATE orders 
SET order_status = 'seller_confirmed',
    seller_confirmed_at = NOW(),
    updated_at = NOW()
WHERE id = '[order-id]';

-- Check if notification was created for BUYER
SELECT * FROM notifications 
WHERE type = 'order_confirmed' 
ORDER BY created_at DESC 
LIMIT 1;
```

**Expected:** You should see a notification for the buyer with:
- `type = 'order_confirmed'`
- `title = 'Order Ready!'`
- `user_id` matches buyer's ID

---

#### Test 3: Buyer Confirms Receipt
```sql
-- Update order to completed (replace with real order ID)
UPDATE orders 
SET order_status = 'completed',
    buyer_confirmed_at = NOW(),
    completed_at = NOW(),
    updated_at = NOW()
WHERE id = '[order-id]';

-- Check if notification was created for SELLER
SELECT * FROM notifications 
WHERE type = 'order_completed' 
ORDER BY created_at DESC 
LIMIT 1;
```

**Expected:** You should see a notification for the seller with:
- `type = 'order_completed'`
- `title = 'Order Completed!'`
- `user_id` matches seller's ID

---

#### Test 4: Order Cancelled
```sql
-- Update order to cancelled (replace with real order ID)
UPDATE orders 
SET order_status = 'cancelled',
    cancelled_at = NOW(),
    updated_at = NOW()
WHERE id = '[order-id]';

-- Check if notifications were created for BOTH PARTIES
SELECT * FROM notifications 
WHERE type = 'order_cancelled' 
ORDER BY created_at DESC 
LIMIT 2;
```

**Expected:** You should see TWO notifications:
1. One for buyer: "Your order... has been cancelled and refunded"
2. One for seller: "The order... has been cancelled"

---

### STEP 4: Test in App

1. **Build and run** the updated app
2. **Place a test order:**
   - Buyer places order
   - Check seller's notifications tab → Should see "New Order!"
3. **Seller marks delivered:**
   - Seller goes to order → "Mark as Delivered"
   - Check buyer's notifications tab → Should see "Order Ready!"
4. **Buyer confirms receipt:**
   - Buyer goes to order → "Confirm Receipt"
   - Check seller's notifications tab → Should see "Order Completed!"

---

## Verification Queries

### Check all order notifications
```sql
SELECT 
    n.id,
    n.type,
    n.title,
    n.body,
    u.name as recipient_name,
    n.created_at,
    o.order_status
FROM notifications n
JOIN users u ON u.id = n.user_id::uuid
LEFT JOIN orders o ON o.id = n.order_id
WHERE n.type IN ('order_placed', 'order_confirmed', 'order_completed', 'order_cancelled')
ORDER BY n.created_at DESC
LIMIT 20;
```

### Check notification counts by type
```sql
SELECT 
    type,
    COUNT(*) as count,
    MAX(created_at) as last_created
FROM notifications
WHERE type IN ('order_placed', 'order_confirmed', 'order_completed', 'order_cancelled')
GROUP BY type
ORDER BY type;
```

### Find orders without notifications
```sql
-- Orders placed without notification
SELECT o.id, o.order_status, o.created_at
FROM orders o
LEFT JOIN notifications n ON n.order_id = o.id AND n.type = 'order_placed'
WHERE n.id IS NULL
ORDER BY o.created_at DESC;
```

---

## Troubleshooting

### Issue: No notifications appearing

**Check 1: Are triggers active?**
```sql
SELECT trigger_name, event_manipulation 
FROM information_schema.triggers
WHERE event_object_table = 'orders';
```
Should show 4 triggers: `order_created_notification_trigger`, `order_status_notification_trigger`, `order_completed_notification_trigger`, `order_cancelled_notification_trigger`

**Check 2: Are functions created?**
```sql
SELECT routine_name 
FROM information_schema.routines
WHERE routine_name LIKE 'notify_%';
```
Should show 4 functions: `notify_new_order`, `notify_order_delivered`, `notify_order_completed`, `notify_order_cancelled`

**Check 3: Test manually**
```sql
-- Call function directly
SELECT notify_new_order();
```

### Issue: Duplicate notifications

This shouldn't happen anymore since we removed the Swift notification calls. If you see duplicates:

1. Check git history - make sure you pulled the latest `OrderService.swift`
2. Verify the 4 manual notification calls were removed (lines 98, 201, 291, 618)
3. Check if old triggers exist - run Step 1 of `fix_order_notifications.sql` to drop them

### Issue: Notifications for wrong user

Check the trigger logic in `fix_order_notifications.sql`:
- `order_placed` → sends to `seller_id` ✅
- `order_confirmed` → sends to `buyer_id` ✅
- `order_completed` → sends to `seller_id` ✅
- `order_cancelled` → sends to BOTH ✅

---

## Benefits of This Approach

✅ **Automatic** - No manual Swift code needed
✅ **Reliable** - Can't forget to send notification
✅ **Consistent** - Same logic for all order updates
✅ **Fast** - Database triggers are instant
✅ **Audit Trail** - All notifications recorded in database
✅ **Works Everywhere** - Even if order updated via SQL/API
✅ **No Duplicates** - Single source of truth

---

## Rollback (If Needed)

If something goes wrong, you can disable the triggers:

```sql
-- Disable all order notification triggers
ALTER TABLE orders DISABLE TRIGGER order_created_notification_trigger;
ALTER TABLE orders DISABLE TRIGGER order_status_notification_trigger;
ALTER TABLE orders DISABLE TRIGGER order_completed_notification_trigger;
ALTER TABLE orders DISABLE TRIGGER order_cancelled_notification_trigger;

-- Re-enable later with:
ALTER TABLE orders ENABLE TRIGGER order_created_notification_trigger;
-- etc...
```

---

## Summary

After deployment:
- ✅ Swift code is cleaner (no manual notification calls)
- ✅ Database automatically sends notifications on order updates
- ✅ Both buyer and seller notified at every step
- ✅ Cancellations notify both parties
- ✅ No risk of missing/duplicate notifications

**Next Steps:**
1. Run `fix_order_notifications.sql` in Supabase
2. Test in app with a real order flow
3. Monitor notifications table to confirm they're being created

Darragh, the system is ready to deploy! 🚀

