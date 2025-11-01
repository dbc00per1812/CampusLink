# Campus Display Issue - Diagnostic Steps

## Issue
User signed up as IU student, Supabase shows IU, but UI displays "Purdue" filter badge.

## Quick Checks

### 1. Check Xcode Console Logs
When you open the app, look for these log messages in Xcode console:
```
🔍 Loading campus for user: [user-id]
✅ Loaded user data - Campus: [campus-value]
✅ Set userCampus to: [campus-value]
```

The `[campus-value]` should show what's actually being loaded from the database.

### 2. Verify Database Value in Supabase
Go to Supabase Dashboard → Table Editor → `users` table
- Find your user by email
- Check the `campus` column value
- It should be EXACTLY: `Indiana University Bloomington` (not `IU`, not `Indiana University`)

### 3. Force Refresh
Try these steps in order:
1. **Sign out and sign back in** - This will reload all user data
2. **Kill and restart the app** - Clears any cached state
3. **Delete app and reinstall** - Nuclear option if above doesn't work

## Expected Values

The app expects these EXACT strings:
- ✅ `Indiana University Bloomington` → Displays as "IU"
- ✅ `Purdue University` → Displays as "Purdue"
- ❌ Any other value (like `IU`, `Indiana University`, etc.) → Will display as-is or cause issues

## SQL Query to Check Your Data

Run this in Supabase SQL Editor to see recent signups:

```sql
SELECT 
  id,
  email, 
  campus,
  created_at
FROM users 
WHERE email LIKE '%iu.edu%' OR email LIKE '%indiana.edu%'
ORDER BY created_at DESC 
LIMIT 10;
```

## Likely Causes

1. **Cached State** - App is showing old data from a previous session
2. **Wrong Database Value** - Database has "Purdue University" instead of "Indiana University Bloomington"
3. **Multiple Accounts** - You might be looking at a different account
4. **State Not Refreshing** - The `loadUserCampus()` function didn't run or failed

## Next Steps

1. Check Xcode console logs (most important!)
2. Verify database value matches EXACTLY: `Indiana University Bloomington`
3. Try sign out/in
4. If issue persists, share the console logs

