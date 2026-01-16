# Deployment Guide: Listing Expiry System

## What This Fixes

🔴 **Current Problem**: 
- Expired tickets and seek posts only get archived when iOS users have the app open
- Mobile app users don't trigger any archiving
- Listings can stay "active" long after they've expired

✅ **Solution**:
- Backend cron job runs every 30 minutes (independent of clients)
- Works for both iOS and Mobile users
- Automatic archiving + push notifications

---

## Pre-Deployment Checklist

- [ ] Supabase CLI installed and authenticated
- [ ] Access to Supabase SQL Editor
- [ ] `pg_cron` extension enabled in Supabase
- [ ] `pg_net` extension enabled in Supabase
- [ ] Edge function environment variables configured

---

## Step 1: Deploy Edge Function

### Option A: Using Supabase CLI (Recommended)

```bash
# Navigate to project root
cd /Users/eileenmurphy/CampusLink

# Make sure you're logged in
supabase login

# Link to your project (if not already linked)
supabase link --project-ref vnmzijluyctlufnzxast

# Deploy the function
supabase functions deploy process-expired-listings
```

### Option B: Manual Deployment (Supabase Dashboard)

1. Go to: https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/functions
2. Click "New Function"
3. Name: `process-expired-listings`
4. Copy contents from: `supabase/functions/process-expired-listings/index.ts`
5. Click "Deploy"

---

## Step 2: Set Up Cron Job

1. Open Supabase SQL Editor:
   - https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/sql/new

2. Run the setup SQL:

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
```

3. Verify it was created:

```sql
SELECT jobid, jobname, schedule, active
FROM cron.job 
WHERE jobname = 'process-expired-listings';
```

Expected output:
```
jobid | jobname                   | schedule      | active
------|---------------------------|---------------|--------
1     | process-expired-listings  | */30 * * * *  | true
```

---

## Step 3: Test the System

### Test 1: Check for Existing Expired Listings

```sql
-- Find expired listings that should be archived
SELECT 
    id, title, category, expires_at, archived,
    EXTRACT(EPOCH FROM (NOW() - expires_at)) / 3600 as hours_overdue
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false
  AND is_sold = false
ORDER BY expires_at ASC;
```

### Test 2: Create Test Data

```sql
-- Create a test expired ticket
INSERT INTO listings (
    user_id,
    title,
    description,
    category,
    price_cents,
    listing_type,
    intent,
    expires_at,
    archived,
    is_sold,
    status
) VALUES (
    (SELECT id FROM users LIMIT 1),
    'TEST: Expired Concert Ticket',
    'This should be auto-archived',
    'Tickets',
    2500,
    'product',
    'offer',
    NOW() - INTERVAL '2 hours',  -- Expired 2 hours ago
    false,
    false,
    'active'
)
RETURNING id, title, expires_at;
```

### Test 3: Manually Trigger Edge Function

```bash
# Using curl
curl -X POST https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings \
  -H "Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw" \
  -H "Content-Type: application/json"
```

Or using SQL:

```sql
SELECT net.http_post(
    url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw"}'::jsonb,
    body := '{}'::jsonb
);
```

### Test 4: Verify Test Listing Was Archived

```sql
SELECT id, title, category, archived, expires_at
FROM listings
WHERE title LIKE '%TEST:%'
ORDER BY created_at DESC;
```

Expected: `archived` should be `true`

---

## Step 4: Monitor and Verify

### Check Edge Function Logs

1. Go to: https://supabase.com/dashboard/project/vnmzijluyctlufnzxast/functions
2. Click on `process-expired-listings`
3. Click "Logs" tab
4. Look for successful runs

### Check Cron Job Execution History

```sql
SELECT 
    runid,
    status,
    start_time,
    end_time,
    EXTRACT(EPOCH FROM (end_time - start_time)) as duration_seconds
FROM cron.job_run_details 
WHERE jobid = (SELECT jobid FROM cron.job WHERE jobname = 'process-expired-listings')
ORDER BY start_time DESC 
LIMIT 10;
```

### Monitor System Health

```sql
-- Check expired listings count (should be 0 or low)
SELECT COUNT(*) as expired_not_archived
FROM listings 
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false
  AND is_sold = false;
```

---

## Rollback Instructions

### Disable Cron Job

```sql
SELECT cron.unschedule('process-expired-listings');
```

### Delete Edge Function

```bash
supabase functions delete process-expired-listings
```

Or delete manually from Supabase Dashboard.

---

## Troubleshooting

### Cron Job Not Running

1. Check if extensions are enabled:
```sql
SELECT * FROM pg_extension WHERE extname IN ('pg_cron', 'pg_net');
```

2. Check cron job status:
```sql
SELECT * FROM cron.job WHERE jobname = 'process-expired-listings';
```

3. Check for errors in recent runs:
```sql
SELECT * FROM cron.job_run_details 
WHERE status = 'failed'
ORDER BY start_time DESC;
```

### Edge Function Errors

1. Check logs in Supabase Dashboard
2. Common issues:
   - Missing environment variables
   - Network permissions
   - Database permissions

### Listings Not Being Archived

1. Verify edge function is deployed:
```bash
supabase functions list
```

2. Test edge function manually (see Test 3 above)

3. Check if listings actually have `expires_at` set:
```sql
SELECT COUNT(*) FROM listings WHERE expires_at IS NOT NULL;
```

---

## Success Criteria

✅ Cron job appears in `cron.job` table  
✅ Edge function appears in Supabase Functions dashboard  
✅ Test expired listing gets archived within 30 minutes  
✅ Push notification sent to listing owner  
✅ Cron job runs without errors every 30 minutes  

---

## Next Steps After Deployment

1. Monitor for first 24 hours
2. Check that expired tickets are being archived
3. Verify users receive notifications
4. Optional: Create admin dashboard to view expiry stats

---

**Last Updated**: January 3, 2026  
**Deployed**: ❌ Not yet deployed  
**Status**: Ready for deployment

