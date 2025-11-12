# Quick Fix Guide

## Issue 1: Embeddings Not Generated (0%)

**Cause:** Supabase AI not properly enabled

**Fix:**
1. Run `FIX_EMBEDDINGS_NOW.sql` in Supabase SQL Editor
2. It will tell you if AI is available
3. If not, go to: Supabase Dashboard → Project Settings → AI
4. Toggle ON "Enable Database Functions"
5. Wait 30 seconds
6. Run `FIX_EMBEDDINGS_NOW.sql` again

**Then run:**
```sql
-- Generate embeddings in batches
SELECT regenerate_embeddings_batch(50);
```

Keep running until all 71 listings have embeddings.

---

## Issue 2: Home Page Looks the Same

**Possible causes:**
1. Not enough variety in test data
2. Diversification logic not triggering

**Diagnose:**
1. Run `TEST_DIVERSIFICATION.sql` in Supabase
2. Check if you have 3+ different categories
3. Check Xcode console for diversification logs

**Test:**
1. Build and run app
2. Open home feed
3. Look in Xcode console for:
   ```
   🔍 Diversification check:
   ✅ Applying diversification...
   📊 Diversification: 4 listings selected
   ```

If you see "Skipping diversification", it means conditions aren't met (need 5+ listings on first page).

---

## What Should Work NOW (Even Without Embeddings):

✅ **Diversification** - Works client-side, no embeddings needed
- First 4 listings show variety

❌ **Hybrid Search** - Needs embeddings
- Will fall back to keyword-only search
- Still works, just not as smart yet

❌ **Similar Items** - Needs embeddings
- Returns empty for now

---

## Quick Test in App:

1. Force quit app
2. Reopen
3. In Xcode console, look for log messages
4. Take screenshot of first 4 listings
5. Tell me what categories you see

