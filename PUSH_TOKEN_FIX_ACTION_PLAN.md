# Push Token Fix Action Plan

## The Problem
- 64-character tokens (standard APNs format) are getting 400 errors
- 160-character tokens (non-standard) are working
- This suggests the Edge Function or APNs setup expects a different format

## Immediate Solutions

### Option 1: Quick Fix - Pad the Token (Temporary)
Since John's 160-char token works, we can temporarily make Darragh's token work by padding it:

```sql
-- TEMPORARY FIX - Pad Darragh's token to 160 chars
UPDATE user_notification_preferences
SET push_token = push_token || push_token || SUBSTRING(push_token, 1, 32),
    updated_at = NOW()
WHERE user_id = 'd4c8cd57-c182-4eed-a961-b24651061676';
```

### Option 2: Proper Fix - Update the Edge Function
The Edge Function might be expecting a different token format. We need to:

1. Check if the token needs to be Base64 encoded
2. Check if spaces need to be added
3. Check if the token format changed between iOS versions

### Option 3: Debug the Exact Error
Click on one of the 400 (orange) entries in the Supabase logs to see the exact APNs error. This will tell us:
- "BadDeviceToken" - Wrong format
- "InvalidProviderToken" - Wrong environment 
- Other specific errors

## Next Steps

1. **Run the temporary fix** to get Darragh working immediately
2. **Check the 400 error logs** to understand the root cause
3. **Update the Edge Function** to handle both token formats

## Most Likely Cause
The 160-char token might be the result of double-encoding or concatenation in an older version of the app. The Edge Function might be expecting this format.

Would you like me to:
1. Apply the temporary fix for Darragh?
2. Update the Edge Function to handle both formats?
3. Investigate further in the logs?
