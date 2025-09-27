# URGENT: Push Notifications Broken

## Current Status
- Previously working for John (user_id: 11cf906c-189d-492f-b9da-bf4bf58c371a) 
- Now NOTHING works - even John's previously working setup fails
- All pushes return `"apnsSuccess": false`

## What Changed
1. We updated the Edge Function to extract first 64 chars from tokens
2. We added enhanced logging
3. Possibly APNs credentials expired or were changed

## Immediate Actions Needed

### 1. Check APNs Environment Variables
Go to Supabase Dashboard → Settings → Edge Functions → Environment Variables

Verify these are set:
- `APNS_TEAM_ID` - Your Apple Developer Team ID
- `APNS_KEY_ID` - Your APNs Auth Key ID  
- `APNS_PRIVATE_KEY` - Your APNs private key (base64 encoded)
- `APNS_ENV` - Should be "sandbox" for development
- `BUNDLE_ID` - Should be "darragh.CampusLink"

### 2. Check if APNs Key Expired
- APNs Auth Keys don't expire, but certificates do
- Check if you're using JWT auth (recommended) or certificates

### 3. Revert Edge Function Changes
The token extraction logic might be breaking things. Need to check logs.

### 4. Check Supabase Edge Function Logs
Go to Functions → send-push-direct → Logs
Look for:
- JWT creation errors
- APNs connection errors
- Token format issues

## Most Likely Cause
Since even John's previously working push now fails, either:
1. APNs credentials are missing/wrong in environment variables
2. The Edge Function changes broke the token handling
3. APNs sandbox server is having issues (unlikely)

## Next Step
CHECK THE EDGE FUNCTION LOGS - they will show the exact error!
