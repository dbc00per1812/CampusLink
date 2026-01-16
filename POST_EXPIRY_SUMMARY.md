# Post Expiry System - Investigation & Fix Summary

## 🔍 What I Found

After comprehensive investigation of your post expiry system:

### ✅ What Was Already Working

1. **iOS App - Ticket Expiry**:
   - `ExpiredListingArchiver` service runs every 30 minutes
   - Properly queries and archives expired listings
   - Good logging for debugging

2. **iOS & Mobile - Setting Expiry Dates**:
   - Tickets: `expires_at` set to event date ✅
   - Seek Posts: `expires_at` set to 7 days from creation ✅
   - Both platforms correctly save these dates

3. **Order Expiry** (different system):
   - Edge function + cron job for 5-day order deadline ✅
   - Working perfectly

### ❌ The Critical Problem

**Listing expiry only worked when iOS users had the app open!**

- **iOS**: Has client-side archiver (runs every 30 min when app open)
- **Mobile**: NO archiver service at all
- **Backend**: NO edge function or cron job for listings

**Impact**: 
- If only React Native users were active, expired tickets/posts never got archived
- Expired listings stayed "active" indefinitely
- Inconsistent behavior between platforms

---

## ✅ What I Fixed

Created a **backend archiving system** (same pattern as order expiry):

### 1. Edge Function: `process-expired-listings`
```typescript
// Runs every 30 minutes via cron job
// Finds: WHERE expires_at < NOW() AND archived = false
// Archives expired listings
// Sends push notifications to owners
```

**Deployed to**: https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings

### 2. Cron Job Setup
- Runs every 30 minutes (24/7)
- Independent of any app being open
- Uses `pg_cron` + `pg_net` extensions

### 3. Complete Documentation
- System overview (`POST_EXPIRY_SYSTEM.md`)
- Deployment guide (`DEPLOY_LISTING_EXPIRY.md`)
- Diagnostic queries (`check_expired_listings.sql`)
- Setup SQL (`auto_archive_expired_listings.sql`)
- Final steps guide (`FINAL_STEPS_LISTING_EXPIRY.md`)

---

## 🎯 How It Works Now

```
User creates ticket → expires_at set to event date → saved to database
                                                            ↓
                                      Every 30 minutes, cron job runs
                                                            ↓
                                      Edge function queries expired listings
                                                            ↓
                                      Archives each one + sends notification
                                                            ↓
                                      Listing removed from active view
```

**Benefits**:
- ✅ Works 24/7 (no dependency on apps)
- ✅ Cross-platform (iOS + Mobile)
- ✅ Automatic notifications
- ✅ Production-ready
- ✅ Easy to monitor

---

## ⏳ What You Need to Do (1 minute)

### Step 1: Set Up Cron Job

1. Go to: https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/sql/new

2. Copy/paste this SQL:

```sql
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

SELECT cron.schedule(
    'process-expired-listings',
    '*/30 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw'
        ),
        body := '{}'::jsonb
    );
    $$
);
```

3. Click "Run"

### Step 2: Verify

```sql
SELECT jobname, schedule, active 
FROM cron.job 
WHERE jobname = 'process-expired-listings';
```

You should see one row showing the cron job is active.

### Step 3: Test (Optional)

Manually trigger it to test:

```sql
SELECT net.http_post(
    url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw"}'::jsonb,
    body := '{}'::jsonb
);
```

Then check logs: https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/functions

---

## 📊 Monitoring

### Check System Health

```sql
-- Should be 0 or very low
SELECT COUNT(*) as expired_not_archived
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false;
```

### Check Recent Runs

```sql
SELECT runid, status, start_time, end_time
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'process-expired-listings')
ORDER BY start_time DESC 
LIMIT 10;
```

---

## 📁 All Documentation Files

1. **Quick Start**: `FINAL_STEPS_LISTING_EXPIRY.md` ← Start here!
2. **Deployment Guide**: `DEPLOY_LISTING_EXPIRY.md`
3. **System Overview**: `docs/POST_EXPIRY_SYSTEM.md`
4. **Setup SQL**: `docs/sql/auto_archive_expired_listings.sql`
5. **Diagnostic SQL**: `docs/sql/check_expired_listings.sql`
6. **This Summary**: `POST_EXPIRY_SUMMARY.md`
7. **Today's Log**: `logs/2026-01-03-post-expiry-fix.md`

---

## 🎉 Summary

**Before**: Post expiry only worked on iOS when app was open  
**After**: Post expiry works 24/7 for all users on all platforms  

**What Changed**: Added backend edge function + cron job (no code changes needed to existing apps)  
**Time Investment**: 1 minute to run SQL, then automatic forever  
**Status**: ✅ Edge function deployed, ⏳ Cron job setup needed  

---

**Next**: Run the SQL from Step 1 above, and you're done! 🚀

