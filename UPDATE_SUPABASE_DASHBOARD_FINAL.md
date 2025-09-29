# Update Supabase Dashboard - In-App OTP Password Reset

## Problem
Web-based password reset pages were problematic due to token expiration and redirect complexity.

## Solution
Use simple in-app OTP password reset flow - no web pages or redirects needed.

## Steps to Update Supabase Dashboard

1. **Go to Supabase Dashboard**: https://supabase.com/dashboard
2. **Navigate to your project**: CampusLink 
3. **Go to Authentication > URL Configuration**
4. **Update Site URL**: 
   ```
   https://supabase.com
   ```
5. **Update Redirect URLs**:
   - Remove any custom URLs
   - Set to: `https://supabase.com`
6. **Click "Save"**

## Important Notes
- These URLs are required by Supabase but **won't actually be used** 
- Our OTP flow is entirely in-app (no web redirects)
- Using `https://supabase.com` as a valid placeholder URL
- For production, you could use your app's real website domain

## What This Does
- Password reset uses OTP codes sent via email
- User enters OTP code + new password directly in the iOS app
- No web redirects or external pages needed
- Simple, reliable, and secure

## How New Flow Works
1. User clicks "Forgot Password?" in app
2. App sends OTP code to user's email via `signInWithOTP`
3. User receives email with 6-digit verification code
4. OTP password reset view appears in app
5. User enters: OTP code + new password + confirm password
6. App verifies OTP and updates password
7. Success! User can login with new password

## Test After Update
1. Go to CampusLink app
2. Click "Forgot Password?"
3. Enter your email
4. Check email for 6-digit code (not a link!)
5. Enter code and new password in the app
6. Should work perfectly without any web pages!
