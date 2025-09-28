# Notification System Setup Guide

## Overview
This guide explains how to set up and test the comprehensive notification system for CampusLink marketplace actions.

## Notifications Implemented

### Order Notifications
1. **New Order** - Seller receives notification when buyer places an order
2. **Order Confirmed** - Buyer receives notification when seller confirms order
3. **Order Delivered** - Buyer receives notification when order is marked delivered
4. **Order Cancelled** - Both parties receive notification if order is cancelled

### Offer Notifications
1. **New Offer** - Seeker receives notification when someone makes an offer on their seek post
2. **Offer Accepted** - Offer maker receives notification when their offer is accepted
3. **Offer Declined** - Offer maker receives notification when their offer is declined

## Setup Steps

### 1. Run Database Migrations
Execute these SQL files in order on your Supabase database:

```bash
# 1. Set up the complete notification infrastructure
psql -h YOUR_DB_HOST -U postgres -d postgres -f setup_notifications_complete.sql

# 2. Create order notification triggers
psql -h YOUR_DB_HOST -U postgres -d postgres -f create_order_notifications.sql

# 3. Create offer notification triggers
psql -h YOUR_DB_HOST -U postgres -d postgres -f create_offer_notifications.sql
```

### 2. Deploy Edge Function
Deploy the notification queue processor:

```bash
# From the project root
cd supabase
supabase functions deploy process-notification-queue
```

### 3. Set Environment Variables
In your Supabase dashboard, set these environment variables for the edge function:

```
APNS_HOST=api.push.apple.com
BUNDLE_ID=com.campus.CampusLink
APPLE_TEAM_ID=your_team_id
APPLE_KEY_ID=your_key_id
APPLE_PRIVATE_KEY=your_base64_encoded_private_key
```

### 4. Schedule the Queue Processor
Set up a cron job to run the notification processor every minute:

```sql
-- In Supabase SQL editor
SELECT cron.schedule(
  'process-push-notifications',
  '* * * * *', -- Every minute
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('supabase.service_role_key'),
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

## Testing the Notifications

### Test Order Notifications

1. **Test New Order Notification (Seller)**
```sql
-- Create a test order
INSERT INTO orders (
  buyer_id, 
  seller_id, 
  price_cents, 
  payment_method, 
  order_status,
  payment_status
) VALUES (
  'buyer-uuid-here',
  'seller-uuid-here',
  1000,
  'card',
  'placed',
  'succeeded'
);

-- Check notifications table
SELECT * FROM notifications 
WHERE type = 'order_placed' 
ORDER BY created_at DESC 
LIMIT 1;

-- Check push queue
SELECT * FROM push_notification_queue 
WHERE processed = false 
ORDER BY created_at DESC 
LIMIT 1;
```

2. **Test Order Confirmation Notification (Buyer)**
```sql
-- Update order status
UPDATE orders 
SET order_status = 'seller_confirmed',
    seller_confirmed_at = now()
WHERE id = 'order-id-here';

-- Check notification was created
SELECT * FROM notifications 
WHERE type = 'order_confirmed' 
ORDER BY created_at DESC 
LIMIT 1;
```

### Test Offer Notifications

1. **Test New Offer Notification (Seeker)**
```sql
-- Create a test offer
INSERT INTO offers (
  seek_listing_id,
  seller_id,
  seeker_id,
  price_cents,
  status
) VALUES (
  'seek-listing-uuid',
  'seller-uuid',
  'seeker-uuid',
  2500,
  'pending'
);

-- Check notification
SELECT * FROM notifications 
WHERE type = 'listing_interest' 
ORDER BY created_at DESC 
LIMIT 1;
```

2. **Test Offer Acceptance Notification**
```sql
-- Update offer status
UPDATE offers 
SET status = 'accepted',
    updated_at = now()
WHERE id = 'offer-id-here';

-- Check notification
SELECT * FROM notifications 
WHERE type = 'marketplace_activity' 
ORDER BY created_at DESC 
LIMIT 1;
```

## Verifying Push Notifications

### 1. Check User Has Push Token
```sql
SELECT user_id, push_token, push_enabled, order_notifications, marketplace_notifications
FROM user_notification_preferences
WHERE user_id = 'user-uuid-here';
```

### 2. Manually Process Queue
```bash
# Trigger the edge function manually
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

### 3. Check Processing Results
```sql
-- See processed notifications
SELECT * FROM push_notification_queue
WHERE processed = true
ORDER BY processed_at DESC
LIMIT 10;

-- See any errors
SELECT * FROM push_notification_queue
WHERE error IS NOT NULL
ORDER BY created_at DESC;
```

## Debugging Common Issues

### No Notifications Created
1. Check if triggers are created:
```sql
SELECT tgname FROM pg_trigger WHERE tgname LIKE '%notification%';
```

2. Check if user has preferences:
```sql
SELECT * FROM user_notification_preferences WHERE user_id = 'user-id';
```

### Push Notifications Not Sent
1. Verify push token is saved:
```sql
SELECT push_token FROM user_notification_preferences WHERE user_id = 'user-id';
```

2. Check edge function logs in Supabase dashboard

3. Verify APNS credentials are set correctly

### Notifications Not Showing in App
1. Ensure NotificationService is fetching:
```swift
// In your app
await NotificationService.shared.fetchNotifications()
```

2. Check if feature flag is enabled:
```swift
print(AppConfig.enableNotifications) // Should be true
```

## User Preference Management
Users can control their notification preferences through the app. The preferences include:
- Push notifications on/off
- Order notifications
- Message notifications
- Payment notifications
- Rating notifications
- Marketplace notifications

These are stored in the `user_notification_preferences` table and respected by all notification triggers.
