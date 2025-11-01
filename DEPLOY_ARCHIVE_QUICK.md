# Quick Deploy: Fix Posts Not Archiving

## 🚨 The Problem
Sold/sold-out posts are still showing up in the marketplace because the auto-archive triggers were never deployed.

## ✅ The Fix (5 Minutes)

### Step 1: Deploy Triggers (2 min)
```sql
-- Go to Supabase → SQL Editor
-- Copy and paste all of DEPLOY_AUTO_ARCHIVE_FIX.sql
-- Click Run
```

### Step 2: Archive Old Sold-Out Listings (1 min)
```sql
-- Go to Supabase → SQL Editor
-- Run this:
UPDATE listings
SET archived = true
WHERE quantity_available <= 0
  AND archived = false;
```

### Step 3: Verify (1 min)
```sql
-- Check that sold-out listings are now archived:
SELECT id, title, quantity_available, archived
FROM listings
WHERE quantity_available <= 0
LIMIT 10;
-- All should show archived = true ✅
```

## 🎯 What Happens Next

### For New Orders (Automatic):
- Item purchased → Quantity decrements
- Quantity = 0 → Post archives automatically
- Archived post disappears from marketplace

### For Cancellations (Automatic):
- Order cancelled → Quantity restored  
- Quantity > 0 → Post unarchives automatically
- Post reappears in marketplace

## ✅ Done!
After Step 1 & 2, your marketplace will automatically archive sold-out posts forever.

---

**Files to use:**
- `DEPLOY_AUTO_ARCHIVE_FIX.sql` ← Run this first
- `FIX_ARCHIVE_NOW.md` ← Detailed guide if needed

