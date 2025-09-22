# 🚀 SIMPLIFIED PUSH NOTIFICATION SETUP

Since you already have the .p12 file and Supabase credentials, here's what you need to do:

## 📋 Your Info:
- **Bundle ID**: `darragh.CampusLink` ✅
- **Supabase URL**: `https://vnmzijluyctlufnzxast.supabase.co` ✅
- **Supabase Anon Key**: Already in Secrets.swift ✅

## 🔧 What You Still Need:

### 1. **Your Apple Team ID**
- Go to: https://developer.apple.com/account
- Look for your Team ID (10 characters like `ABC123DEF4`)
- It's usually shown in the top right or under Membership

### 2. **Your Supabase Service Role Key**
- Go to: https://vnmzijluyctlufnzxast.supabase.co/dashboard/settings/api
- Scroll down to "Service role key"
- Copy it (starts with `eyJ...`)

### 3. **Convert Your .p12 to Base64**
Since you can't directly upload the .p12 to Supabase Edge Functions, convert it:

```bash
# Convert .p12 to base64 (replace with your actual file name)
base64 -i CampusLinkPush.p12 -o push_cert_base64.txt

# View the content (you'll paste this in Supabase)
cat push_cert_base64.txt
```

## 🚀 Quick Setup Steps:

### 1. **Set Supabase Environment Variables**
Go to: https://vnmzijluyctlufnzxast.supabase.co/dashboard/settings/functions

Add these environment variables:
- `BUNDLE_ID` = `darragh.CampusLink`
- `APPLE_TEAM_ID` = Your 10-character Team ID
- `PUSH_CERT_BASE64` = Content of push_cert_base64.txt
- `PUSH_CERT_PASSWORD` = Password you set when exporting .p12

### 2. **Deploy the Edge Function**
```bash
cd /Users/eileenmurphy/CampusLink

# Login to Supabase
supabase login

# Link to your project
supabase link --project-ref vnmzijluyctlufnzxast

# Deploy the function
supabase functions deploy send-push-notification
```

### 3. **Run the SQL Files**
In your Supabase SQL editor:

1. Run `test_notifications_schema.sql`
2. Run `message_notification_trigger.sql`
3. Run this to set config:
```sql
ALTER DATABASE postgres SET app.settings.supabase_url = 'https://vnmzijluyctlufnzxast.supabase.co';
ALTER DATABASE postgres SET app.settings.supabase_service_role_key = 'YOUR_SERVICE_ROLE_KEY_HERE';
```

### 4. **Enable Push in Xcode**
✅ Already done (I can see it in your screenshot)

### 5. **Test on Real Device**
- Build and run on your iPhone
- Allow notifications
- Send a message to another user
- See the push notification!

## 🧪 Test Command:
```bash
# Replace USER_UUID with an actual user ID from your database
curl -X POST 'https://vnmzijluyctlufnzxast.supabase.co/functions/v1/send-push-notification' \
  -H 'Authorization: Bearer eyJhbGciOiJIUzI1NiIsInR5cCI6IkpXVCJ9.eyJpc3MiOiJzdXBhYmFzZSIsInJlZiI6InZubXppamx1eWN0bHVmbnp4YXN0Iiwicm9sZSI6ImFub24iLCJpYXQiOjE3NTM1Njk5MTksImV4cCI6MjA2OTE0NTkxOX0.9_MrimvbcH8zZXrEL-M-XEL2oI5C8XD1yH6anwKyuSw' \
  -H 'Content-Type: application/json' \
  -d '{"user_id": "USER_UUID", "title": "Test", "body": "Push notification test!"}'
```
