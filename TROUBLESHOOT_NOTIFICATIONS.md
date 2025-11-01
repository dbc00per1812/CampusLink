# Troubleshooting: Notifications Not Showing

## Issue
Seller (test user) did not receive notification when buyer placed order.

## Debugging Steps

### Step 1: Check Xcode Console Logs
When you place an order, look for these logs in Xcode console:

**Expected logs when notification works:**
```
✅ Order created successfully: [order-id]
📬 createOrderNotification called:
   - User ID: [seller-uuid]
   - Order ID: [order-uuid]
   - Listing: [item name]
   - Status: placed
📬 Creating notification: order_placed for user [seller-uuid]
✅ Notification created successfully
✅ Order notification created successfully
```

**If you see error logs:**
```
❌ Failed to create notification: [error message]
❌ Error details: [details]
```

This tells us exactly what's failing.

### Step 2: Run Diagnostic SQL in Supabase

1. Open Supabase Dashboard → SQL Editor
2. Run the script: `check_notification_setup.sql`
3. Look at the results:

**Check these specific results:**

**Result #5 - Recent Orders:**
- Does `notification_count` = 0 for recent orders?
- If yes, notifications aren't being created in the database

**Result #3 - User Notification Preferences:**
- Does the seller have `order_notifications = true`?
- Is `push_enabled = true`?
- If NULL or false, this could block notifications

**Result #4 - RLS Policies:**
- Look for INSERT policy on notifications
- Make sure users can insert their own notifications OR there's a service role policy

### Step 3: Common Issues & Fixes

#### Issue A: RLS Policy Too Restrictive
**Symptom:** Error mentions "row-level security" or "policy"

**Fix:** Run this SQL to check/fix RLS:
```sql
-- Check existing policies
SELECT policyname, cmd, qual 
FROM pg_policies 
WHERE tablename = 'notifications';

-- If no INSERT policy exists, create one:
CREATE POLICY "Users can create any notifications" 
ON notifications FOR INSERT 
WITH CHECK (true);

-- OR more restrictive:
CREATE POLICY "Users can create notifications for themselves" 
ON notifications FOR INSERT 
WITH CHECK (auth.uid()::text = user_id);
```

#### Issue B: Missing User in Public Users Table
**Symptom:** Foreign key constraint error mentioning `user_id`

**Fix:** The seller might not exist in the public.users table:
```sql
-- Check if seller exists
SELECT id, email, name 
FROM users 
WHERE id = 'SELLER_UUID_HERE';

-- If not found, create manually:
INSERT INTO users (id, email, created_at)
VALUES (
  'SELLER_UUID_FROM_AUTH_USERS',
  'seller@email.edu',
  NOW()
);
```

#### Issue C: Missing Notification Preferences
**Symptom:** No error, but notification doesn't appear

**Fix:** Create notification preferences for the seller:
```sql
-- Check preferences
SELECT * 
FROM user_notification_preferences 
WHERE user_id = 'SELLER_UUID';

-- If not found, create:
INSERT INTO user_notification_preferences (
  user_id,
  push_enabled,
  order_notifications,
  message_notifications,
  payment_notifications,
  rating_notifications,
  marketplace_notifications
) VALUES (
  'SELLER_UUID',
  true,
  true,
  true,
  true,
  true,
  false
);
```

#### Issue D: App Config Disabled
**Symptom:** Console shows "⚠️ Notifications disabled in AppConfig"

**Fix:** Check `AppConfig.swift`:
```swift
static let enableNotifications = true  // Must be true
```

### Step 4: Test End-to-End

After fixing issues, test the complete flow:

1. **As Buyer:** Place an order
2. **Check Console:** Look for notification creation logs
3. **Check Supabase:** Query notifications table:
   ```sql
   SELECT * FROM notifications 
   ORDER BY created_at DESC 
   LIMIT 5;
   ```
4. **As Seller:** 
   - Open app
   - Pull down to refresh notifications
   - Check notification bell icon for badge
   - Tap bell to see notification list

### Step 5: Check Seller's App State

Make sure the seller's app:
- ✅ Is logged in with the correct account
- ✅ Has notification permissions enabled (Settings → Notifications)
- ✅ Has pulled down to refresh the notification list
- ✅ Is checking the notification bell icon (not elsewhere)

### Quick Diagnostic Checklist

Run through this checklist:

- [ ] **Xcode Console** - Do you see "✅ Order notification created successfully"?
- [ ] **SQL Query** - Does the notification exist in the database?
- [ ] **RLS Policies** - Can users INSERT into notifications table?
- [ ] **User Exists** - Does seller exist in public.users table?
- [ ] **Preferences** - Does seller have notification preferences?
- [ ] **App Config** - Is enableNotifications = true?
- [ ] **Seller Logged In** - Is seller using the right account?
- [ ] **Permissions** - Did seller allow notifications in iOS settings?

### Most Likely Issues (in order)

1. **RLS Policy** - User can't insert into notifications table
2. **Missing User** - Seller doesn't exist in public.users
3. **Seller Not Refreshing** - App needs to fetch new notifications
4. **Wrong User** - Seller logged into different account

### Get Help

If still not working, provide:
1. Console logs from placing an order
2. Results from `check_notification_setup.sql`
3. Seller's user ID (UUID)
4. Whether notification appears in Supabase notifications table

---

## Expected Behavior

When working correctly:
1. Buyer places order
2. Notification inserted into database immediately
3. Seller's app fetches notifications (on open or refresh)
4. Notification appears in bell icon with badge count
5. Tapping bell shows notification list with new order notification


