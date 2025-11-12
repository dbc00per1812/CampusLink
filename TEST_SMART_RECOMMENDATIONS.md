# Testing Smart Recommendations & Search

## ✅ Pre-Flight Check

Run this in Supabase SQL Editor to verify everything is set up:

```sql
-- Check 1: Vector extension enabled?
SELECT 
    CASE WHEN EXISTS (SELECT 1 FROM pg_extension WHERE extname = 'vector')
    THEN '✅ pgvector enabled'
    ELSE '❌ pgvector NOT enabled'
    END as status;

-- Check 2: Embedding column exists?
SELECT 
    CASE WHEN EXISTS (
        SELECT 1 FROM information_schema.columns 
        WHERE table_name = 'listings' AND column_name = 'embedding'
    )
    THEN '✅ embedding column exists'
    ELSE '❌ embedding column missing'
    END as status;

-- Check 3: How many embeddings generated?
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as with_embeddings,
    COUNT(*) FILTER (WHERE embedding IS NULL) as without_embeddings,
    COUNT(*) as total_active,
    ROUND(100.0 * COUNT(*) FILTER (WHERE embedding IS NOT NULL) / NULLIF(COUNT(*), 0), 1) as percent_complete
FROM listings
WHERE status = 'active' AND archived = false;

-- Check 4: All functions exist?
SELECT 
    routine_name,
    '✅' as status
FROM information_schema.routines
WHERE routine_schema = 'public'
AND routine_name IN (
    'hybrid_search_listings',
    'get_similar_listings',
    'generate_listing_embedding'
)
ORDER BY routine_name;
```

**Expected Results:**
- ✅ All should show checkmarks
- ✅ Embeddings: 100% complete (or close to it)
- ✅ All 3 functions should exist

---

## Test 1: Home Feed Diversification

### What to Test:
Open the app and go to the home feed (For You tab).

### What to Look For:
✅ **First 4 listings should show variety:**
- Different categories (not 4 of the same thing)
- Mix of products and services
- Example: Electronics, Books, Furniture, Tutoring

### In Debug Console:
Look for this log:
```
📊 Diversification: 4 listings selected
   Products: 3
   Services: 1
   Categories: 3 unique
```

### Test Different Tabs:
1. **For You** - Should show diversified first 4
2. **All** - Should show diversified first 4  
3. **Selling** - Should show diversified first 4
4. **Buying** - Should NOT show diversification (normal order)

---

## Test 2: Hybrid Search

### Test Case 1: Semantic Understanding
Search for: **"laptop"**

**Expected Results:**
- Should find: "MacBook", "computer", "notebook", etc.
- Not just exact "laptop" matches

### Test Case 2: Different Search Terms
Try these searches and see if they're smarter:

| Search | Should Also Find |
|--------|------------------|
| "bike" | bicycle, cycling gear |
| "textbook" | books, study materials |
| "couch" | sofa, furniture |
| "tutor" | tutoring, study help |

### In Debug Console:
Look for:
```
📱 SearchService: Received X results from database
```

### Compare With Keyword-Only:
1. Set `AppConfig.enableHybridSearch = false`
2. Build and search for "laptop"
3. Compare results
4. Set back to `true`

---

## Test 3: Similar Items (Future)

This is ready in the database but not yet in the UI. To test manually:

### Run in Supabase SQL Editor:
```sql
-- Get a sample listing ID
SELECT id, title, category FROM listings 
WHERE status = 'active' AND embedding IS NOT NULL 
LIMIT 1;

-- Then use that ID to find similar items
-- Replace YOUR-LISTING-ID with actual ID from above
SELECT 
    title,
    category,
    similarity_score,
    ROUND(similarity_score * 100) as similarity_percent
FROM get_similar_listings_simple(
    'YOUR-LISTING-ID'::uuid,
    5
)
ORDER BY similarity_score DESC;
```

**Expected:**
- Items in same or related categories
- Similar price ranges
- High similarity scores (>0.7 is good)

---

## Test 4: Performance Check

### Home Feed Load Time:
1. Force quit the app
2. Open it fresh
3. Time how long until listings appear

**Expected:** <1 second

### Search Performance:
1. Type a search query
2. Time until results appear

**Expected:** <500ms

### Infinite Scroll:
1. Scroll down on home feed
2. Check that more listings load smoothly
3. Diversification should ONLY apply to first 4

---

## Test 5: Verify No Breakage

Make sure existing features still work:

- [ ] Create a new listing
- [ ] Edit a listing
- [ ] Search with filters (category, price)
- [ ] View listing details
- [ ] Make a purchase
- [ ] Send a message

**All should work normally.**

---

## If Something Doesn't Work

### Issue: Home feed looks the same (no diversification)
**Check:**
- Is `useDiversification` being set to true?
- Add a print statement in `getDisplayListings()` to debug
- Check if you have enough listings with variety

### Issue: Search doesn't seem smarter
**Check:**
- Run the embedding percentage query above
- If < 50% have embeddings, run backfill again
- Check `AppConfig.enableHybridSearch = true`
- Look for errors in debug console

### Issue: Similar items don't work
**Expected** - UI not implemented yet! This is ready in database but needs UI work to add to listing detail view.

---

## Success Criteria

✅ **Phase 0 Working:**
- First 4 listings show 3+ different categories
- Mix of products and services

✅ **Phase 2 Working:**
- Search finds semantically similar items
- "laptop" finds "computer", etc.

✅ **Performance:**
- Home feed loads fast
- Search responds quickly
- No UI freezing

---

## Next Steps After Testing

If everything works:
1. Monitor user engagement metrics
2. Track if users click on the diversified listings
3. Gather feedback on search quality
4. (Future) Add "Similar items" UI to listing detail view

---

## Quick Debug Commands

### Check App Config:
Add this to HomeTabView's onAppear:
```swift
print("🔍 Diversification enabled: \(useDiversification)")
print("🔍 Hybrid search enabled: \(AppConfig.enableHybridSearch)")
```

### Check Diversification Results:
The RecommendationService already logs in DEBUG mode.

### Force Refresh:
Pull down to refresh on any tab to reload with fresh data.

