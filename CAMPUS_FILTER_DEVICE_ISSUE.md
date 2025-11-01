# Campus Filter Not Working on Device - Troubleshooting

## Situation
- ✅ Works correctly on simulator
- ✅ Worked when build was submitted
- ❌ Not working now (on device/TestFlight)

## Root Cause
This is almost certainly a **cached state issue** on your device, not a code problem.

## Fix Steps (Try in Order)

### 1. Force Quit and Reopen App
- Swipe up to app switcher
- Swipe up on CampusLink to force quit
- Reopen the app

### 2. Sign Out and Sign Back In
- Open app → Profile → Settings → Sign Out
- Sign back in with your IU account
- This will reload all user data fresh from Supabase

### 3. Delete App and Reinstall from TestFlight
- Delete CampusLink app from your device
- Go to TestFlight
- Reinstall the latest build
- Sign in again

### 4. Check TestFlight Build Version
Make sure you're running the LATEST build that includes the campus feature:
- Open TestFlight
- Check build number
- If there's an "Update" button, tap it

### 5. Verify Database (Just to be sure)
Go to Supabase Dashboard → Table Editor → `users` table:
- Find your account by email
- Verify `campus` column shows exactly: `Indiana University Bloomington`
- If it shows anything else (like `Purdue University`), that's your problem

## Why This Happens

When you sign up/test on a device:
1. App caches user state in memory
2. If you signed up BEFORE the campus feature was added, old state persists
3. Simulator is clean slate each time (no persistent cache)
4. Device keeps old cached data

## Don't Resubmit If...
- It works on simulator ✅
- Database shows correct campus ✅
- You just need to clear device cache

## DO Resubmit If...
- After trying all fixes above, it still shows wrong campus
- Database shows WRONG campus value
- Simulator also shows wrong campus

## Most Likely Fix
Delete app → Reinstall from TestFlight → Sign in again

This gives you a completely fresh state.

---

**Darragh** - Try deleting the app and reinstalling from TestFlight first. That usually fixes cached state issues. Let me know if it still shows Purdue after that!


