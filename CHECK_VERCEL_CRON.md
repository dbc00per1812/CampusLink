# WHY YOUR VERCEL CRON ISN'T WORKING

## The Problem

Your Vercel cron job (`api/process-notifications.js`) hasn't run in 20 days. That's why notifications are queuing but not being sent.

## Quick Fix Options

### Option A: Use Supabase Cron Instead (Recommended)

Supabase has built-in cron jobs using pg_cron. Create this in Supabase SQL Editor:

```sql
-- Enable pg_cron extension
CREATE EXTENSION IF NOT EXISTS pg_cron;

-- Create a cron job that runs every minute
SELECT cron.schedule(
    'process-push-notifications',
    '* * * * *', -- every minute
    $$
    SELECT
      net.http_post(
          url:='https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-push-queue',
          headers:='{"Content-Type": "application/json", "Authorization": "Bearer YOUR_SERVICE_ROLE_KEY"}'::jsonb,
          body:='{}'::jsonb
      ) as request_id;
    $$
);

-- Check if it's scheduled
SELECT * FROM cron.job;
```

Replace `YOUR_SERVICE_ROLE_KEY` with your actual service role key.

### Option B: Fix Vercel Cron

1. Go to Vercel Dashboard → Your Project
2. Settings → Cron Jobs
3. Check if `api/process-notifications.js` is listed and enabled
4. Settings → Environment Variables
5. Verify these exist:
   - `CRON_SECRET` (can be any random string)
   - `SUPABASE_SERVICE_ROLE_KEY` (from Supabase dashboard)
6. Check deployment logs for cron errors

### Option C: Manual Trigger (Temporary)

Until you fix the cron, you can manually trigger processing:

**In Terminal:**
```bash
export SUPABASE_SERVICE_ROLE_KEY='your-key-here'
./trigger_push_now.sh
```

**Or in Supabase Dashboard:**
Edge Functions → process-push-queue → Invoke Function

---

## Recommended: Use Supabase Cron

It's more reliable and you don't need to manage Vercel cron jobs. Just run the SQL above and you're done.


