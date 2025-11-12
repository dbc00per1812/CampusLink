# ⚠️ CRITICAL: Database Migration Required

## Issue Found During Testing

**Error Message:**
```
Failed to create offer: Could not find the 'listing_id' column of 'offers' in the schema cache
```

---

## What Happened?

The original migration (`migrate_offers_to_unified.sql`) partially applied:
- ✅ Added `offer_from_user_id` column
- ✅ Added `offer_to_user_id` column  
- ✅ Added `parent_offer_id` column
- ✅ Added `listing_type` column
- ❌ **MISSING**: `listing_id` column was NOT created

---

## Why This Broke

The `UnifiedOfferService` tries to insert offers with a `listing_id` field, but the database doesn't have that column yet.

**Current Database Schema:**
```sql
CREATE TABLE offers (
  seek_listing_id uuid NOT NULL,    -- Old field (seek-specific)
  offer_listing_id uuid,             -- Old field (seek-specific)
  -- listing_id is MISSING!
  ...
);
```

**What We Need:**
```sql
CREATE TABLE offers (
  listing_id uuid NOT NULL,          -- NEW unified field
  seek_listing_id uuid,              -- Old field (now optional)
  offer_listing_id uuid,             -- Old field (optional)
  ...
);
```

---

## 🔧 How to Fix

### Step 1: Open Supabase SQL Editor
1. Go to https://supabase.com
2. Select your project
3. Click "SQL Editor" in left sidebar

### Step 2: Run This Migration

**File:** `add_listing_id_to_offers.sql`

```sql
-- Add listing_id column to offers table
ALTER TABLE offers 
ADD COLUMN IF NOT EXISTS listing_id UUID;

-- Populate from existing seek_listing_id
UPDATE offers 
SET listing_id = seek_listing_id 
WHERE listing_id IS NULL;

-- Add foreign key constraint
ALTER TABLE offers
ADD CONSTRAINT offers_listing_id_fkey 
FOREIGN KEY (listing_id) REFERENCES listings(id);

-- Make it NOT NULL
ALTER TABLE offers 
ALTER COLUMN listing_id SET NOT NULL;

-- Make old columns nullable
ALTER TABLE offers 
ALTER COLUMN seek_listing_id DROP NOT NULL;

ALTER TABLE offers 
ALTER COLUMN seeker_id DROP NOT NULL;

ALTER TABLE offers 
ALTER COLUMN seller_id DROP NOT NULL;
```

### Step 3: Click "Run" Button

You should see: **Success. No rows returned**

### Step 4: Verify It Worked

Run this verification query:
```sql
SELECT column_name, data_type, is_nullable 
FROM information_schema.columns 
WHERE table_name = 'offers' 
AND column_name IN ('listing_id', 'seek_listing_id', 'offer_from_user_id', 'offer_to_user_id')
ORDER BY column_name;
```

**Expected Result:**
```
listing_id          | uuid | NO
offer_from_user_id  | uuid | YES
offer_to_user_id    | uuid | YES
seek_listing_id     | uuid | YES
```

---

## After Migration

Once you run the migration:
1. Restart your app
2. Try making an offer again
3. It should work! ✅

---

## Why This Happened

The original `migrate_offers_to_unified.sql` file might have had the `listing_id` changes, but they either:
- Weren't included in the file you ran
- Were in a different part you didn't execute
- Got skipped due to an error

This is a common issue with database migrations - they need to be run completely and in order.

---

## Summary

**Problem:** Missing `listing_id` column in offers table  
**Solution:** Run `add_listing_id_to_offers.sql`  
**Time:** 30 seconds  
**Impact:** After this, offers will work perfectly!

---

**Created:** November 11, 2025  
**Priority:** 🔴 CRITICAL - Blocking all offer functionality

