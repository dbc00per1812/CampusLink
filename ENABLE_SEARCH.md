# How to Enable Full Search Functionality

## Quick Steps:

1. **Open Supabase Dashboard**
   - Go to your Supabase project dashboard
   - Navigate to the SQL Editor

2. **Run the Search Setup Script**
   - Copy the entire contents of `create_search_functions.sql`
   - Paste it into the SQL editor
   - Click "Run" to execute

3. **Verify Installation**
   - The script creates:
     - Full-text search indexes
     - `search_listings` function
     - `get_search_suggestions` function
     - Performance indexes

4. **Test Search**
   - Search is already enabled in the app (AppConfig.enableSearch = true)
   - Try searching for:
     - Product names (e.g., "laptop", "textbook")
     - Categories (e.g., "Electronics", "Tutoring")
     - Descriptions
   - Use filters:
     - Category dropdown
     - Price range
     - Selling/Buying filter
     - Trust score minimum

## What the Search Does:

- **Keyword Matching**: Searches in both title and description
- **Smart Ranking**: Prioritizes title matches over description matches
- **Partial Matches**: "lap" will find "laptop"
- **Case Insensitive**: "LAPTOP" = "laptop" = "Laptop"
- **Filter Combination**: All filters work together
- **Fast Performance**: Uses PostgreSQL GIN indexes

## Troubleshooting:

If search returns no results:
1. Check that you have active listings in the database
2. Verify the SQL functions were created successfully
3. Try a simple search without filters first
4. Check that listings have `status = 'active'` and `archived = false`

That's it! Search should now work properly with full keyword matching and filtering.
