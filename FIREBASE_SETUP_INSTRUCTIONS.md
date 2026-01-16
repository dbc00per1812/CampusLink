# Firebase Configuration for Android Push Notifications

## Step 2: Download and Add google-services.json

### Instructions

1. **Go to Firebase Console**
   - Visit: https://console.firebase.google.com/
   - Sign in with your Google account

2. **Select or Create Project**
   - If you already have a Firebase project for CampusLink, select it
   - If not, create a new project:
     - Click "Add project"
     - Name it "CampusLink" (or your preferred name)
     - Follow the setup wizard

3. **Add Android App (if not already added)**
   - Click the Android icon or go to Project Settings
   - Click "Add app" → Select Android
   - Enter package name: `com.darragh.buckley1812.mobile`
   - (This must match the package in mobile/app.json)
   - Click "Register app"

4. **Download google-services.json**
   - After registering the app, click "Download google-services.json"
   - Or go to Project Settings → Your apps → Android app → Download config file

5. **Place the File**
   ```bash
   # Move the downloaded file to:
   /Users/eileenmurphy/CampusLink/mobile/android/app/google-services.json
   ```

6. **Verify Placement**
   ```bash
   # The file should be at:
   mobile/
   └── android/
       └── app/
           └── google-services.json  ← HERE
   ```

### Important Notes

- ✅ The file is already in `.gitignore` - it won't be committed to git
- ✅ This file is required for Android push notifications via FCM
- ✅ iOS doesn't need this file (uses APNs with .p8 key already configured)

### What's in the File

The `google-services.json` contains:
- Firebase project configuration
- API keys for FCM (Firebase Cloud Messaging)
- Client IDs and OAuth settings
- Database URLs

### Verification

Once you place the file, you can verify it's correctly formatted:

```bash
cat mobile/android/app/google-services.json | grep "project_info"
```

You should see project information including your project ID.

### Next Steps

After adding this file:
1. The Android build will automatically use it during `npx expo run:android`
2. FCM will be configured for push notifications
3. Test on a physical Android device to verify notifications work

---

**Status:** File placement pending (requires Firebase Console access)
**Required for:** Android push notifications only
**Already configured:** iOS APNs (.p8 key uploaded to OneSignal)
