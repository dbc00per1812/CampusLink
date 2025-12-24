# OneSignal Push Notifications - Next Steps

## ✅ Completed
- OneSignal SDK installed and configured
- Mobile app code fully implemented
- Backend edge function created
- Deployment scripts ready
- Documentation complete
- All code committed (ready to push)

## 📋 Remaining Steps to Go Live

### Step 1: Download Firebase Config File

1. Go to [Firebase Console](https://console.firebase.google.com/)
2. Select your project (or create one if needed)
3. Go to Project Settings (⚙️ icon)
4. Under "Your apps" section, find your Android app
5. Download `google-services.json`
6. Place it at: `mobile/android/app/google-services.json`
   - This file is already in .gitignore, so it won't be committed

### Step 2: Deploy Backend Edge Function

**Option A: Using the script (easiest)**
```bash
cd /Users/eileenmurphy/CampusLink
./deploy_onesignal_push.sh
```

**Option B: Manual deployment**
```bash
# Set secrets
supabase secrets set ONESIGNAL_APP_ID=cb72afc9-84c6-4cfc-8cc3-64f63d1700c1
supabase secrets set ONESIGNAL_REST_API_KEY=os_v2_app_znzk7smeyzgpzdgdmt3d2fyaygrqwhvvis5ub6e6dzatew45bwht56hbk3ossykighoaexsq3q67qmkrrjb4zwvpaq3hc7bnhdoigey

# Deploy function
supabase functions deploy send-push-onesignal
```

### Step 3: Rebuild Mobile App

OneSignal requires native code, so you need to rebuild:

```bash
cd mobile

# Generate native iOS/Android projects
npx expo prebuild

# For iOS:
npm run ios
# or open ios/mobile.xcworkspace in Xcode and run

# For Android:
npm run android
```

**Note**: You may need to install pods for iOS:
```bash
cd ios
pod install
cd ..
```

### Step 4: Test Push Notifications

**A. Test on Physical Device (Required)**
- Push notifications only work on physical devices
- Simulators/emulators don't support push notifications

**B. Send Test Notification from OneSignal Dashboard**
1. Go to [OneSignal Dashboard](https://dashboard.onesignal.com/)
2. Select your app
3. Go to "Messages" → "New Push"
4. Select "Send to Test Device"
5. Enter your device's player ID (check console logs in app)

**C. Test via Edge Function**
```bash
supabase functions invoke send-push-onesignal --data '{
  "user_id": "your-test-user-uuid",
  "title": "Test Notification",
  "body": "This is a test from Supabase!",
  "data": {
    "type": "test",
    "screen": "Home"
  }
}'
```

**D. Test via SQL**
```sql
SELECT
  net.http_post(
    'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-onesignal',
    jsonb_build_object(
      'user_id', 'your-user-uuid',
      'title', 'Test from SQL',
      'body', 'Testing OneSignal integration'
    ),
    headers:=jsonb_build_object(
      'Authorization', 'Bearer ' || current_setting('app.settings.service_role_key')
    )
  );
```

### Step 5: Update Existing Notification Calls

Find and replace old notification function calls with new OneSignal function:

**Old (Expo/APNs):**
```typescript
await supabase.functions.invoke('send-push-notification', { ... })
await supabase.functions.invoke('process-push-queue', { ... })
```

**New (OneSignal):**
```typescript
await supabase.functions.invoke('send-push-onesignal', {
  body: {
    user_id: userId,
    title: 'Order Update',
    body: 'Your order has been confirmed',
    data: {
      type: 'order_confirmed',
      order_id: orderId,
    },
  }
})
```

### Step 6: Verify in Production

**Check these items:**
- [ ] User can grant notification permissions
- [ ] Player ID saves to database after login
- [ ] Notifications appear when app is in foreground
- [ ] Notifications appear when app is in background
- [ ] Notifications appear when app is closed
- [ ] Tapping notification navigates correctly
- [ ] Badge count updates on iOS
- [ ] User preferences control delivery
- [ ] OneSignal dashboard shows delivery metrics

## 🔍 Debugging Checklist

If notifications aren't working:

1. **Check Device Permissions**
   - iOS: Settings → Your App → Notifications → Allow
   - Android: Should be granted automatically

2. **Check User Preferences**
   ```sql
   SELECT * FROM user_notification_preferences 
   WHERE user_id = 'your-uuid';
   ```
   - Verify `push_enabled = true`
   - Verify `push_token` exists (OneSignal player ID)

3. **Check OneSignal Dashboard**
   - View delivery reports
   - Check for failed deliveries
   - Verify device is registered

4. **Check Edge Function Logs**
   ```bash
   supabase functions logs send-push-onesignal
   ```

5. **Check Mobile App Console**
   - Look for OneSignal initialization logs
   - Check for player ID
   - Verify external user ID is set

## 📱 App Usage

Users will experience:
1. **First Launch**: OneSignal initializes silently
2. **After Login**: Prompt for notification permissions (iOS)
3. **Permission Granted**: Player ID saved to database
4. **Receive Notifications**: Orders, messages, listings, etc.
5. **Tap Notification**: Navigates to relevant screen

## 🚀 Integration Examples

### Send Order Notification
```typescript
await supabase.functions.invoke('send-push-onesignal', {
  body: {
    user_id: sellerId,
    title: 'New Order!',
    body: `${buyerName} placed an order`,
    data: {
      type: 'order_placed',
      order_id: orderId,
    },
    badge: 1,
    priority: 'high',
  }
});
```

### Send Message Notification
```typescript
await supabase.functions.invoke('send-push-onesignal', {
  body: {
    user_id: recipientId,
    title: senderName,
    body: messageText,
    data: {
      type: 'new_message',
      conversation_id: conversationId,
      message_id: messageId,
    },
  }
});
```

## 📊 OneSignal Dashboard

Monitor your notifications:
- **Messages**: View sent notifications
- **Delivery Reports**: See delivery rates, open rates
- **Users**: View registered devices and their segments
- **Settings**: Manage API keys, credentials

## 🎯 Success Metrics

Track these in OneSignal dashboard:
- **Delivery Rate**: % of notifications delivered
- **Open Rate**: % of notifications opened
- **Click-Through Rate**: % that navigate to app
- **User Segments**: Active vs inactive users

## 📝 Documentation References

- **Edge Function**: `supabase/functions/send-push-onesignal/README.md`
- **Deployment Script**: `deploy_onesignal_push.sh`
- **Today's Log**: `logs/2025-12-16.md`
- **Plan**: `.cursor/plans/onesignal_push_notifications_setup_8d7360e4.plan.md`

## ⚠️ Important Notes

- **Physical Devices Only**: Push notifications don't work on simulators
- **Firebase Required**: Android needs google-services.json file
- **APNs Certificate**: iOS needs proper APNs setup in OneSignal dashboard
- **Secrets Security**: Never commit API keys or google-services.json
- **Testing**: Always test on both iOS and Android before production release

## 🤝 Support

- **OneSignal Docs**: https://documentation.onesignal.com/
- **OneSignal Support**: Dashboard → Support
- **Supabase Edge Functions**: https://supabase.com/docs/guides/functions

---

**Ready to deploy!** Follow the steps above in order, and you'll have push notifications working in no time.

