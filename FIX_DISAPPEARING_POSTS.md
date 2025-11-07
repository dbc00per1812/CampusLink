# Fix: Posts Disappearing From Purdue Page

## Problem
Posts on the Purdue page are disappearing after a while, even though they're still active and not archived.

## Diagnosis Steps

### Step 1: Run Diagnostic Query
1. Open **Supabase Dashboard** → **SQL Editor**
2. Open the file: `/Users/eileenmurphy/CampusLink/DIAGNOSE_DISAPPEARING_POSTS.sql`
3. Copy and paste the entire file into the SQL Editor
4. Click **Run**
5. Review the results

### Step 2: Analyze the Results

Look for these issues in the diagnostic output:

#### Issue 1: Incorrectly Archived Posts
If you see posts with `HAS STOCK BUT ARCHIVED` in STEP 3:
- These posts have `quantity_available > 0` but `archived = true`
- They should be visible but are hidden
- **Fix**: Run the fix below

#### Issue 2: Trigger Not Firing Correctly
If auto-archive triggers are missing or not working:
- Check STEP 6 output
- If triggers are missing, redeploy them
- **Fix**: Run `DEPLOY_AUTO_ARCHIVE_FIX.sql`

#### Issue 3: Time-Based Pattern
If STEP 5 shows higher archive rates for older posts:
- This could indicate a cron job or scheduled task archiving old posts
- Check the engagement notifications deployment
- **Fix**: May need to disable or adjust the cron job

#### Issue 4: Campus Field Issues
If STEP 8 shows inconsistent campus values:
- Posts may be filtered due to campus name mismatch
- **Fix**: Standardize campus names

## Likely Causes

### Cause 1: Auto-Archive Triggers Firing Incorrectly
The auto-archive system might be archiving posts that still have stock.

**Check**:
```sql
SELECT id, title, quantity_available, archived, is_sold
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE u.campus = 'Purdue University'
  AND quantity_available > 0
  AND archived = true;
```

**Fix** (if posts found):
```sql
-- Unarchive posts that still have stock
UPDATE listings
SET archived = false, is_sold = false
WHERE quantity_available > 0
  AND archived = true
  AND user_id IN (SELECT id FROM users WHERE campus = 'Purdue University');
```

### Cause 2: Quantity Being Set to 0 Incorrectly
Orders might be decrementing quantity incorrectly (bug in trigger).

**Check**:
```sql
SELECT 
    l.id,
    l.title,
    l.quantity_available,
    l.quantity_sold,
    l.archived,
    COALESCE(SUM(o.quantity), 0) as actual_orders
FROM listings l
JOIN users u ON u.id = l.user_id
LEFT JOIN orders o ON o.listing_id = l.id AND o.payment_status = 'succeeded'
WHERE u.campus = 'Purdue University'
  AND l.created_at > NOW() - INTERVAL '30 days'
GROUP BY l.id, l.title, l.quantity_available, l.quantity_sold, l.archived
HAVING l.quantity_sold > COALESCE(SUM(o.quantity), 0)
   OR l.quantity_available < 0;
```

**Fix** (if inconsistencies found):
```sql
-- Recalculate quantities for all listings
UPDATE listings l
SET 
    quantity_sold = COALESCE((
        SELECT SUM(o.quantity) 
        FROM orders o 
        WHERE o.listing_id = l.id 
        AND o.payment_status = 'succeeded'
    ), 0),
    quantity_available = GREATEST(0, 
        1 - COALESCE((
            SELECT SUM(o.quantity) 
            FROM orders o 
            WHERE o.listing_id = l.id 
            AND o.payment_status = 'succeeded'
        ), 0)
    ),
    archived = CASE 
        WHEN 1 - COALESCE((
            SELECT SUM(o.quantity) 
            FROM orders o 
            WHERE o.listing_id = l.id 
            AND o.payment_status = 'succeeded'
        ), 0) <= 0 THEN true
        ELSE false
    END
WHERE l.user_id IN (SELECT id FROM users WHERE campus = 'Purdue University')
  AND l.created_at > NOW() - INTERVAL '30 days';
```

### Cause 3: Frontend Filter Issue
The app might be incorrectly filtering Purdue posts on the client side.

**Check**: Look at `HomeTabView.swift` line 571 - `applyCampusFilter()` function.

### Cause 4: Campus Name Mismatch
Users might be saved with different campus string variations.

**Check**:
```sql
SELECT DISTINCT campus, COUNT(*) 
FROM users 
WHERE campus LIKE '%Purdue%' OR campus LIKE '%purdue%'
GROUP BY campus;
```

**Fix** (if variations found):
```sql
-- Standardize to exact campus name
UPDATE users
SET campus = 'Purdue University'
WHERE campus LIKE '%Purdue%' OR campus LIKE '%purdue%';
```

## Quick Fix (If Posts Are Incorrectly Archived)

If the diagnostic shows posts that should be visible but are archived, run this:

```sql
-- Step 1: Unarchive posts that still have stock
UPDATE listings
SET archived = false, is_sold = false
WHERE quantity_available > 0
  AND archived = true
  AND user_id IN (SELECT id FROM users WHERE campus = 'Purdue University');

-- Step 2: Verify the fix
SELECT 
    '✅ FIXED POSTS' as result,
    COUNT(*) as posts_unarchived
FROM listings
WHERE quantity_available > 0
  AND archived = false
  AND user_id IN (SELECT id FROM users WHERE campus = 'Purdue University');
```

## Prevention

To prevent this from happening again:

1. **Ensure Triggers Are Correct**
   - Run `DEPLOY_AUTO_ARCHIVE_FIX.sql` to deploy correct triggers
   - Verify with `CHECK_IF_TRIGGERS_DEPLOYED.sql`

2. **Add Safeguard to Trigger**
   - Modify the trigger to NEVER archive if quantity > 0
   - Add logging to track when posts are archived

3. **Monitor Listings**
   - Regularly check for posts with `quantity_available > 0` AND `archived = true`
   - Set up alert if this condition is detected

## Next Steps

1. ✅ Run `DIAGNOSE_DISAPPEARING_POSTS.sql`
2. ✅ Review the diagnostic output
3. ✅ Identify which cause applies
4. ✅ Run the appropriate fix
5. ✅ Verify posts are now visible
6. ✅ Deploy safeguards to prevent recurrence

**Darragh** - Run the diagnostic SQL first and share the results. That will tell us exactly what's causing the posts to disappear.


