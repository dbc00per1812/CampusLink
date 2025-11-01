# 🎯 Engagement Notifications - Quick Reference

## 5-Minute Deployment

### Step 1: Deploy
```sql
-- In Supabase SQL Editor, run:
DEPLOY_ENGAGEMENT_NOTIFICATIONS.sql
```

### Step 2: Verify
```sql
-- Check triggers created
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_name IN ('first_sale_milestone_trigger', 'payout_success_trigger');

-- Check functions created  
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE '%send_%' OR routine_name LIKE '%notify_first%' OR routine_name LIKE '%notify_payout%';

-- Check cron jobs
SELECT jobname, active FROM cron.job WHERE jobname LIKE 'send-%';
```

### Step 3: Test Manually
```sql
-- Test each scheduled function
SELECT send_idle_listing_reminders();
SELECT send_rating_reminders();
SELECT send_message_reminders();
SELECT send_campus_activity_digest();

-- Check results
SELECT * FROM notifications WHERE type IN (
  'idle_listing_reminder', 'rating_reminder', 'message_reminder', 
  'marketplace_activity', 'first_sale_milestone', 'payout_completed'
) ORDER BY created_at DESC LIMIT 10;
```

## The Notifications

| # | Name | Frequency | Type | Target |
|---|------|-----------|------|--------|
| 1 | Idle Listing | Weekly | `idle_listing_reminder` | Sellers with stale inventory |
| 2 | Rating Reminder | 1d, 3d, 7d | `rating_reminder` | Post-transaction users |
| 3 | Message Reminder | 24h, then 3d | `message_reminder` | Users with unread messages |
| 4 | Campus Digest | Daily 6pm | `marketplace_activity` | All campus users |
| 5 | First Sale | Real-time | `first_sale_milestone` | First-time sellers |
| 6 | Payout Success | Real-time | `payout_completed` | Sellers receiving payouts |

## Cron Schedule

```
0 */6 * * *   → send-idle-listing-reminders    (Every 6 hours)
0 10 * * *    → send-rating-reminders          (Daily 10am UTC)
0 */6 * * *   → send-message-reminders         (Every 6 hours)
0 18 * * *    → send-campus-activity-digest    (Daily 6pm UTC)
```

## Daily Monitoring

```sql
-- Today's notifications by type
SELECT type, COUNT(*) as count, COUNT(DISTINCT user_id) as users
FROM notifications
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY type
ORDER BY count DESC;

-- Read rates
SELECT type, 
  ROUND(100.0 * SUM(CASE WHEN is_read THEN 1 ELSE 0 END) / COUNT(*), 1) as read_rate
FROM notifications
WHERE created_at > NOW() - INTERVAL '7 days'
GROUP BY type
ORDER BY read_rate DESC;

-- Cron execution history
SELECT jobname, status, start_time
FROM cron.job_run_details
WHERE jobname LIKE 'send-%'
ORDER BY start_time DESC
LIMIT 10;
```

## Troubleshooting

### No notifications being created?
```sql
-- Check if functions exist
SELECT routine_name FROM information_schema.routines 
WHERE routine_name LIKE 'send_%';

-- Check if cron jobs are active
SELECT jobname, active FROM cron.job WHERE jobname LIKE 'send-%';

-- Manually trigger to test
SELECT send_campus_activity_digest();
```

### Duplicates being sent?
```sql
-- Check deduplication logic
SELECT user_id, type, COUNT(*) as dupe_count
FROM notifications
WHERE created_at > NOW() - INTERVAL '24 hours'
GROUP BY user_id, type
HAVING COUNT(*) > 2
ORDER BY dupe_count DESC;
```

### Cron not running?
```sql
-- Check job status
SELECT * FROM cron.job WHERE jobname LIKE 'send-%';

-- Check execution logs
SELECT * FROM cron.job_run_details 
WHERE jobname LIKE 'send-%' 
ORDER BY start_time DESC LIMIT 5;
```

## Quick Disable (Without Deleting)

```sql
-- Pause all cron jobs
SELECT cron.alter_job('send-idle-listing-reminders', job_active := false);
SELECT cron.alter_job('send-rating-reminders', job_active := false);
SELECT cron.alter_job('send-message-reminders', job_active := false);
SELECT cron.alter_job('send-campus-activity-digest', job_active := false);

-- Re-enable later
SELECT cron.alter_job('send-campus-activity-digest', job_active := true);
-- etc.
```

## Key Metrics to Track

📊 **Engagement Metrics:**
- Daily active users (before/after)
- Notification read rates by type
- Time to complete transactions
- Rating completion rate
- Message response time

🎯 **Success Thresholds:**
- Read rate > 30% for engagement notifications
- < 5% duplicate rate
- Cron jobs > 95% success rate
- Zero user complaints about spam

## Files Reference

- **DEPLOY_ENGAGEMENT_NOTIFICATIONS.sql** - Full deployment script
- **TEST_ENGAGEMENT_NOTIFICATIONS.sql** - Comprehensive testing
- **ENGAGEMENT_NOTIFICATIONS_SUMMARY.md** - This file
- **log.md** - Detailed documentation

---

**Status:** ✅ Production Ready | **Risk:** Low | **Deploy Time:** 5 min

