# Missing Posts Analysis - Purdue Listings

## Issue Overview
Certain Purdue posts are not showing on the Purdue home feed despite being in the database.

## All Purdue Listings in Database (30 total)

### ✅ SHOWING in App (14 listings):
1. ✅ "Vintage Chevy pullover" - $15 (Isaiah Swider - e1cefac0...)
2. ✅ "Purdue vs Evansville game SS" - $30 (Hope Howard - 151b30c7...)
3. ✅ "Oakley aviator glasses" - $20 (Isaiah Swider - e1cefac0...)
4. ✅ "Longsleeve Nike running shirt" - $10 (Isaiah Swider - e1cefac0...)
5. ✅ "Vintage Nike shirt" - $15 (Isaiah Swider - e1cefac0...)
6. ✅ "IU and ohio state football student section" - $20 (Alex Kelley - 6cda4a46...)
7. ✅ "Evansville basketball ss ticket" - $25 (Declan Motherway - 1ce58ab4...)
8. ✅ "Ohio State Football ticket Student Section" - $25 (Faith McDevitt - 0c05ecc2...)
9. ✅ "Batch urban bike - Gray M" - $500 (Gabriel Fernandez - 8bc69957...)
10. ✅ "Ohio State @ Purdue Football" - $40 (Mateo Barriocanal - 8cd6f08c...)
11. ✅ "Purdue vs Evansville ticket" - $20 (Siva Avudaiappan - dff15a3a...)
12. ✅ "Purdue vs Ohio State SS" - $25 (Gabriel Fernandez - 8bc69957...)
13. ✅ "Guinness Sign" - $30 (Elle Mae - 0030536e...)
14. ✅ "Timberland Size 11 Men's - Wheat" - $120 (Gabriel Fernandez - 8bc69957...)

### ❌ NOT SHOWING in App (16 listings):

#### From Leo Cavalier (user_id: 39b8a95a-d2c5-4641-b44e-2541ac2682f6) - 6 listings:
1. ❌ "Guitar Lesson" - $20 (service) - created: 2025-11-03 17:41:10
2. ❌ "Linen button up T" - $12 (product) - created: 2025-11-03 17:43:44
3. ❌ "Blender (Oster)" - $25 (product) - created: 2025-11-03 17:45:47
4. ❌ "LUMIX GH2 Camera" - $120 (product) - created: 2025-11-03 17:31:20
5. ❌ "Fan" - $18 (product) - created: 2025-11-03 17:34:35

#### From Sanjay Jaikaran (user_id: 82b262d2-4796-4798-b94d-1c14d33c53bc) - 9 listings:
6. ❌ "Barstool Golf Sweatshirt" - $80 (product) - created: 2025-11-03 17:54:03
7. ❌ "Duncan Keith Playoff Jersey" - $100 (product) - created: 2025-11-03 17:58:10
8. ❌ "Chicago White Sox Shorts" - $100 (product) - created: 2025-11-03 18:01:09
9. ❌ "Chicago Blackhawks Hoodie" - $80 (product) - created: 2025-11-03 17:51:56
10. ❌ "Walter Peyton Stitched Jersey/Hoodie hybrid" - $60 (product) - created: 2025-11-03 17:55:28
11. ❌ "JFK Assassination newspaper clipping" - $300 (product) - created: 2025-11-03 17:57:30
12. ❌ "Chicago Irish Blackhawks Jersey" - $120 (product) - created: 2025-11-03 17:53:27
13. ❌ "Chicago Bears Jersey" - $50 (product) - created: 2025-11-03 17:52:50

#### From Others:
14. ❌ "Purdue vs OSU" - $25 (Renato Machado - eac1b82c...) - created: 2025-11-04 03:16:54
15. ❌ "Name" - $3 (Jim John - f74d6ffd...) - created: 2025-10-28 03:05:02

## Key Findings

### Pattern 1: User-Specific Issue
- **Leo Cavalier** has 6 listings that aren't showing (but is from Purdue)
- **Sanjay Jaikaran** has 9 listings that aren't showing (but is from Purdue)
- Both users' listings meet all criteria (active, not archived, not sold)

### Pattern 2: Limit Issue
- The `loadAllListings()` function uses `.limit(20)` 
- The database returns only the **first 20 listings** ordered by `created_at DESC` (newest first)
- After campus filtering, the user may see fewer than 20 listings

### Pattern 3: Timing Analysis
Looking at creation times of SHOWING vs NOT SHOWING:

**SHOWING listings** (more recent):
- 2025-11-04 23:11:30 (A100 Final Exam Tutoring)
- 2025-11-04 13:29:42 (Evansville basketball ss ticket)
- 2025-11-04 03:58:10 (Purdue vs Evansville game SS)
- 2025-11-04 03:05:50 (Ohio State Football ticket)
- 2025-11-04 02:50:39 (Purdue vs Ohio State SS)
- 2025-11-04 02:49:14 (Batch urban bike)
- 2025-11-04 02:48:38 (Purdue vs Evansville ticket)
- 2025-11-04 02:47:17 (Timberland Size 11)
- 2025-11-03 22:29:56+ (Various from Isaiah Swider)
- 2025-11-03 21:22:03 (Guinness Sign)

**NOT SHOWING listings** (older):
- 2025-11-03 17:31:20 to 18:01:09 (Leo Cavalier and Sanjay listings)
- 2025-10-28 03:05:02 (Name listing from Jim John)

## Root Cause

The issue is the **LIMIT 20** constraint combined with:
1. Many listings were created after Leo and Sanjay's posts
2. The database query fetches the 20 most recent listings across ALL campuses
3. Campus filtering is applied AFTER fetching, not BEFORE
4. This means if there are many recent listings from other campuses, Purdue listings get pushed out

### Current Flow:
```
1. Fetch 20 newest listings (all campuses) ❌ PROBLEM HERE
2. Apply campus filter (removes non-Purdue)
3. User sees <20 Purdue listings
```

### Should Be:
```
1. Fetch listings filtered by campus ✅
2. Limit to 20
3. User sees 20 Purdue listings
```

## Solution

Move the campus filtering from client-side to server-side (database query level).

Currently the code does:
```swift
let result: [ListingWithUser] = try await supabase
    .from("listings")
    .select("*, user:users(*)")
    .eq("status", value: "active")
    .neq("archived", value: true)
    .eq("is_sold", value: false)
    .order("created_at", ascending: false)
    .limit(20)  // ← Gets 20 from ALL campuses
    .execute()
    .value

// Then filters client-side
var filteredResult = await applyCampusFilter(result)
```

Should do:
```swift
// Filter by campus AT THE DATABASE LEVEL
let result: [ListingWithUser] = try await supabase
    .from("listings")
    .select("*, user:users!inner(*)")  // inner join
    .eq("status", value: "active")
    .neq("archived", value: true)
    .eq("is_sold", value: false)
    .eq("users.campus", value: currentUserCampus)  // ← Filter in query
    .order("created_at", ascending: false)
    .limit(20)  // ← Now gets 20 Purdue listings
    .execute()
    .value
```

## Recommended Fix

Update all three listing load functions:
1. `loadAllListings()`
2. `loadOfferListings()`
3. `loadSeekListings()`

Add campus filter to the Supabase query before the limit is applied.

