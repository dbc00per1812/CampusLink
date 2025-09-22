# 🚀 Push Notifications Action Plan

## Current Status
- ✅ Database schema is ready (notifications & user_notification_preferences tables)
- ✅ Swift implementation complete (NotificationManager & NotificationService)
- ✅ Push entitlements enabled in Xcode
- ✅ Edge function written (but needs Auth Key format)
- ❌ Push tokens not saving to database
- ❌ Edge function not deployed
- ❌ Environment variables not set

## 🔴 Immediate Actions Required

### 1. Test Current Setup (5 minutes)
```bash
# Run this SQL in Supabase to check current state
cd /Users/eileenmurphy/CampusLink
# Copy contents of debug_notifications.sql and run in Supabase SQL editor
```

### 2. Add Test View to App (2 minutes)
Add this to your Settings or Profile view:
```swift
NavigationLink("Push Notification Test", destination: PushNotificationTestView())
```

### 3. Get Apple Push Auth Key (10 minutes)
Since your edge function expects Auth Key format (.p8), not certificate (.p12):

1. Go to: https://developer.apple.com/account/resources/authkeys/add
2. Click "+" to create new key
3. Check "Apple Push Notifications service (APNs)"
4. Download the .p8 file
5. Note the Key ID (10 characters like "ABC123DEF4")

### 4. Set Supabase Environment Variables (5 minutes)
Go to: https://vnmzijluyctlufnzxast.supabase.co/dashboard/settings/functions

Add these variables:
```
BUNDLE_ID = darragh.CampusLink
APNS_TEAM_ID = 39QG7MQD33
APNS_KEY_ID = [Your 10-character Key ID from step 3]
APNS_PRIVATE_KEY = [Paste entire content of .p8 file including headers]
APNS_ENV = sandbox
```

Also get your Service Role Key:
- Go to: https://vnmzijluyctlufnzxast.supabase.co/dashboard/settings/api
- Copy the "service_role" key (starts with eyJ...)

### 5. Deploy Edge Function (5 minutes)
```bash
cd /Users/eileenmurphy/CampusLink

# Install Supabase CLI if not already installed
brew install supabase/tap/supabase

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref vnmzijluyctlufnzxast

# Deploy the function
supabase functions deploy send-push-notification
```

### 6. Configure Database (2 minutes)
Run this SQL in Supabase with your actual service role key:
```sql
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://vnmzijluyctlufnzxast.supabase.co';
ALTER DATABASE postgres SET app.settings.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY_HERE';
```

### 7. Test Push Notifications (5 minutes)
1. Run app on real iPhone (not simulator)
2. Go to Push Notification Test view
3. Click "Request Permissions" and allow
4. Click "Save Token to Database"
5. Click "Test Push Notification"

## 🟡 Alternative: Use OneSignal (If Auth Key doesn't work)

If you can't get an Auth Key or prefer an easier solution:

1. Create free account at https://onesignal.com
2. Add your iOS app
3. Follow their setup guide
4. Update edge function to use OneSignal API
5. No certificates needed!

## 🟢 Quick Win: Test Local Notifications First

While setting up push, you can test with local notifications:
1. Run the app
2. Go to Push Notification Test view
3. Click "Test Local Notification"
4. You'll see a notification in 2 seconds!

## Debugging Checklist

- [ ] Push token appears in Xcode console?
- [ ] Token saved to database? (check with SQL)
- [ ] Edge function deployed?
- [ ] Environment variables set?
- [ ] Testing on real device?
- [ ] User logged in when requesting permissions?

## Common Issues & Fixes

### Issue: Push token not saving
**Fix**: Make sure user is logged in before requesting permissions

### Issue: Edge function fails
**Fix**: Check Supabase function logs for errors

### Issue: No push notifications received
**Fix**: Verify APNS_ENV matches your provisioning (sandbox vs production)

## SQL Commands for Testing

```sql
-- Check if user has push token
SELECT * FROM user_notification_preferences WHERE user_id = 'YOUR_USER_ID';

-- Test notification function
SELECT test_push_notification('YOUR_USER_ID', 'Test', 'Hello from CampusLink!');

-- Check recent notifications
SELECT * FROM notifications ORDER BY created_at DESC LIMIT 10;
```

## Next Steps After Push Works

1. Test message notifications (automatic via trigger)
2. Test order notifications (automatic via trigger)
3. Add notification preferences UI
4. Implement notification center view
5. Add badge count updates

---

**Estimated Total Setup Time: 30 minutes**

Need help? The hardest part is getting the Auth Key from Apple. Everything else is straightforward!
