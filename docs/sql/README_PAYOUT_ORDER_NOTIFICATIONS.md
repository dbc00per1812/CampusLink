# Fix Payout Setup & Order Notifications

## Issues Fixed

### 1. Payout Setup Completion Notification ❌ → ✅
**Problem**: Users completing Stripe Connect payout setup weren't receiving notifications confirming their setup was complete.

**Solution**: Added a database trigger `on_payout_setup_complete` that automatically sends a notification when `stripe_payouts_enabled` changes from `false` to `true`. The notification includes:
- Confirmation that payout setup is complete
- Amount of pending funds (if any) waiting to be transferred
- Link to Wallet screen

### 2. Order Notifications Not Working ❌ → ✅
**Problem**: Sellers weren't receiving notifications when someone purchased from them (bought a ticket).

**Solution**: 
- Improved the `on_order_placed` trigger with better error handling
- Added null checks and error logging to prevent silent failures
- Ensured the trigger is properly enabled

## How to Apply the Fix

### Step 1: Run the SQL Script

1. Open Supabase Dashboard → SQL Editor
2. Copy and paste the contents of `fix_payout_setup_and_order_notifications.sql`
3. Run the script

The script will:
- ✅ Improve the order notification trigger with error handling
- ✅ Add the payout setup completion notification trigger
- ✅ Verify all triggers are enabled
- ✅ Show diagnostic queries to check recent orders and payout setups

### Step 2: Verify Triggers Are Enabled

After running the script, check the verification output. You should see:

```
✅ ENABLED  | on_order_placed          | orders
✅ ENABLED  | on_payout_setup_complete  | users
```

### Step 3: Test the Fixes

#### Test Order Notifications:
1. Have User A create a listing
2. Have User B purchase from User A
3. User A should receive a push notification: "New Order! 💰 [Buyer] purchased '[Listing]' for $X.XX"

#### Test Payout Setup Notifications:
1. User completes Stripe Connect onboarding
2. When `stripe_payouts_enabled` changes to `true`, user receives notification:
   - If pending funds: "Payout Setup Complete! 🎉 Your payout account is ready! You have $X.XX waiting to be transferred."
   - If no pending funds: "Payout Setup Complete! 🎉 Your payout account is ready! You can now receive payments from sales."

## How It Works

### Order Notifications
- Trigger: `on_order_placed` fires AFTER INSERT on `orders` table
- Function: `notify_order_placed()` gets buyer name, listing title, and order amount
- Notification: Sent via `send_onesignal_notification()` to the seller
- Error Handling: If notification fails, logs warning but doesn't fail the order insert

### Payout Setup Notifications
- Trigger: `on_payout_setup_complete` fires AFTER UPDATE on `users` table when `stripe_payouts_enabled` changes
- Function: `notify_payout_setup_complete()` checks for pending funds and sends appropriate message
- Notification: Sent via `send_onesignal_notification()` to the user
- Error Handling: If notification fails, logs warning but doesn't fail the user update

## Troubleshooting

### If order notifications still don't work:

1. **Check trigger is enabled:**
```sql
SELECT tgname, tgrelid::regclass, tgenabled 
FROM pg_trigger 
WHERE tgname = 'on_order_placed';
```
Should show `tgenabled = 'O'` (enabled)

2. **Check recent orders:**
```sql
SELECT o.id, o.seller_id, o.created_at, n.id AS notification_id
FROM orders o
LEFT JOIN notifications n ON n.order_id = o.id AND n.type = 'order_placed'
ORDER BY o.created_at DESC
LIMIT 10;
```

3. **Check function exists:**
```sql
SELECT proname FROM pg_proc WHERE proname = 'notify_order_placed';
```

4. **Check send_onesignal_notification function:**
```sql
SELECT proname FROM pg_proc WHERE proname = 'send_onesignal_notification';
```

### If payout setup notifications don't work:

1. **Check trigger is enabled:**
```sql
SELECT tgname, tgrelid::regclass, tgenabled 
FROM pg_trigger 
WHERE tgname = 'on_payout_setup_complete';
```

2. **Manually test the trigger:**
```sql
-- Update a test user (replace with actual user_id)
UPDATE users 
SET stripe_payouts_enabled = true 
WHERE id = 'your-user-id' AND stripe_payouts_enabled = false;
```

3. **Check notifications table:**
```sql
SELECT * FROM notifications 
WHERE type = 'payout_setup_complete' 
ORDER BY created_at DESC 
LIMIT 10;
```

## Related Files

- **SQL Script**: `docs/sql/fix_payout_setup_and_order_notifications.sql`
- **Main Notification Triggers**: `docs/sql/onesignal_notification_triggers.sql`
- **Webhook Handler**: `supabase/functions/stripe-webhook/index.ts`
- **Connect Onboarding**: `supabase/functions/connect_onboarding/index.ts`
- **OneSignal Function**: `supabase/functions/send-push-onesignal/index.ts`
