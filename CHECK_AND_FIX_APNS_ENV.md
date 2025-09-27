# Fix Push Notifications - APNS Environment

## Quick Check
1. **How did you install the app on your phone?**
   - Via Xcode (Debug) → You need `APNS_ENV=sandbox`
   - Via TestFlight → You need `APNS_ENV=production`
   - Via App Store → You need `APNS_ENV=production`

## To Fix:
Go to **Supabase Dashboard** → **Settings** → **Edge Functions** → **Environment Variables**

Add or update:
```
APNS_ENV = production
```

(or `sandbox` if you're running a debug build from Xcode)

## Why This Happens:
- Debug builds generate sandbox tokens
- Release builds generate production tokens
- Sending a sandbox token to production APNs (or vice versa) results in silent failure
- Apple returns success but never delivers the notification

## After Changing the Environment Variable:
1. No need to redeploy the Edge Function
2. Test John again immediately
3. It should work!

This is the #1 cause of "successful" pushes that never arrive.
