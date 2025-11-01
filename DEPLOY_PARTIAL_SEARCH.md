# Deploy Partial Search Feature

This guide will help you enable partial/prefix search so users can find results by typing partial words (e.g., "lap" finds "laptop").

## What This Does

- **Before**: User had to type complete words to get search results
- **After**: Typing any part of a word shows matching results
- **Example**: Typing "tut" now finds "tutoring", "tutorial", "tutor", etc.

## Quick Deploy (2 Minutes)

### Step 1: Open Supabase SQL Editor

1. Go to your Supabase dashboard
2. Click on "SQL Editor" in the left sidebar
3. Click "+ New query" button

### Step 2: Run the SQL Script

1. Open the file: `enable_partial_search.sql`
2. Copy ALL the contents (Cmd+A, Cmd+C)
3. Paste into the Supabase SQL Editor (Cmd+V)
4. Click "Run" button (or press Cmd+Enter)

### Step 3: Verify It Works

You should see test results at the bottom showing:
```
id | title | relevance_score | photo | photo_count
```

If you see results, the deployment was successful! ✅

## How It Works

### Old Behavior (Full Word Matching)
```sql
-- Only matched complete words
l.tsv @@ plainto_tsquery('english', query_text)
```

### New Behavior (Partial Matching)
```sql
-- Matches any part of the word (case-insensitive)
LOWER(l.title) LIKE '%' || query_text || '%'
OR LOWER(l.description) LIKE '%' || query_text || '%'
OR LOWER(l.category) LIKE '%' || query_text || '%'
```

## Smart Relevance Scoring

Results are ranked by relevance:

| Match Type | Score | Example |
|------------|-------|---------|
| Exact match | 10.0 | "laptop" matches "laptop" |
| Title starts with | 7.0 | "lap" matches "**lap**top" |
| Title contains | 5.0 | "top" matches "lap**top**" |
| Category match | 3.0-8.0 | "elec" matches "**elec**tronics" |
| Description match | 1.0-2.0 | Search term in description |

## Testing After Deployment

### In the App
1. Open CampusLink app
2. Go to Search tab
3. Type partial words:
   - "tex" → should find textbooks
   - "lap" → should find laptops
   - "tut" → should find tutoring

### Example Searches to Try
- "fur" → furniture
- "elec" → electronics  
- "bike" → bicycle, bike
- "text" → textbook, texting

## Troubleshooting

### Error: "function search_listings already exists"
- This is fine! The script uses `DROP FUNCTION IF EXISTS` to handle this
- The function will be replaced with the new version

### No results showing up
- Check if listings exist with those keywords
- Try a more common word like "the" or "a" to test if ANY results show

### Search seems slow
- For large databases (10,000+ listings), consider adding an index:
  ```sql
  CREATE INDEX idx_listings_title_gin ON listings USING gin(lower(title) gin_trgm_ops);
  CREATE INDEX idx_listings_description_gin ON listings USING gin(lower(description) gin_trgm_ops);
  ```

## Rollback (If Needed)

If you need to revert to the old behavior:

1. Open Supabase SQL Editor
2. Run the `fix_search_photos.sql` script
3. This will restore the original full-word matching

## Technical Notes

- **Performance**: ILIKE is efficient for small-medium datasets
- **Case-Insensitive**: Uses LOWER() for case-insensitive matching
- **No Extensions Needed**: Works with standard PostgreSQL (no pg_trgm required)
- **Backwards Compatible**: All existing features and filters still work
- **All Filters Maintained**: Price, category, intent, trust score, etc.

## Next Steps

After successful deployment:
- ✅ Test the search with partial words
- ✅ Monitor performance (should be fine for current dataset size)
- ✅ Gather user feedback on search quality
- Consider adding search analytics to track popular partial searches

## Support

If you encounter any issues:
1. Check Supabase logs for errors
2. Verify the function exists: `SELECT * FROM pg_proc WHERE proname = 'search_listings';`
3. Test with the provided SQL test query in the script

---

**Status**: Ready to deploy
**Estimated Time**: 2 minutes
**Risk Level**: Low (easily reversible)

