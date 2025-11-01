# PUSH NOTIFICATION RECOVERY PLAN
## Created: 2025-10-16

## What Happened
Push notifications were working 8 hours ago. Then someone ran SQL that broke the system.

## The Push Notification Architecture

### Complete Flow (How It Should Work)
```
1. Message sent → INSERT into messages
2. Trigger creates notification → INSERT into notifications  ✅ WORKING
3. Trigger on notifications → INSERT into push_notification_queue  ❌ BROKEN
4. Cron job (every minute) → Calls process-push-queue edge function
5. Edge function → Reads queue, sends to APNs, marks processed
6. User gets push on device
```

### What's Broken
Step 3: The trigger that inserts into `push_notification_queue` was deleted.

## Diagnostic Steps

### Step 1: Run the Diagnostic
Run the file `PUSH_DIAGNOSTIC_FULL.sql` in Supabase SQL Editor.

This will show you:
- Current state of push_notification_queue table
- All triggers on notifications table
- All notification-related functions
- Users with push tokens
- Recent notifications
- Cron jobs

### Step 2: Look for These Key Issues

**CRITICAL CHECK 1**: Is there a trigger on notifications table that calls `queue_push_notification()`?
- If NO → This is the main problem
- If YES → Trigger exists, check if it's working

**CRITICAL CHECK 2**: Do you see entries in push_notification_queue?
- If NO → Trigger isn't firing
- If YES → Check if they're being processed

**CRITICAL CHECK 3**: Are entries being marked as processed?
- If NO → Either cron isn't running OR edge function doesn't exist/is broken
- If YES → Everything is working except maybe APNs credentials

**CRITICAL CHECK 4**: Does the `process-push-queue` edge function exist?
- Check in Supabase Dashboard → Edge Functions
- If NO → We need to create it
- If YES → Check its logs for errors

## Recovery Plan

### Fix 1: Restore the Missing Trigger (MOST LIKELY FIX)
Run `FINAL_FIX_PUSH.sql` - this restores the trigger.

### Fix 2: Verify Edge Function Exists
The edge function `process-push-queue` must exist. If it doesn't, we need to create it.

### Fix 3: Verify Cron Job is Running
Either Vercel cron OR Supabase pg_cron needs to call the edge function every minute.

## Quick Test After Fix

```sql
-- 1. Send a message in your app

-- 2. Check if it made it to the queue:
SELECT * FROM push_notification_queue ORDER BY created_at DESC LIMIT 5;

-- 3. Wait 1-2 minutes, check if processed:
SELECT * FROM push_notification_queue WHERE processed = true ORDER BY processed_at DESC LIMIT 5;
```

## What We Know Works
- ✅ In-app notifications (notifications table)
- ✅ Device token collection (user_notification_preferences)
- ✅ APNs credentials (was working 8 hours ago)
- ✅ Message triggers

## What's Definitely Broken
- ❌ Trigger from notifications → push_notification_queue

## What Might Be Broken
- ❓ Edge function (might not exist in codebase)
- ❓ Cron job (might have stopped)

---

**NEXT ACTION**: Run `PUSH_DIAGNOSTIC_FULL.sql` and share the results.



