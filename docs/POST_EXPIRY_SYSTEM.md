# Post Expiry System - Complete Documentation

## Overview

CampusLink has **two separate expiry systems**:

1. **Listing Expiry** - For tickets and seek posts
2. **Order Expiry** - For transactions that aren't completed in time

---

## 1. Listing Expiry System

### What Gets Expired

- **Tickets**: Expire at the event date (set by seller when creating listing)
- **Seek Posts**: Expire 7 days after creation (customizable)
- **Regular Listings**: Do NOT expire (expires_at = NULL)

### How It Works

#### Frontend (Creating Listings)

**iOS (`TabViews.swift`)**:
```swift
// Determine expiration date based on listing type
var expirationDate: Date? = nil
if selectedIntent == .seek {
    expirationDate = expiresDate  // 7 days from now
} else if selectedCategory == "Tickets" {
    expirationDate = eventDate    // User-selected event date
}
```

**Mobile (`CreateListingScreen.tsx`)**:
```typescript
// Determine expiration date based on listing type
let expirationDate: string | null = null;
if (intent === 'seek') {
  expirationDate = expiresDate.toISOString();  // 7 days from now
} else if (selectedCategory === 'Tickets') {
  expirationDate = eventDate.toISOString();    // User-selected event date
}
```

#### Backend (Archiving Expired Listings)

**Edge Function**: `process-expired-listings`
- Runs every 30 minutes via cron job
- Queries: `WHERE expires_at IS NOT NULL AND expires_at < NOW() AND archived = false`
- Archives expired listings by setting `archived = true`
- Sends push notification to listing owner

**iOS Client-Side Archiver**: `ExpiredListingArchiver.swift`
- Runs every 30 minutes when iOS app is open
- Acts as a backup to the edge function
- Useful for immediate archiving without waiting for cron

**Mobile**: No client-side archiver (relies on backend)

### Database Schema

```sql
-- listings table
expires_at timestamp with time zone  -- NULL for regular listings, set for tickets/seek
archived boolean DEFAULT false       -- true when listing is archived
```

### Setup Instructions

#### 1. Deploy Edge Function

```bash
# From project root
cd supabase/functions/process-expired-listings

# Deploy to Supabase
supabase functions deploy process-expired-listings
```

#### 2. Set Up Cron Job

Run this SQL in Supabase SQL Editor:

```sql
-- Enable extensions
CREATE EXTENSION IF NOT EXISTS pg_net WITH SCHEMA extensions;
CREATE EXTENSION IF NOT EXISTS pg_cron WITH SCHEMA extensions;

-- Schedule cron job (every 30 minutes)
SELECT cron.schedule(
    'process-expired-listings',
    '*/30 * * * *',
    $$
    SELECT net.http_post(
        url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings',
        headers := jsonb_build_object(
            'Content-Type', 'application/json',
            'Authorization', 'Bearer YOUR_ANON_KEY'
        ),
        body := '{}'::jsonb
    );
    $$
);
```

#### 3. Verify Setup

```sql
-- Check cron job is scheduled
SELECT * FROM cron.job WHERE jobname = 'process-expired-listings';

-- Check for expired listings
SELECT id, title, category, expires_at, archived
FROM listings
WHERE expires_at IS NOT NULL
  AND expires_at < NOW()
  AND archived = false;
```

### Testing

#### Manual Test (SQL)

```sql
-- Create a test expired ticket
INSERT INTO listings (
    user_id, title, description, category, 
    price_cents, expires_at, archived
) VALUES (
    'YOUR_USER_ID',
    'Test Expired Ticket',
    'This should be archived',
    'Tickets',
    1000,
    NOW() - INTERVAL '1 hour',  -- Expired 1 hour ago
    false
);

-- Manually trigger the edge function
SELECT net.http_post(
    url := 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings',
    headers := '{"Content-Type": "application/json", "Authorization": "Bearer YOUR_ANON_KEY"}'::jsonb,
    body := '{}'::jsonb
);

-- Verify it was archived
SELECT id, title, archived FROM listings WHERE title = 'Test Expired Ticket';
```

#### iOS Testing

1. Create a ticket with event date in the past
2. Check console logs for:
   ```
   📦 ExpiredListingArchiver: Checking for expired listings
   📦 ExpiredListingArchiver: Found 1 expired listing(s)
   ✅ Archived expired listing: Test Ticket
   ```

#### Mobile Testing

1. Create a ticket with event date in the past
2. Wait 30 minutes for cron job to run (or trigger manually)
3. Refresh listings - expired ticket should be gone

---

## 2. Order Expiry System

### What Gets Expired

- Orders in status: `placed`, `seller_confirmed`, `in_progress`
- That are older than **5 days** from creation

### How It Works

**Edge Function**: `process-expired-orders`
- Runs every hour via cron job
- Finds orders older than 5 days that aren't completed
- Cancels/refunds Stripe payment or refunds wallet
- Sets order status to `cancelled`
- Sends notifications to buyer and seller
- Restores listing availability (`is_sold = false`, `archived = false`)

### Setup Instructions

See: `docs/sql/auto_cancel_expired_orders.sql`

```bash
# Deploy edge function
supabase functions deploy process-expired-orders
```

Then run the SQL to set up the cron job.

---

## Troubleshooting

### Listings Not Being Archived

1. **Check if edge function is deployed**:
   ```bash
   supabase functions list
   ```

2. **Check if cron job is scheduled**:
   ```sql
   SELECT * FROM cron.job WHERE jobname = 'process-expired-listings';
   ```

3. **Check recent cron runs**:
   ```sql
   SELECT * FROM cron.job_run_details 
   WHERE jobname = 'process-expired-listings'
   ORDER BY start_time DESC 
   LIMIT 10;
   ```

4. **Manually trigger edge function**:
   ```bash
   curl -X POST https://vnmzijluyctlufnzxast.supabase.co/functions/v1/process-expired-listings \
     -H "Authorization: Bearer YOUR_ANON_KEY" \
     -H "Content-Type: application/json"
   ```

5. **Check edge function logs**:
   Go to Supabase Dashboard > Edge Functions > process-expired-listings > Logs

### iOS Archiver Not Working

1. Check console logs on app launch - should see:
   ```
   📦 ExpiredListingArchiver: Started auto-archiving
   ```

2. Check if timer is firing every 30 minutes

3. Manually trigger archiving in code (for testing)

### Mobile App Not Seeing Changes

- Mobile app relies on backend archiving only
- Refresh the listings screen to fetch latest data
- Check if backend cron job is running

---

## Summary

✅ **What's Working**:
- iOS client-side archiver
- Backend edge function (once deployed)
- Ticket expiry (event date)
- Seek post expiry (7 days)
- Order expiry (5 days)

✅ **What's Fixed**:
- Mobile app now sets `expires_at` correctly
- Backend handles archiving for all clients
- No dependency on iOS app being open

📋 **Deployment Checklist**:
- [ ] Deploy `process-expired-listings` edge function
- [ ] Run SQL to set up cron job
- [ ] Verify cron job is scheduled
- [ ] Test with an expired listing
- [ ] Monitor edge function logs

---

**Last Updated**: January 3, 2026  
**Status**: Backend solution implemented, ready for deployment

