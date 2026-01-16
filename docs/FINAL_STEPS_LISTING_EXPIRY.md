# Final Steps: Listing Expiry System Setup

## ✅ What's Been Done

1. ✅ Created edge function: `process-expired-listings`
2. ✅ **DEPLOYED** edge function to Supabase
3. ✅ Created SQL setup files
4. ✅ Created comprehensive documentation

**Edge Function URL**: 
https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/functions

---

## 🔴 What You Need to Do Now (2 minutes)

### Step 1: Set Up the Cron Job

1. **Open Supabase SQL Editor**:
   - Go to: https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/sql/new

2. **Copy and paste this SQL** (all at once):

```sql
-- Enable required extensions
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Schedule the cron job (every 30 minutes)
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

-- Verify it was created
SELECT 
    jobid,
    jobname,
    schedule,
    active
FROM cron.job 
WHERE jobname = 'process-expired-listings';
```

3. **Click "Run"**

4. **Expected result**: You should see a table with one row showing the cron job:
   ```
   jobid | jobname                  | schedule     | active
   ------|--------------------------|--------------|--------
   X     | process-expired-listings | */30 * * * * | t
   ```

---

### Step 2: Test It Works

**Option A: Wait 30 minutes** and check if any expired listings get archived automatically.

**Option B: Test immediately** by running this in SQL Editor:

```sql
-- Manually trigger the edge function
SELECT net.http_post(
    url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw"}'::jsonb,
    body := '{}'::jsonb
);
```

Then check the edge function logs:
- Go to: https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/functions
- Click on `process-expired-listings`
- Click "Logs" tab
- You should see a successful run

---

### Step 3: Verify Everything Works

Run this query to check for expired listings that haven't been archived:

```sql
SELECT 
    id,
    title,
    category,
    intent,
    expires_at,
    archived,
    EXTRACT(EPOCH FROM (NOW() - expires_at)) / 3600 as hours_overdue
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false
  AND is_sold = false
ORDER BY expires_at ASC;
```

**Expected result**: This should return 0 rows (or very few if recently created).

---

## 📊 How to Monitor

### Check System Health (Daily/Weekly)

```sql
-- Should be 0 or very low
SELECT COUNT(*) as expired_not_archived
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false
  AND is_sold = false;
```

### Check Recent Cron Runs

```sql
SELECT 
    runid,
    status,
    start_time,
    end_time
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'process-expired-listings')
ORDER BY start_time DESC 
LIMIT 10;
```

---

## 🎯 What This Fixes

### Before
- ❌ Expired tickets only archived when iOS users had app open
- ❌ Mobile app users couldn't trigger archiving
- ❌ Expired listings stayed "active" indefinitely

### After
- ✅ Backend cron job runs every 30 minutes (24/7)
- ✅ Works for both iOS and Mobile users
- ✅ Automatic archiving with push notifications
- ✅ No dependency on any app being open

---

## 🚨 If Something Goes Wrong

### Disable the Cron Job

```sql
SELECT cron.unschedule('process-expired-listings');
```

### Re-enable It Later

Just run the setup SQL from Step 1 again.

---

## 📁 Related Files

- **Edge Function**: `/supabase/functions/process-expired-listings/index.ts`
- **Setup SQL**: `/docs/sql/auto_archive_expired_listings.sql`
- **Diagnostic SQL**: `/docs/sql/check_expired_listings.sql`
- **Full Documentation**: `/docs/POST_EXPIRY_SYSTEM.md`
- **This Guide**: `/docs/FINAL_STEPS_LISTING_EXPIRY.md`
- **Deployment Guide**: `/DEPLOY_LISTING_EXPIRY.md`

---

**Status**: ✅ Edge function deployed, ⏳ Waiting for cron job setup  
**Next**: Run the SQL from Step 1 above (takes 1 minute)

