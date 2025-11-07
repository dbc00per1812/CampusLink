# Fix: Frontend Campus Filter Hiding Posts

## Problem
Posts appear as visible in the database but don't show up in the app. This is caused by the **frontend campus filter** doing exact string matching.

## Root Cause

In `HomeTabView.swift` line 478:
```swift
let shouldInclude = userCampus == currentCampus
```

This does **exact string matching**. If campus names have:
- Different capitalization ("Purdue University" vs "purdue university")
- Extra whitespace ("Purdue University " vs "Purdue University")
- Different formats ("Purdue" vs "Purdue University")

Then posts won't match and will be filtered out by the app, even though they exist in the database.

## Diagnosis

### Step 1: Check Campus String Variations
Run `CHECK_CAMPUS_STRINGS.sql` in Supabase SQL Editor to see if there are variations.

Look for:
- Multiple entries for the same campus with different strings
- Extra spaces or different capitalizations
- Users/listings that should match but have different campus strings

### Step 2: Check Xcode Console Logs
When viewing the app, check Xcode console for these log messages:
```
🔍 Campus Filter: Current user campus: [CAMPUS_NAME]
🚫 Campus Filter: Excluding listing '[TITLE]' - campus mismatch (user: X vs current: Y)
✅ Campus Filter: Including listing '[TITLE]' - campus match
🔍 Campus Filter: Filtered X listings to Y for campus [CAMPUS_NAME]
```

This will show you:
1. What campus the current user has
2. Which listings are being excluded and why
3. The exact campus strings being compared

## Solutions

### Solution 1: Fix Database Campus Names (Recommended)

Standardize all campus names in the database to exact values:

```sql
-- Standardize Purdue
UPDATE users
SET campus = 'Purdue University'
WHERE campus ILIKE '%purdue%' AND campus != 'Purdue University';

-- Standardize IU
UPDATE users
SET campus = 'Indiana University Bloomington'
WHERE (campus ILIKE '%indiana%' OR campus ILIKE '%bloomington%') 
  AND campus != 'Indiana University Bloomington';

-- Remove extra whitespace from all campus names
UPDATE users
SET campus = TRIM(campus)
WHERE campus IS NOT NULL AND campus != TRIM(campus);

-- Verify the fix
SELECT campus, COUNT(*) 
FROM users 
WHERE campus IS NOT NULL 
GROUP BY campus 
ORDER BY COUNT(*) DESC;
```

### Solution 2: Make Frontend Filter Case-Insensitive

Update `HomeTabView.swift` to use case-insensitive comparison:

**Find** (around line 478):
```swift
let shouldInclude = userCampus == currentCampus
```

**Replace with**:
```swift
let shouldInclude = userCampus.trimmingCharacters(in: .whitespaces).lowercased() == 
                    currentCampus.trimmingCharacters(in: .whitespaces).lowercased()
```

This will:
- Ignore leading/trailing whitespace
- Ignore capitalization differences
- Match "Purdue University", "purdue university", " Purdue University " as the same

**Also update** the same comparison in `BrowseByCategoryView.swift` around line 242.

### Solution 3: Temporarily Disable Campus Filter

If you need an immediate fix while investigating:

**In `HomeTabView.swift` line 41**, change:
```swift
private let enableCampusFilter = true
```

**To**:
```swift
private let enableCampusFilter = false
```

This will show all listings regardless of campus. ⚠️ Only use this temporarily for testing!

## Step-by-Step Fix (Recommended Approach)

### Step 1: Diagnose
```bash
# Run in Supabase SQL Editor
CHECK_CAMPUS_STRINGS.sql
```

### Step 2: Check Xcode Logs
1. Run app in Xcode
2. Go to Purdue page
3. Check console for campus filter logs
4. Note the exact campus strings being compared

### Step 3: Standardize Database
```sql
-- Run in Supabase SQL Editor
UPDATE users
SET campus = TRIM(campus)
WHERE campus IS NOT NULL;

-- Check for variations again
SELECT campus, COUNT(*) 
FROM users 
WHERE campus ILIKE '%purdue%'
GROUP BY campus;
```

### Step 4: Update Frontend (If Needed)
If database standardization isn't enough, apply Solution 2 to make the frontend filter more robust.

## Quick Test

After applying fixes:

1. **Check Database**:
```sql
SELECT DISTINCT campus 
FROM users 
WHERE campus ILIKE '%purdue%';
-- Should return exactly 1 row: "Purdue University"
```

2. **Check App**:
   - Open app
   - Go to Purdue feed
   - Posts should now appear
   - Check Xcode console for "✅ Campus Filter: Including..." messages

## Prevention

To prevent this in the future:

1. **Signup Validation**: Ensure signup only allows exact campus values from an enum
2. **Database Constraint**: Add CHECK constraint to enforce exact campus names
3. **Robust Frontend**: Use case-insensitive, trimmed comparison always

## Code Changes Required

### File 1: `HomeTabView.swift`

Around line 478, change:
```swift
let shouldInclude = userCampus == currentCampus
```

To:
```swift
// Case-insensitive, whitespace-tolerant comparison
let normalizedUserCampus = userCampus.trimmingCharacters(in: .whitespaces).lowercased()
let normalizedCurrentCampus = currentCampus.trimmingCharacters(in: .whitespaces).lowercased()
let shouldInclude = normalizedUserCampus == normalizedCurrentCampus
```

### File 2: `BrowseByCategoryView.swift`

Around line 242, make the same change:
```swift
// Case-insensitive, whitespace-tolerant comparison
let normalizedUserCampus = userCampus.trimmingCharacters(in: .whitespaces).lowercased()
let normalizedCurrentCampus = currentCampus.trimmingCharacters(in: .whitespaces).lowercased()
return normalizedUserCampus == normalizedCurrentCampus
```

## Expected Results

After applying fixes:
- ✅ All Purdue posts from Purdue users will show up
- ✅ Posts won't disappear based on minor string differences
- ✅ Database will have consistent campus names
- ✅ Frontend will handle variations gracefully

**Darragh** - First run `CHECK_CAMPUS_STRINGS.sql` and check your Xcode console logs. Share what you find and we'll apply the right fix.


