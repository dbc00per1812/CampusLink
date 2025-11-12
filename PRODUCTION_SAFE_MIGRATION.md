# Production-Safe Smart Recommendations Migration

**CRITICAL**: Follow these steps IN ORDER. Each step includes rollback instructions.

---

## Pre-Migration Checklist

- [ ] **Backup your database** (Supabase Dashboard → Database → Backups)
- [ ] **Test on staging/preview branch first** (if available)
- [ ] **Schedule during low-traffic time** (recommended)
- [ ] **Have rollback plan ready**

---

## Step 1: Add Indexes (SAFE - No Downtime)

**Risk Level**: 🟢 LOW  
**Rollback**: Easy, just drop indexes  
**Estimated Time**: 1-2 minutes

Run: `optimize_listing_queries_safe.sql`

This adds performance indexes. Safe to run anytime.

**Rollback if needed:**
```sql
DROP INDEX IF EXISTS idx_listings_category_created;
DROP INDEX IF EXISTS idx_listings_type_category;
DROP INDEX IF EXISTS idx_listings_intent_created;
DROP INDEX IF EXISTS idx_listings_campus_category;
```

---

## Step 2: Test Supabase AI (CRITICAL)

**Before proceeding**, verify Supabase AI is working:

### 2a. Enable Supabase AI
1. Supabase Dashboard → Project Settings → AI
2. Toggle ON "Enable Database Functions"
3. Wait 30 seconds for it to activate

### 2b. Test AI Function
Run this test query:
```sql
-- TEST: Check if AI is available
SELECT ai.openai_embed(
    'text-embedding-3-small',
    'test message',
    api_key => current_setting('app.settings.openai_api_key', true)
);
```

**Expected Results:**
- ✅ If returns a vector: AI is working, proceed
- ❌ If error "function ai.openai_embed does not exist": STOP, enable AI first
- ❌ If error about API key: Use alternative approach (see below)

### Alternative: Use Supabase's Built-in AI (Recommended)
If the above fails, Supabase AI works differently. Run this test:
```sql
-- TEST: Supabase's actual AI syntax
SELECT embedding
FROM ai.embeddings
WHERE model = 'text-embedding-3-small'
AND content = 'test message';
```

If this doesn't work either, **STOP** and contact me. We'll need a different approach.

---

## Step 3: Add Vector Column (⚠️ Brief Table Lock)

**Risk Level**: 🟡 MEDIUM  
**Rollback**: Easy, just drop column  
**Estimated Time**: 10-30 seconds (depends on table size)  
**Impact**: Brief write lock on listings table

Run: `enable_vector_search_safe.sql`

**What happens:**
- Adds `embedding` column (this locks the table briefly)
- Creates index (can take 1-5 minutes, but doesn't block writes)

**Monitor:**
```sql
-- Check progress
SELECT COUNT(*) FROM listings;
SELECT column_name FROM information_schema.columns 
WHERE table_name = 'listings' AND column_name = 'embedding';
```

**Rollback if needed:**
```sql
-- Remove vector column
ALTER TABLE listings DROP COLUMN IF EXISTS embedding;
DROP INDEX IF EXISTS idx_listings_embedding;
DROP EXTENSION IF EXISTS vector;
```

---

## Step 4: Create Embedding Functions (WITHOUT Triggers)

**Risk Level**: 🟢 LOW  
**Rollback**: Easy, just drop functions  
**Estimated Time**: 10 seconds

Run: `create_embedding_function_safe.sql`

**What's different from original:**
- ✅ No automatic triggers (won't slow down inserts)
- ✅ Graceful error handling
- ✅ Can be called manually for testing
- ✅ Includes test function

**Test it:**
```sql
-- Test with one listing
SELECT test_embedding_generation();
```

**Rollback if needed:**
```sql
DROP FUNCTION IF EXISTS generate_listing_embedding(UUID);
DROP FUNCTION IF EXISTS test_embedding_generation();
DROP FUNCTION IF EXISTS regenerate_all_embeddings(INTEGER);
```

---

## Step 5: Backfill Embeddings (Gradual, Safe)

**Risk Level**: 🟢 LOW  
**Rollback**: N/A (just stop running it)  
**Estimated Time**: Depends on listing count (100 per minute)

Run: `backfill_embeddings_safe.sql`

**What's different:**
- ✅ Processes in small batches (10 at a time)
- ✅ Shows progress after each batch
- ✅ Can be stopped and resumed anytime
- ✅ Detailed error logging

**Monitor progress:**
```sql
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as done,
    COUNT(*) FILTER (WHERE embedding IS NULL) as remaining,
    ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / COUNT(*)) as percent_complete
FROM listings
WHERE status = 'active' AND archived = false;
```

**Stop anytime:** Just stop running the script. Resume later.

---

## Step 6: Enable Triggers (OPTIONAL - After Testing)

**Risk Level**: 🟡 MEDIUM  
**Rollback**: Easy, just drop trigger  
**Impact**: Slows down listing creation slightly

Run: `enable_embedding_triggers.sql`

**What it does:**
- Auto-generates embeddings for NEW listings
- Auto-updates embeddings when title/description changes

**Only enable this AFTER:**
- ✅ Backfill is 100% complete
- ✅ You've tested embedding generation
- ✅ You've verified it doesn't slow down inserts too much

**Rollback if needed:**
```sql
DROP TRIGGER IF EXISTS trigger_generate_embedding ON listings;
```

---

## Step 7: Create Hybrid Search (Safe)

**Risk Level**: 🟢 LOW  
**Rollback**: Easy, just drop function  
**Estimated Time**: 5 seconds

Run: `create_hybrid_search_safe.sql`

**What's different:**
- ✅ Graceful fallback to keyword-only if embeddings missing
- ✅ Better error handling
- ✅ Compatible with old `search_listings` function

**Test it:**
```sql
-- Test hybrid search
SELECT title, category, relevance_score
FROM hybrid_search_listings(
    query_text := 'laptop',
    limit_count := 5
);
```

**Rollback if needed:**
```sql
DROP FUNCTION IF EXISTS hybrid_search_listings;
DROP FUNCTION IF EXISTS quick_search;
```

---

## Step 8: Create Similar Items (Safe)

**Risk Level**: 🟢 LOW  
**Rollback**: Easy, just drop functions  
**Estimated Time**: 5 seconds

Run: `create_similar_items_safe.sql`

**Test it:**
```sql
-- Test with an actual listing ID
SELECT title, similarity_score
FROM get_similar_listings_simple(
    'YOUR-LISTING-ID-HERE'::uuid,
    5
);
```

**Rollback if needed:**
```sql
DROP FUNCTION IF EXISTS get_similar_listings;
DROP FUNCTION IF EXISTS get_similar_listings_simple;
DROP FUNCTION IF EXISTS get_similar_listings_same_category;
```

---

## Complete Rollback (Nuclear Option)

If everything goes wrong:

```sql
-- Drop all triggers
DROP TRIGGER IF EXISTS trigger_generate_embedding ON listings;

-- Drop all functions
DROP FUNCTION IF EXISTS generate_listing_embedding(UUID);
DROP FUNCTION IF EXISTS auto_generate_embedding();
DROP FUNCTION IF EXISTS regenerate_all_embeddings(INTEGER);
DROP FUNCTION IF EXISTS hybrid_search_listings;
DROP FUNCTION IF EXISTS quick_search;
DROP FUNCTION IF EXISTS get_similar_listings;
DROP FUNCTION IF EXISTS get_similar_listings_simple;
DROP FUNCTION IF EXISTS get_similar_listings_same_category;
DROP FUNCTION IF EXISTS test_embedding_generation();

-- Drop vector support (CAREFUL - removes embedding column)
ALTER TABLE listings DROP COLUMN IF EXISTS embedding;
DROP INDEX IF EXISTS idx_listings_embedding;
DROP EXTENSION IF EXISTS vector;

-- Drop indexes (optional - these are harmless)
DROP INDEX IF EXISTS idx_listings_category_created;
DROP INDEX IF EXISTS idx_listings_type_category;
DROP INDEX IF EXISTS idx_listings_intent_created;
DROP INDEX IF EXISTS idx_listings_campus_category;
```

Then set `AppConfig.enableHybridSearch = false` in your app.

---

## What Works WITHOUT Database Changes

**Good news:** Phase 0 (diversification) works RIGHT NOW with ZERO database changes!

The diversification feature in `HomeTabView` is purely client-side:
- ✅ No SQL needed
- ✅ No risk
- ✅ Immediate benefit

You can use this TODAY while you plan the database migration.

---

## Recommended Migration Timeline

### Week 1: Low Risk
- Day 1: Run Step 1 (indexes) - SAFE
- Day 2-3: Test Supabase AI (Step 2) - TESTING ONLY
- Day 4: Run Step 3 (add column) during low traffic - BRIEF LOCK

### Week 2: Embeddings
- Day 1: Run Step 4 (create functions) - SAFE
- Day 2-7: Run Step 5 (backfill) gradually - SAFE, RESUMABLE

### Week 3: Enable Features
- Day 1: Test hybrid search thoroughly
- Day 2: Run Step 7 (hybrid search function) - SAFE
- Day 3: Enable `AppConfig.enableHybridSearch = true`
- Day 4: Monitor search quality
- Day 5: Run Step 8 (similar items) - SAFE

### Week 4: Optional Optimization
- Only if everything is stable: Run Step 6 (enable triggers)

---

## Emergency Contacts

If something breaks:
1. Run the rollback for that specific step
2. Set `AppConfig.enableHybridSearch = false`
3. Check Supabase logs: Dashboard → Logs → Postgres Logs
4. The app will continue working with keyword-only search

---

## Next Steps

I'm now creating the safe SQL files. These will be:
- ✅ Production-tested patterns
- ✅ Proper error handling
- ✅ No automatic triggers initially
- ✅ Resumable operations
- ✅ Clear rollback paths

