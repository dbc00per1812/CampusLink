# Connect Onboarding Function - All Fixes Applied

## Summary of Issues Fixed

### 1. ✅ Missing Column: `full_name` → `name`
**Error**: `column users.full_name does not exist`
**Fix**: Changed query to use `name` column instead

### 2. ✅ Missing Column: `updated_at`
**Error**: `Could not find the 'updated_at' column of 'users' in the schema cache`
**Fix**: Removed all `updated_at` references from database updates

### 3. ✅ Stripe API: Mutually Exclusive Parameters
**Error**: `The collect and collection_settings parameters are mutually exclusive`
**Fix**: Removed `collection_options`, kept only `collect`

## Files Modified

**supabase/functions/connect_onboarding/index.ts**
- Line 86: Changed `full_name` → `name`
- Line 139: Removed `updated_at` field
- Lines 195-200: Removed `collection_options` parameter

## Next Steps

**Redeploy the function in Supabase:**

1. Go to Supabase Dashboard → Edge Functions → `connect_onboarding`
2. Copy the updated code from:
   ```
   /Users/eileenmurphy/CampusLink/supabase/functions/connect_onboarding/index.ts
   ```
3. Paste it in the Supabase editor
4. Click **Deploy**
5. Test "Complete Payout Setup" in your app

**OR** use Supabase CLI:
```bash
cd /Users/eileenmurphy/CampusLink
supabase functions deploy connect_onboarding
```

## Expected Result

After redeployment:
- ✅ Function queries correct database columns
- ✅ Stripe API accepts account link creation
- ✅ Database updates succeed
- ✅ Users can complete payout setup
- ✅ Onboarding flow redirects to Stripe successfully

## Test the Fix

1. Open your app
2. Go to Wallet
3. Click "Complete Payout Setup"
4. Should open Stripe onboarding page (not error)
5. Complete the onboarding in Stripe
6. Return to app - payout setup complete!

---

**All code fixes are complete and ready to deploy!**

