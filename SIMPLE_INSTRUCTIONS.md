# Simple Instructions - Get Everything Working

## Step 1: Restore Message Notifications

Run `RESTORE_TO_WORKING_STATE_FINAL.sql`

This restores message notifications to the exact code that was working before.

**Test**: Send a message via the app. Check if notification appears.

---

## Step 2: Add Order Notifications (After Step 1 Works)

Run `ADD_ORDER_NOTIFICATIONS_SEPARATE.sql`

This ONLY touches the orders table. Never touches messages.

**Test**: Place an order. Check if seller gets notification.

---

## That's It

Two simple scripts. No complexity. No debugging.

If Step 1 doesn't work, then something else changed in your database (not just the trigger).

If Step 1 works, then Step 2 will work too.

---

**Run Step 1 now and tell me if message notifications work.**


