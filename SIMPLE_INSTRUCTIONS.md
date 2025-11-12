# Simple Instructions - Smart Recommendations

## Step 1: Add File to Xcode ⚠️ REQUIRED

**In Xcode:**
1. Right-click `CampusLink/Core/Services/` folder
2. Click "Add Files to CampusLink..."
3. Select `RecommendationService.swift`
4. ✅ Check "Add to targets: CampusLink"
5. Click "Add"

**Or drag-and-drop:**
- Drag `RecommendationService.swift` from Finder into Xcode's `Core/Services/` folder

**This fixes the error you saw.**

---

## Step 2: Run Database Migration

**BEFORE you run anything:**
1. Supabase Dashboard → Project Settings → AI
2. Enable "Database Functions"
3. Wait 30 seconds

**Then:**
1. Open Supabase SQL Editor
2. Copy/paste entire content of `MASTER_MIGRATION_ALL_IN_ONE.sql`
3. Click "Run"
4. Wait 2-5 minutes

**If it says "X listings still need embeddings":**
- Just run the same file again
- Keep running until it says "MIGRATION COMPLETE"

---

## Step 3: Build & Run

Build and run your app. Done!

---

## What You'll Get

✅ **Diversified home feed** - Variety of categories in first 4 listings  
✅ **Hybrid search** - Smarter search that understands meaning  
✅ **Similar items** - Foundation for recommendations

---

## If Something Fails

**Don't panic.** Just tell me the error and I'll help you fix it.

Every query has rollback instructions at the bottom of `MASTER_MIGRATION_ALL_IN_ONE.sql`.

---

## Minimum to Get Started

**Just want diversification without database changes?**

1. Add `RecommendationService.swift` to Xcode
2. Build and run
3. Skip Step 2 entirely

The diversified home feed works WITHOUT any database changes!
