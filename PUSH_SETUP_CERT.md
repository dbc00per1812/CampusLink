# 🚀 Push Notification Setup with Certificate (.p12)

## Current Status
You have a .p12 certificate file (CampusLinkPush.p12) for push notifications. The edge function expects Auth Key (.p8) format, so we need to either:
1. Convert your certificate setup
2. Get an Auth Key from Apple Developer
3. Use a third-party service

## Option 1: Convert .p12 to PEM Files (Immediate Solution)

### Step 1: Extract Certificate and Key
```bash
# Extract certificate
openssl pkcs12 -in CampusLinkPush.p12 -out push_cert.pem -clcerts -nokeys

# Extract private key
openssl pkcs12 -in CampusLinkPush.p12 -out push_key.pem -nocerts -nodes

# Convert both to base64 for Supabase
base64 -i push_cert.pem -o cert_base64.txt
base64 -i push_key.pem -o key_base64.txt
```

### Step 2: Test Push Locally
```bash
# Test with your device token
curl -v \
  --cert push_cert.pem \
  --key push_key.pem \
  --header "apns-topic: darragh.CampusLink" \
  --header "apns-push-type: alert" \
  --data '{"aps":{"alert":{"title":"Test","body":"Hello from CampusLink"}}}' \
  https://api.sandbox.push.apple.com/3/device/YOUR_DEVICE_TOKEN
```

### Step 3: Implement Certificate-Based Push
Since Supabase Edge Functions can't directly use certificate auth, you'll need:
- Use a proxy service that handles certificate auth
- Or implement a simple Node.js backend service
- Or use a third-party service (recommended)

## Option 2: Get Auth Key from Apple (Recommended)

### Step 1: Create Auth Key
1. Go to https://developer.apple.com/account/resources/authkeys/add
2. Select "Apple Push Notifications service (APNs)"
3. Download the .p8 file
4. Note your Key ID (10 characters)

### Step 2: Set Supabase Environment Variables
Go to: https://vnmzijluyctlufnzxast.supabase.co/dashboard/settings/functions

Add these:
- `BUNDLE_ID` = `darragh.CampusLink`
- `APNS_TEAM_ID` = `39QG7MQD33`
- `APNS_KEY_ID` = Q3VU4ZW8CQ
- `APNS_PRIVATE_KEY` = Content of .p8 file (paste the entire key including headers)
- `APNS_ENV` = `sandbox` (change to `production` for App Store)

### Step 3: Deploy Edge Function
```bash
cd /Users/eileenmurphy/CampusLink
supabase functions deploy send-push-notification
```

## Option 3: Use a Third-Party Service (Easiest)

### OneSignal Setup (Free)
1. Create account at https://onesignal.com
2. Add iOS app with your Bundle ID
3. They handle certificates for you
4. Update your edge function to use OneSignal API

### Modified Edge Function for OneSignal:
```typescript
// In send-push-notification/index.ts
const ONESIGNAL_APP_ID = Deno.env.get('ONESIGNAL_APP_ID')
const ONESIGNAL_API_KEY = Deno.env.get('ONESIGNAL_API_KEY')

const response = await fetch('https://onesignal.com/api/v1/notifications', {
  method: 'POST',
  headers: {
    'Authorization': `Basic ${ONESIGNAL_API_KEY}`,
    'Content-Type': 'application/json'
  },
  body: JSON.stringify({
    app_id: ONESIGNAL_APP_ID,
    include_player_ids: [userPrefs.push_token],
    headings: { en: title },
    contents: { en: body },
    data: data
  })
})
```

## Quick Test: Local Notifications (Works Now!)

While you set up push notifications, test with local notifications:

```swift
// In ChatView or any view
Button(action: {
    let content = UNMutableNotificationContent()
    content.title = "Test Notification"
    content.body = "Push notifications will work soon!"
    content.sound = .default
    
    let trigger = UNTimeIntervalNotificationTrigger(timeInterval: 2, repeats: false)
    let request = UNNotificationRequest(identifier: UUID().uuidString, content: content, trigger: trigger)
    
    UNUserNotificationCenter.current().add(request)
}) {
    Label("Test Notification", systemImage: "bell")
}
```

## Current Issues to Fix:

1. **Push Token Not Saving**: The Swift code gets the token but might not be saving it to Supabase
2. **Edge Function Not Deployed**: Need to deploy the push notification function
3. **Missing Environment Variables**: Need to set up Supabase env vars

## Next Steps:

1. **Check if push token is being saved**:
   ```sql
   SELECT user_id, push_token, push_enabled 
   FROM user_notification_preferences 
   WHERE push_token IS NOT NULL;
   ```

2. **Deploy edge function** (after choosing auth method)
3. **Test push notifications** on real device

## Debugging Tips:

1. **Check console logs** in Xcode for push token
2. **Verify entitlements** in CampusLink.entitlements (already done ✅)
3. **Test on real device** (simulator doesn't support push)
4. **Check Supabase logs** for edge function errors
