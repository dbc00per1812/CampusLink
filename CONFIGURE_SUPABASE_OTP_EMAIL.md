# Configure Supabase to Send OTP Codes in Email

## Problem
Password reset emails are sending clickable links instead of OTP codes for in-app entry.

## Solution
Configure Supabase email template to show the OTP code directly in the email.

## Steps to Configure Supabase Dashboard

### 1. Update Email Template
1. **Go to Supabase Dashboard**: https://supabase.com/dashboard
2. **Navigate to your project**: CampusLink
3. **Go to Authentication > Email Templates**
4. **Select "Reset Password" template**
5. **Edit the email content** to include:

```html
<h2>Reset Your CampusLink Password</h2>
<p>You requested a password reset for your CampusLink account.</p>
<p><strong>Your password reset code is: {{ .Token }}</strong></p>
<p>Enter this code in the CampusLink app to reset your password.</p>
<p>This code will expire in 1 hour.</p>
<p>If you didn't request this, please ignore this email.</p>
```

6. **Click "Save"**

### 2. Update URL Configuration (if not done already)
1. **Go to Authentication > URL Configuration**
2. **Set Site URL**: `https://supabase.com`
3. **Set Redirect URLs**: `https://supabase.com`
4. **Click "Save"**

## What This Does
- Email will show the 6-digit OTP code directly (like: **123456**)
- User can copy/type the code into the app
- No clickable links that would open browsers
- Perfect for in-app password reset flow

## Test After Configuration
1. Request password reset in app
2. Check email for **6-digit code** (not a link!)
3. Enter code in app's OTP screen
4. Reset password successfully

## Expected Email Content
Instead of "Click here to reset", user will see:
```
Your password reset code is: 123456
```

Perfect for in-app OTP entry! 🎯
