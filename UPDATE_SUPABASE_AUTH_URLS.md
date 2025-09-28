# 🔧 URGENT: Fix Password Reset Redirect URLs

## Problem
Password reset emails redirect to `localhost` which doesn't work on mobile devices.

## Solution
Update Supabase Authentication URL Configuration:

### Step 1: Go to Supabase Dashboard
1. Open your Supabase project dashboard
2. Navigate to `Authentication` → `URL Configuration`

### Step 2: Update URLs
**Site URL:**
```
campuslink://auth
```

**Redirect URLs (add this to the list):**
```
campuslink://auth
```

### Step 3: Save Changes
- Click "Save" to apply the configuration

## What This Fixes
- ✅ Password reset links will now open the CampusLink app directly  
- ✅ Works on all devices (iPhone, Android, etc.)
- ✅ No more "localhost" connection errors
- ✅ Seamless user experience for password recovery

## How It Works
1. User clicks "Forgot Password?" in app
2. Supabase sends reset email with `campuslink://auth` link
3. User clicks email link on their phone
4. Link opens CampusLink app directly
5. App handles the password reset flow automatically

## Test After Update
1. Request password reset from app
2. Check email on phone  
3. Click reset link - should open app directly
4. Complete password reset in app

**Status:** ⏳ WAITING FOR SUPABASE DASHBOARD UPDATE
