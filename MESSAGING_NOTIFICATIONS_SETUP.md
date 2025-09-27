# 🚀 Messaging Notifications Setup Guide

## Overview
This guide sets up automatic push notifications when users send messages to each other.

## Architecture
1. **Message sent** → Trigger fires → Notification created in database
2. **Queue processor** → Runs every minute → Sends push notifications
3. **No hardcoded keys** → All credentials stored in Supabase secrets

## Setup Steps

### Step 1: Apply Database Changes
Run this in Supabase SQL Editor:
```sql
-- Copy contents from: supabase/sql/fix_messaging_notifications_complete.sql
```

### Step 2: Deploy Queue Processor
```bash
cd /Users/eileenmurphy/CampusLink
supabase functions deploy process-push-queue
```

### Step 3: Set Up Scheduled Processing

#### Option A: Manual Trigger (Recommended for Testing)
Test the queue processor manually:
```bash
curl -X POST "https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

#### Option B: External Cron Service (Recommended for Production)
Use a service like:
- **Render Cron Jobs**: https://render.com/docs/cronjobs
- **Vercel Cron**: https://vercel.com/docs/cron-jobs
- **GitHub Actions**: Schedule a workflow to call your function

Example with GitHub Actions:
```yaml
name: Process Push Notifications
on:
  schedule:
    - cron: '* * * * *'  # Every minute
jobs:
  process:
    runs-on: ubuntu-latest
    steps:
      - name: Call Supabase Function
        run: |
          curl -X POST "https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue" \
            -H "Authorization: Bearer ${{ secrets.SUPABASE_ANON_KEY }}" \
            -H "Content-Type: application/json"
```

#### Option C: Database Cron (If pg_cron is available)
```sql
-- First set the service role key (one time only)
ALTER DATABASE postgres SET "app.settings.service_role_key" = 'YOUR_SERVICE_ROLE_KEY_HERE';

-- Then run the cron setup
-- Copy contents from: supabase/sql/setup_push_notification_cron.sql
```

### Step 4: Test the Complete System

1. **Send a test message**:
```sql
SELECT test_complete_messaging_flow(
  'fa4c2be3-3d26-4777-a8b5-b030d4d7b4af',  -- conversation_id
  'd4c8cd57-c182-4eed-a961-b24651061676',   -- sender_id (Darragh)
  'Test message - should trigger push notification to Leo!'
);
```

2. **Check if notification was created**:
```sql
SELECT * FROM notifications 
WHERE type = 'new_message' 
ORDER BY created_at DESC 
LIMIT 5;
```

3. **Check pending push queue**:
```sql
SELECT * FROM pending_push_notifications;
```

4. **Manually trigger processor** (if not using cron):
```bash
curl -X POST "https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue" \
  -H "Authorization: Bearer YOUR_ANON_KEY" \
  -H "Content-Type: application/json"
```

5. **Verify push was sent**:
```sql
SELECT id, user_id, title, body, is_delivered, delivered_at
FROM notifications 
WHERE type = 'new_message' 
  AND is_delivered = true
ORDER BY delivered_at DESC 
LIMIT 5;
```

## Troubleshooting

### No notifications created
- Check if trigger exists: `SELECT * FROM get_messaging_notification_status();`
- Check trigger logs: `SELECT * FROM trigger_debug_log ORDER BY created_at DESC LIMIT 5;`

### Notifications created but not delivered
- Check user has push token: `SELECT * FROM pending_push_notifications;`
- Manually run processor and check logs
- Verify APNs environment (sandbox vs production)

### Push sent but not received on device
- Check device notification settings
- Verify app is closed/background
- Check APNs environment matches app build

## Security Notes
- Service role key is only stored in Supabase secrets
- Never hardcode keys in code or SQL files
- Edge functions access keys via environment variables
- Database uses secure configuration parameters

## Production Recommendations
1. Use external cron service for reliability
2. Monitor queue size to ensure timely delivery
3. Add error tracking and alerting
4. Consider batching for high volume
5. Implement retry logic for failed pushes
