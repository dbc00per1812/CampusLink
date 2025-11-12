# Important: Supabase SQL Editor and CONCURRENTLY

## Why CONCURRENTLY Was Removed

Supabase SQL Editor runs all queries inside a transaction block by default.

`CREATE INDEX CONCURRENTLY` **cannot** run inside a transaction, which causes:
```
ERROR: 25001: CREATE INDEX CONCURRENTLY cannot run inside a transaction block
```

## Solution

All SQL files have been updated to use regular `CREATE INDEX` (without CONCURRENTLY).

### Impact

**Regular CREATE INDEX:**
- ✅ Works in Supabase SQL Editor
- ✅ Creates indexes successfully
- ⚠️ May briefly lock the table during creation (1-5 minutes)
- ✅ Safe for small to medium tables (<100k rows)

**Recommended:** Run during low-traffic times for larger tables.

### Alternative (If You Need CONCURRENTLY)

If you have a very large table and need concurrent index creation:

1. Use `psql` directly (not SQL Editor):
   ```bash
   psql "postgresql://[connection-string]" -c "CREATE INDEX CONCURRENTLY..."
   ```

2. Or run each CREATE INDEX statement separately in SQL Editor (they still work fine without CONCURRENTLY)

## All Fixed Files

✅ optimize_listing_queries_safe.sql
✅ enable_vector_search_safe.sql

All other files don't use CONCURRENTLY and will work fine.
