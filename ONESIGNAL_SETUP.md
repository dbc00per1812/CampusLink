# 🚀 OneSignal Push Notifications Setup

## ✅ What I've Done (From IDE):

1. **Created OneSignal Edge Function** (`send-push-onesignal`)
2. **Created OneSignal Swift Service** (`OneSignalService.swift`)
3. **Updated Test View** with OneSignal buttons
4. **Deployed Edge Function** to Supabase

## 🔧 What You Need to Do (5 minutes):

### **Step 1: Create OneSignal Account**
1. Go to: https://onesignal.com
2. **Sign up for free account**
3. **Create new app**:
   - App Name: `CampusLink`
   - Platform: `iOS`
   - Bundle ID: `darragh.CampusLink`

### **Step 2: Get Your Credentials**
1. **App ID**: Found in OneSignal dashboard (looks like: `12345678-1234-1234-1234-123456789012`)
2. **REST API Key**: Found in Settings → Keys & IDs

### **Step 3: Add to Supabase Environment Variables**
Go to: https://vnmzijluyctlufnzxast.supabase.co/dashboard/settings/functions

Add these variables:
- `ONESIGNAL_APP_ID` = `[Your App ID from OneSignal]`
- `ONESIGNAL_API_KEY` = `[Your REST API Key from OneSignal]`

### **Step 4: Test on iPhone**
1. **Build and run** on your iPhone
2. **Go to Settings → Push Notification Test**
3. **Tap "Test OneSignal Push"**
4. **You should get a real push notification!**

## 🎯 **What Works Now:**

- ✅ **OneSignal Edge Function** deployed
- ✅ **Swift integration** ready
- ✅ **Test view** updated
- ✅ **Local notifications** work immediately
- ✅ **OneSignal push** (after you add credentials)

## 📱 **Expected Result:**

After adding your OneSignal credentials, you'll get:
- **Real push notifications** on lock screen
- **Banner notifications** when app is open
- **Badge counts** on app icon
- **Sound alerts**
- **Tap to open** functionality

## 🔄 **Fallback Options:**

If OneSignal doesn't work:
1. **Local notifications** work immediately (no setup needed)
2. **Apple APNs** (what we were debugging) - still available
3. **Firebase** - another alternative

## ⚡ **Why OneSignal is Better:**

- **No Apple certificates** needed
- **10x easier** setup than APNs
- **Better analytics** and delivery tracking
- **Free tier** up to 30,000 users
- **Cross-platform** support

**Ready to add your OneSignal credentials and test?**
