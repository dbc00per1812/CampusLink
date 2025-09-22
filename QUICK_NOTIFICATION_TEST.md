# 🚀 QUICK NOTIFICATION TEST

## Your Info:
- **Bundle ID**: `darragh.CampusLink`
- **Team ID**: `39QG7MQD33`
- **Supabase Project**: `vnmzijluyctlufnzxast`

## Step 1: Run SQL in Supabase
Go to: https://vnmzijluyctlufnzxast.supabase.co/dashboard/sql

Run this SQL:
```sql
-- 1. Run the notifications schema
-- Copy entire content of test_notifications_schema.sql and run it

-- 2. Then run this simple test
INSERT INTO user_notification_preferences (user_id)
SELECT id FROM auth.users LIMIT 1;
```

## Step 2: Test Local Notifications (No .p12 needed!)
1. Build and run the app on your iPhone
2. Go to any chat
3. Tap the blue bell icon (🔔)
4. You'll see a notification in 2 seconds!

## Step 3: For Real Push Notifications

### Option A: Use OneSignal (EASIEST - No .p12 needed!)
1. Go to https://onesignal.com
2. Create free account
3. Add iOS app
4. Follow their setup guide
5. They handle all the certificate mess

### Option B: Direct APNs (Complex - Uses your .p12)
If you really want to use your .p12 file:

```bash
# 1. Convert .p12 to PEM files
openssl pkcs12 -in CampusLinkPush.p12 -out push_cert.pem -clcerts -nokeys
openssl pkcs12 -in CampusLinkPush.p12 -out push_key.pem -nocerts -nodes

# 2. Test sending a push
curl -v \
  --cert push_cert.pem \
  --key push_key.pem \
  --header "apns-topic: darragh.CampusLink" \
  --header "apns-push-type: alert" \
  --data '{"aps":{"alert":"Test"}}' \
  https://api.push.apple.com/3/device/YOUR_DEVICE_TOKEN
```

## 🎯 My Recommendation:
1. **Test local notifications first** (works now, no setup needed)
2. **Use OneSignal for push** (free, handles certificates for you)
3. **Save the .p12 file** for later if needed

The .p12 file is for sending push notifications directly to Apple's servers, but it's complex. OneSignal or similar services make it MUCH easier.
