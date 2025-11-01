# ⚠️ ACTION REQUIRED: Deploy Auto-Archive Triggers

## The Problem
**Posts are NOT being archived after purchase** because the database triggers were never deployed to production.

## The Fix (Takes 2 minutes)

### Step 1: Check if Triggers Exist
1. Go to **Supabase Dashboard** → **SQL Editor**
2. Copy and paste this query:
   ```sql
   SELECT trigger_name
   FROM information_schema.triggers
   WHERE trigger_name IN ('update_listing_quantity_after_order', 'restore_listing_quantity_on_order_cancel');
   ```
3. Click **Run**

**If you get 0 rows** → Triggers don't exist, proceed to Step 2  
**If you get 2 rows** → Triggers already exist, skip to Step 3

---

### Step 2: Deploy the Triggers (IF Step 1 returned 0 rows)
1. Open the file: `/Users/eileenmurphy/CampusLink/DEPLOY_AUTO_ARCHIVE_FIX.sql`
2. Copy the **ENTIRE file contents** (237 lines)
3. Paste into **Supabase SQL Editor**
4. Click **Run**
5. Wait for completion (~5 seconds)
6. You should see:
   ```
   ✅ TRIGGERS CREATED:
   - update_listing_quantity_after_order
   - restore_listing_quantity_on_order_cancel
   ```

---

### Step 2.5: Fix Old Listings (Retroactive Fix)
⚠️ **IMPORTANT:** The triggers are NOT retroactive. They only work for NEW orders after deployment.

To archive listings that SHOULD already be archived from past orders:

1. Open file: `/Users/eileenmurphy/CampusLink/RETROACTIVE_ARCHIVE_FIX.sql`
2. Run the **STEP 1** query to preview what will be fixed
3. Uncomment and run the **STEP 3** query to archive sold-out listings
4. Run the **STEP 4** query to verify the fix

This is a **one-time fix** - future orders will be handled automatically by the triggers.

---

### Step 3: Test It Works
1. Create a test listing with quantity = 1
2. Buy it with another account
3. Check the listing in Supabase:
   ```sql
   SELECT id, title, quantity_available, archived
   FROM listings
   WHERE title = 'YOUR TEST LISTING TITLE';
   ```
4. **Expected:** `quantity_available` = 0, `archived` = true ✅

---

## What Happens After Deployment

### ✅ Automatic Behavior (No code changes needed):
- **NEW orders:** When a post is purchased, `quantity_available` decreases by 1
- When `quantity_available` reaches 0, post is automatically archived
- Archived posts disappear from homepage, search, and profiles
- Sellers can still see their archived posts in "My Listings"
- If order is cancelled, quantity is restored and post is unarchived

### ⚠️ Important: NOT Retroactive
- The triggers ONLY work for orders created AFTER deployment
- Old listings that should be archived need the retroactive fix (Step 2.5)
- This is a one-time fix - future orders are handled automatically

---

## Files Reference
- **`DEPLOY_AUTO_ARCHIVE_FIX.sql`** - Run this in Supabase (main fix)
- **`RETROACTIVE_ARCHIVE_FIX.sql`** - One-time fix for old orders
- **`FIX_AUTO_ARCHIVE_DEPLOYMENT.md`** - Detailed guide with troubleshooting
- **`VERIFY_AUTO_ARCHIVE_TRIGGERS.sql`** - Diagnostic queries

---

## Need Help?
If after deploying, posts still aren't archiving:
1. Check the detailed guide: `FIX_AUTO_ARCHIVE_DEPLOYMENT.md`
2. Look at the troubleshooting section
3. Check Supabase → Logs → Postgres Logs for trigger messages

---

**Priority:** 🔴 HIGH - Core functionality broken  
**Time Required:** 2 minutes  
**Difficulty:** Easy - Just copy/paste SQL

