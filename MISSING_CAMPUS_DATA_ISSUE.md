# Real Issue: Missing Campus Data on Users

## You're Right!

You're absolutely correct - if users select campus from a dropdown, there shouldn't be string variations. The normalized comparison fix might not be the real issue.

## Likely Real Problem

Looking at the campus filter code more carefully (line 473-476):

```swift
guard let userCampus = listing.user.campus, !userCampus.isEmpty else {
    print("⚠️ Campus Filter: Excluding listing '\(listing.title)' - user has no campus set")
    return false // Exclude listings from users without campus
}
```

**This code EXCLUDES any listing where the seller doesn't have a campus set.**

## Possible Causes

1. **Some users don't have campus field set** 
   - Maybe older users from before campus was required?
   - Maybe signup flow has a bug where campus isn't saved?
   - Maybe database migration didn't backfill campus for existing users?

2. **Campus field is NULL or empty string in database**
   - Even if user selected it during signup, maybe it didn't save properly

3. **Filter is too restrictive**
   - Maybe `enableCampusFilter` should be `false` for now?
   - Or filter should show posts from users without campus?

## Diagnostic

Run `CHECK_MISSING_CAMPUS_DATA.sql` in Supabase to check:

1. How many active posts are from users without campus set
2. How many Purdue email users don't have campus set
3. Which specific posts would be filtered out

This will tell us if missing campus data is the real issue.

## Quick Checks

### Check 1: Are there users without campus?
```sql
SELECT COUNT(*) 
FROM users 
WHERE campus IS NULL OR campus = '';
```

### Check 2: Are there active listings from users without campus?
```sql
SELECT COUNT(l.*) 
FROM listings l
JOIN users u ON u.id = l.user_id
WHERE l.archived = false 
  AND l.is_sold = false 
  AND l.status = 'active'
  AND (u.campus IS NULL OR u.campus = '');
```

### Check 3: Are there Purdue users without campus set?
```sql
SELECT COUNT(*) 
FROM users 
WHERE email ILIKE '%purdue.edu%' 
  AND (campus IS NULL OR campus = '' OR campus != 'Purdue University');
```

## Potential Fixes

### Fix 1: Backfill Missing Campus Data

If users have Purdue email but no campus:
```sql
UPDATE users
SET campus = 'Purdue University'
WHERE email ILIKE '%purdue.edu%' 
  AND (campus IS NULL OR campus = '');

UPDATE users
SET campus = 'Indiana University Bloomington'
WHERE email ILIKE '%iu.edu%' 
  AND (campus IS NULL OR campus = '');
```

### Fix 2: Make Filter More Lenient

Show posts from users without campus to everyone:

**In `HomeTabView.swift` line 473**, change:
```swift
guard let userCampus = listing.user.campus, !userCampus.isEmpty else {
    print("⚠️ Campus Filter: Excluding listing '\(listing.title)' - user has no campus set")
    return false // Exclude listings from users without campus
}
```

To:
```swift
guard let userCampus = listing.user.campus, !userCampus.isEmpty else {
    print("⚠️ Campus Filter: Including listing '\(listing.title)' - user has no campus set (showing to all)")
    return true // Show listings from users without campus to everyone
}
```

### Fix 3: Disable Campus Filter Temporarily

**In `HomeTabView.swift` line 41**, change:
```swift
private let enableCampusFilter = true
```

To:
```swift
private let enableCampusFilter = false  // Disabled until campus data is backfilled
```

## Next Steps

1. **Run `CHECK_MISSING_CAMPUS_DATA.sql`** to see if this is the issue
2. **Check Xcode console logs** when viewing app - look for:
   ```
   ⚠️ Campus Filter: Excluding listing 'X' - user has no campus set
   ```
3. Based on results, apply appropriate fix

## Most Likely Solution

If the diagnostic shows many users without campus:
1. Backfill campus data based on email domain (Fix 1)
2. Ensure signup flow properly saves campus
3. Add database constraint to require campus on new users

**Darragh** - Run `CHECK_MISSING_CAMPUS_DATA.sql` first. If it shows users without campus data, that's your issue. The normalized comparison fix I made is still good to have, but the real problem is likely missing campus data.







