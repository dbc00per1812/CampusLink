# 🚀 Deploy Archive on Offer Accept - Quick Start

## What This Fixes

**Problem**: Listings stay visible in marketplace after offer accepted  
**Solution**: Automatically archive listings the moment an offer is accepted

## 3-Minute Deployment

### Step 1: Open Supabase
1. Go to [https://supabase.com/dashboard](https://supabase.com/dashboard)
2. Select your CampusLink project
3. Click **SQL Editor** in left sidebar
4. Click **New Query**

### Step 2: Copy & Paste
1. Open the file: `archive_listing_on_offer_accept.sql`
2. Copy **ALL** contents (Cmd+A, Cmd+C)
3. Paste into Supabase SQL Editor
4. Click **RUN** (or press Cmd+Enter)

### Step 3: Verify
Paste and run this:
```sql
SELECT trigger_name FROM information_schema.triggers 
WHERE trigger_name = 'archive_listing_after_offer_accept';
```

✅ See 1 row? **Success!** You're done.

## Test It

### Quick Test in Supabase
```sql
-- Find a pending offer
SELECT id FROM offers WHERE status = 'pending' LIMIT 1;

-- Accept it (replace YOUR_OFFER_ID)
UPDATE offers SET status = 'accepted' WHERE id = 'YOUR_OFFER_ID';

-- Check logs - you should see:
-- 🎯 Offer accepted!
-- ✅ Listing archived
```

### Real Test in App
1. Create listing
2. Make offer from different account
3. Accept offer
4. **Listing should disappear from marketplace immediately** ✅

## What Happens Now

```
Before:
Offer accepted → Listing still visible ❌

After:
Offer accepted → Listing IMMEDIATELY archived ✅
                → Hidden from marketplace ✅
                → No duplicate sales ✅
```

## That's It!

The trigger is now active and will automatically archive listings when offers are accepted.

**No app changes needed** - this is pure database logic.

---

**Need more details?** See `ARCHIVE_ON_ACCEPT_SUMMARY.md`  
**Want to test?** See `TEST_ARCHIVE_ON_OFFER.sql`  
**Full deployment guide?** See `DEPLOY_ARCHIVE_ON_OFFER.md`

Darragh

