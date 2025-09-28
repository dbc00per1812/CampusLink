# Notification Debug Steps

Follow these steps to identify why notifications aren't working:

## Step 1: Check Database Setup
Run this in your Supabase SQL editor:

```sql
-- Check if triggers exist
SELECT triggername FROM pg_trigger WHERE triggername LIKE '%notification%';

-- Should show:
-- trigger_order_placed_notification
-- trigger_order_status_notification  
-- trigger_offer_made_notification
-- trigger_offer_status_notification
```

## Step 2: Check Recent Activity
```sql
-- Check recent orders (should trigger seller notification)
SELECT id, buyer_id, seller_id, order_status, created_at 
FROM orders 
ORDER BY created_at DESC 
LIMIT 3;

-- Check if any notifications were created
SELECT id, user_id, type, title, created_at 
FROM notifications 
ORDER BY created_at DESC 
LIMIT 5;
```

## Step 3: Test Manual Notification Creation
```sql
-- Replace 'YOUR_USER_ID' with your actual UUID from auth.users
INSERT INTO notifications (
  user_id,
  type,
  title,
  body,
  data
) VALUES (
  'YOUR_USER_ID',
  'order_placed',
  'Manual Test Notification',
  'Testing if notifications work',
  '{}'::jsonb
);

-- Check if it was created
SELECT * FROM notifications WHERE title = 'Manual Test Notification';
```

## Step 4: Check User Preferences
```sql
-- Check your notification preferences (replace YOUR_USER_ID)
SELECT * FROM user_notification_preferences WHERE user_id = 'YOUR_USER_ID';

-- If no row exists, create default preferences:
INSERT INTO user_notification_preferences (user_id) VALUES ('YOUR_USER_ID');
```

## Step 5: Test Order Creation
```sql
-- Get real user IDs and listing IDs
SELECT id as user_id, email FROM auth.users LIMIT 3;
SELECT id as listing_id, title, user_id as owner_id FROM listings WHERE status = 'active' LIMIT 3;

-- Create a test order (replace UUIDs with real values)
-- Make sure buyer_id ≠ seller_id
INSERT INTO orders (
  listing_id,
  buyer_id, 
  seller_id,
  price_cents,
  payment_method,
  order_status,
  payment_status
) VALUES (
  'REAL_LISTING_ID',
  'REAL_BUYER_ID',
  'REAL_SELLER_ID', 
  1000,
  'card',
  'placed',
  'succeeded'
);

-- Check if notification was created for seller
SELECT * FROM notifications WHERE type = 'order_placed' ORDER BY created_at DESC LIMIT 1;
```

## Step 6: Check Push Token (In-App)
In your iOS app, check if push token is registered:
- Go to Profile > Settings > Notifications
- Should show notification permissions and preferences

## Step 7: Check Edge Function
```bash
# Test the notification queue processor
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

## Common Issues:

1. **No triggers created** → Run the SQL migration files
2. **No notifications in database** → Triggers not firing, check step 5  
3. **Notifications created but not showing in app** → Check AppConfig.enableNotifications
4. **No push notifications** → Check push token registration and edge function
5. **Wrong user IDs** → Make sure buyer_id ≠ seller_id in orders

## What to tell me:
1. Which step fails?
2. What does the notification table show after step 3?
3. What users/listings do you have in your database?

Let me know the results of each step and I'll help identify the exact issue!
