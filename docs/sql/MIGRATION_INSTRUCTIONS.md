# SQL Migration Instructions

## How to Run SQL Migrations

### For Supabase (Current Setup)

1. Log in to [Supabase Dashboard](https://app.supabase.com)
2. Select your CampusLink project
3. Navigate to **SQL Editor** in the left sidebar
4. Click **New Query**
5. Copy the contents of the SQL file you want to run
6. Paste into the query editor
7. Click **Run** button

### Pending Migrations

#### Add Conversation Archive Fields
**File**: `add_conversation_archive_fields.sql`

**Status**: ⏳ Pending - Run this to enable swipe-to-delete on conversations

**Description**: Adds `archived_by_buyer` and `archived_by_seller` columns to the conversations table, allowing users to independently archive conversations from their view.

**Safe to run**: ✅ Yes - Uses `IF NOT EXISTS` clauses and default values

**Rollback** (if needed):
```sql
-- Remove archive columns
ALTER TABLE public.conversations DROP COLUMN IF EXISTS archived_by_buyer;
ALTER TABLE public.conversations DROP COLUMN IF EXISTS archived_by_seller;

-- Remove indexes
DROP INDEX IF EXISTS idx_conversations_archived_by_buyer;
DROP INDEX IF EXISTS idx_conversations_archived_by_seller;
```

---

## Migration Checklist

- [ ] Run migration in Supabase SQL Editor
- [ ] Verify no errors in the execution output
- [ ] Test the feature in the mobile app
- [ ] If issues occur, run rollback script
- [ ] Update this file to mark migration as complete

---

*Last updated: December 13, 2025*

