# Fix Posts Not Archiving After Sale

## The Problem
**Posts aren't disappearing after being sold** because the database triggers that auto-archive them were never deployed.

## The Solution (3 Simple Steps)

### ✅ Step 1: Deploy Auto-Archive Triggers (2 minutes)

1. **Open Supabase Dashboard** → **SQL Editor**
2. **Copy ALL contents** from this file: `DEPLOY_AUTO_ARCHIVE_FIX.sql`
3. **Paste** into Supabase SQL Editor
4. **Click Run**
5. **Wait for success** - you should see:
   ```
   ✅ TRIGGERS CREATED:
   - update_listing_quantity_after_order
   - restore_listing_quantity_on_order_cancel
   
   ✅ FUNCTIONS CREATED:
   - update_listing_quantity_on_order
   - restore_listing_quantity_on_cancel
   ```

**What this does:**
- ✅ Automatically archives posts when `quantity_available` reaches 0
- ✅ Decrements quantity when items are purchased
- ✅ Restores quantity if orders are cancelled
- ✅ Works for all NEW orders going forward

---

### ✅ Step 2: Fix Old Sold-Out Listings (1 minute)

⚠️ **Important:** The triggers are NOT retroactive! Listings that already sold out won't be archived automatically.

1. **Open Supabase Dashboard** → **SQL Editor**
2. **Run this query** to see which listings should be archived:

```sql
-- Preview which listings need fixing
SELECT 
    id, title, quantity_available, quantity_sold, archived
FROM listings
WHERE quantity_available <= 0 AND archived = false;
```

3. **If you see listings**, run this to archive them:

```sql
-- Archive all sold-out listings
UPDATE listings
SET archived = true
WHERE quantity_available <= 0
  AND archived = false;
```

4. **Verify** it worked:

```sql
-- Check archived listings
SELECT 
    id, title, quantity_available, archived
FROM listings
WHERE quantity_available <= 0;
```

All should show `archived = true` ✅

---

### ✅ Step 3: Test It Works

1. **Create a test listing** with quantity = 1
2. **Purchase it** with another test account
3. **Check if it's archived:**

```sql
SELECT id, title, quantity_available, archived
FROM listings
ORDER BY created_at DESC
LIMIT 5;
```

The purchased listing should show:
- `quantity_available` = 0
- `archived` = true ✅

---

## What Happens After This

### ✅ For New Orders (Automatic)
- Purchase made → Quantity decrements
- Quantity reaches 0 → Post automatically archives
- Archived posts disappear from:
  - ✅ Home feed
  - ✅ Search results
  - ✅ User profiles
  - ✅ Browse by category
- Sellers still see archived posts in "My Listings"

### ✅ For Order Cancellations (Automatic)
- Order cancelled → Quantity restored
- Quantity > 0 → Post automatically unarchives
- Post reappears in public views

---

## App Code Status

The app is **already configured** to hide archived posts:
- ✅ `HomeTabView.swift` - filters out archived listings
- ✅ `SearchService.swift` - filters out archived listings
- ✅ `ProfileTabView.swift` - filters out archived listings
- ✅ `BrowseByCategoryView.swift` - filters out archived listings

**All queries include:**
```swift
.neq("archived", value: true)
.eq("is_sold", value: false)
```

So once the database triggers are deployed, everything will work automatically.

---

## Why This Happened

The auto-archive system was **designed and coded** but the database triggers were **never deployed to production**. The Swift app was filtering archived listings, but nothing was setting `archived = true` in the database.

This is a simple deployment fix - no code changes needed.

---

## Time Required
- Step 1: 2 minutes (deploy triggers)
- Step 2: 1 minute (archive old listings)
- Step 3: 2 minutes (test)
- **Total: ~5 minutes**

---

## Files You Need
1. **`DEPLOY_AUTO_ARCHIVE_FIX.sql`** - Main fix (run this first)
2. **`RETROACTIVE_ARCHIVE_FIX.sql`** - Alternative with more diagnostic queries
3. **`VERIFY_AUTO_ARCHIVE_TRIGGERS.sql`** - Check if triggers exist

---

**Priority:** 🔴 CRITICAL - Core marketplace functionality  
**Difficulty:** 🟢 EASY - Just SQL copy/paste  
**Impact:** ✅ Fixes sold items still appearing in marketplace

---

Darragh, just run the SQL in Steps 1 and 2 in your Supabase dashboard and this will be fixed!

