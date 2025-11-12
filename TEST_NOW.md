# Test Diversification Right Now

## Step 1: Check Your Data (30 seconds)

Run `CHECK_DIVERSIFICATION.sql` in Supabase SQL Editor.

**It will tell you:**
- ✅ If you have enough listings (need 5+)
- ✅ If you have enough variety (need 3+ categories)
- ✅ What categories you have

**If it says "NOT ENOUGH LISTINGS":**
- Diversification won't trigger
- You need to create more test listings

**If it says "LIMITED VARIETY":**
- All your listings might be in same category
- Diversification works but won't look different
- Create listings in different categories to test

---

## Step 2: Test in App (1 minute)

1. **Build and run the app**
2. **Open home feed (For You tab)**
3. **Look at Xcode console** - you should see:

```
🔍 Diversification check:
   useDiversification: true
   isSearchActive: false
   currentPage: 0
   baseListings.count: 20

✅ Applying diversification...

📊 Diversification: 4 listings selected
   Products: 3
   Services: 1
   Categories: 3 unique
```

**If you see:**
- "⏭️ Skipping diversification" = Conditions not met (not enough listings)
- "✅ Applying diversification" = It's working!

---

## Step 3: Visual Check

Look at the first 4 listings on your home feed.

**Before diversification:**
- Might be: Electronics, Electronics, Electronics, Electronics

**After diversification:**
- Should be: Electronics, Books, Furniture, Tutoring (example)

**If they're all the same category:**
- Your test data probably only has one category
- The code is working, but data isn't varied enough to show it

---

## Quick Test:

What does `CHECK_DIVERSIFICATION.sql` show?
- How many total listings?
- How many unique categories?
- What are the categories?

Tell me that and I'll confirm if diversification should be visible or not.

