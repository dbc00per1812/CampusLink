# 🔍 Debug Notifications Step by Step

## The Problem
Notifications still don't work. We need to find exactly where the chain breaks.

## Current Flow (What Should Happen)
1. **App sends message** → Direct INSERT into `messages` table ✅
2. **Database trigger fires** → `notify_new_message()` function executes ❓
3. **Trigger calls edge function** → `send-push-direct` ❓
4. **Push sent to recipient** → APNs delivery ❓
5. **Recipient gets notification** → On device ❓

## Step-by-Step Debugging

### Step 1: Check if Trigger Exists
```sql
-- Run this in Supabase SQL Editor
SELECT * FROM get_messaging_notification_status();
```

**Expected Result:**
- `trigger_exists: true`
- `trigger_function_exists: true`

**If false:** The SQL wasn't applied properly.

### Step 2: Check Recent Messages
```sql
-- Check if messages are being inserted
SELECT 
  id,
  conversation_id,
  sender_id,
  content,
  created_at
FROM messages 
ORDER BY created_at DESC 
LIMIT 5;
```

**Expected Result:** Recent messages from your app.

### Step 3: Check Trigger Execution
```sql
-- Check if trigger fired (debug logs)
SELECT 
  id,
  message_id,
  message_content,
  sender_id,
  conversation_id,
  created_at
FROM trigger_debug_log 
ORDER BY created_at DESC 
LIMIT 5;
```

**Expected Result:** Recent entries when messages were sent.

**If empty:** Trigger is not firing.

### Step 4: Check Notifications Created
```sql
-- Check if notifications were created
SELECT 
  id,
  user_id,
  type,
  title,
  body,
  is_delivered,
  delivery_status,
  created_at
FROM notifications 
WHERE type = 'new_message'
ORDER BY created_at DESC 
LIMIT 5;
```

**Expected Result:** Recent `new_message` notifications.

### Step 5: Test Trigger Manually
```sql
-- Get a real conversation ID
SELECT 
  c.id as conversation_id,
  c.buyer_id,
  c.seller_id,
  b.name as buyer_name,
  s.name as seller_name
FROM conversations c
JOIN users b ON b.id = c.buyer_id
JOIN users s ON s.id = c.seller_id
LIMIT 1;
```

Then test with real IDs:
```sql
-- Replace with actual IDs from above
SELECT test_messaging_notification(
  'conversation_id_here',
  'sender_id_here',
  'Manual test message'
);
```

## Common Issues & Solutions

### Issue 1: Trigger Not Installed
**Symptoms:** `trigger_exists: false`
**Solution:** Apply the SQL file properly in Supabase Dashboard

### Issue 2: Trigger Not Firing
**Symptoms:** `trigger_debug_log` is empty
**Possible Causes:**
- Trigger function has errors
- RLS policies blocking trigger execution
- Conversation structure mismatch

### Issue 3: Edge Function Not Called
**Symptoms:** Trigger fires but no notifications created
**Possible Causes:**
- Edge function URL incorrect
- Service role key not set
- HTTP call failing

### Issue 4: Push Not Delivered
**Symptoms:** Notifications created but `is_delivered: false`
**Possible Causes:**
- APNs environment mismatch
- Invalid push tokens
- Recipient notification settings

## Quick Diagnostic Script

Run this to get a complete picture:

```sql
-- Complete diagnostic
WITH recent_messages AS (
  SELECT COUNT(*) as message_count
  FROM messages 
  WHERE created_at > now() - interval '1 hour'
),
recent_triggers AS (
  SELECT COUNT(*) as trigger_count
  FROM trigger_debug_log 
  WHERE created_at > now() - interval '1 hour'
),
recent_notifications AS (
  SELECT COUNT(*) as notification_count
  FROM notifications 
  WHERE type = 'new_message' 
  AND created_at > now() - interval '1 hour'
)
SELECT 
  rm.message_count,
  rt.trigger_count,
  rn.notification_count,
  CASE 
    WHEN rm.message_count = 0 THEN 'No recent messages'
    WHEN rt.trigger_count = 0 THEN 'Trigger not firing'
    WHEN rn.notification_count = 0 THEN 'Edge function not called'
    ELSE 'Notifications being created - check delivery'
  END as diagnosis
FROM recent_messages rm, recent_triggers rt, recent_notifications rn;
```

## Next Steps Based on Results

### If No Recent Messages
- App is not sending messages properly
- Check app logs and messaging flow

### If Messages But No Triggers
- Trigger not installed or has errors
- Check trigger function syntax

### If Triggers But No Notifications
- Edge function call failing
- Check HTTP request in trigger function

### If Notifications But Not Delivered
- APNs delivery failing
- Check push tokens and environment

Run the diagnostic and let me know what you find!
