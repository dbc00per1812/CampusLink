# Push Notification Quick Fix Guide

## Why you're not getting push notifications (most likely causes):

### 1. Push Token Not Registered (Most Common)
**Problem:** Your device hasn't registered for push notifications.

**How to check:** Run `check_push_token_status.sql` and look for your user - is `push_token` NULL?

**Fix:** In your iOS app:
1. Go to Settings > CampusLink > Notifications
2. Enable "Allow Notifications"  
3. Or go to iPhone Settings > Notifications > CampusLink and enable notifications
4. Restart the app - it should register a push token

### 2. Edge Function Not Deployed
**Problem:** The push notification processor isn't running.

**How to check:** Look at your Supabase Edge Functions dashboard.

**Fix:** Deploy the processor:
```bash
cd supabase
supabase functions deploy process-notification-queue
```

### 3. APNS Credentials Missing
**Problem:** Apple Push Notification credentials not set up.

**How to check:** Check Supabase Edge Functions environment variables.

**Fix:** In Supabase Dashboard > Edge Functions > process-notification-queue, set:
- `APPLE_TEAM_ID` = Your Apple Developer Team ID
- `APPLE_KEY_ID` = Your APNs Key ID
- `APPLE_PRIVATE_KEY` = Your APNs private key (base64 encoded)
- `BUNDLE_ID` = com.campus.CampusLink (or your actual bundle ID)

### 4. No Cron Job Scheduled
**Problem:** The push notification queue processor isn't being called regularly.

**Fix:** In Supabase SQL Editor, run:
```sql
SELECT cron.schedule(
  'process-push-notifications',
  '* * * * *', -- Every minute
  $$
  SELECT net.http_post(
    url := 'https://YOUR_PROJECT_ID.supabase.co/functions/v1/process-notification-queue',
    headers := jsonb_build_object(
      'Authorization', 'Bearer ' || 'YOUR_SERVICE_ROLE_KEY',
      'Content-Type', 'application/json'
    ),
    body := '{}'::jsonb
  );
  $$
);
```

## Quick Test Steps:

### Step 1: Check Your Push Token
1. Run `check_push_token_status.sql` (replace YOUR_EMAIL with your email)
2. If `push_token` is NULL → Fix notification permissions in iOS
3. If `push_token` exists → Continue to Step 2

### Step 2: Test Database Notifications
1. Run `simple_notification_test.sql` to create a test order
2. Check if notification appears in the `notifications` table
3. If no notification → Database triggers not working
4. If notification exists → Continue to Step 3

### Step 3: Test Push Queue
1. Check if entry was added to `push_notification_queue`
2. If no queue entry → Triggers not queuing push notifications
3. If queue entry exists but `processed = false` → Edge function issue

### Step 4: Manual Edge Function Test
```bash
curl -X POST https://YOUR_PROJECT.supabase.co/functions/v1/process-notification-queue \
  -H "Authorization: Bearer YOUR_SERVICE_ROLE_KEY" \
  -H "Content-Type: application/json" \
  -d '{}'
```

If this returns errors, the edge function has issues with APNS credentials.

## Most Likely Solutions:

1. **90% of cases:** Enable notifications in iOS Settings > CampusLink
2. **8% of cases:** Deploy the edge function and set up cron job
3. **2% of cases:** APNS credentials not configured properly

Try step 1 first - that fixes most issues!
