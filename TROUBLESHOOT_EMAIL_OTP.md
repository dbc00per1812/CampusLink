# Email OTP Troubleshooting Guide

## Issue: Email confirmation code not arriving for some testers

### Quick Diagnosis Steps

#### 1. Check Supabase Email Logs
**Action:** Go to Supabase Dashboard → Logs → Select "Auth" logs
- Look for email send events
- Check if emails were actually sent to both addresses
- Look for any error messages

#### 2. Verify Rate Limits
**Problem:** Supabase Free tier = 3 emails/hour
**Solution:**
- Wait 1 hour between test attempts
- OR upgrade to Supabase Pro ($25/month) for 100 emails/hour
- OR use custom SMTP provider

**Check current usage:**
```
Supabase Dashboard → Settings → Usage → Auth section
```

#### 3. Check if User Already Exists
**Problem:** Supabase won't send duplicate signup emails
**Solution:**
```sql
-- Run in Supabase SQL Editor
SELECT email, email_confirmed_at 
FROM auth.users 
WHERE email = 'tester@university.edu';
```

If user exists:
- Delete from: Supabase Dashboard → Authentication → Users
- OR use your `delete_all_users.sql` script

#### 4. Verify Email Template Configuration
**Location:** Supabase Dashboard → Authentication → Email Templates → "Confirm signup"

**Required content:**
```html
<h2>Confirm your signup</h2>

<p>Your verification code is:</p>
<h1>{{ .Token }}</h1>

<p>This code expires in 1 hour.</p>
```

**Common mistakes:**
- Missing `{{ .Token }}` - code won't display
- Using `{{ .ConfirmationURL }}` - shows link instead of code

#### 5. Test Email Delivery by Provider
Some .edu domains block emails from Supabase's shared infrastructure.

**Test different providers:**
- Gmail (.edu forwards) - Usually works ✅
- Microsoft/Outlook .edu - Sometimes blocked ⚠️
- University-specific systems - Often strict ❌

**Ask tester to check:**
- Spam/Junk folder
- Quarantine (some universities have this)
- Email filtering rules
- IT department blocks

#### 6. Check Supabase Project Settings
**Location:** Supabase Dashboard → Authentication → Settings

**Verify:**
- ✅ "Enable email confirmations" = ON
- ✅ "Mailer autoconfirm" = OFF (should be disabled)
- ✅ OTP expiry = 3600 seconds (1 hour)
- ✅ OTP length = 6

#### 7. Use Custom SMTP (Recommended for Production)
Supabase's default email service is unreliable for production.

**Better alternatives:**
- **SendGrid** - 100 free emails/day
- **Postmark** - 100 free emails/month
- **AWS SES** - Very cheap, reliable
- **Resend** - Modern, developer-friendly

**Setup:** Supabase Dashboard → Project Settings → Auth → SMTP Settings

---

## Quick Fixes

### Fix 1: Wait and Retry (Rate Limit)
```
1. Wait 1 full hour
2. Have tester try signup again
3. Check email within 5 minutes
```

### Fix 2: Delete Existing User
```
1. Supabase Dashboard → Authentication → Users
2. Find tester's email
3. Click "..." → Delete user
4. Try signup again immediately
```

### Fix 3: Use Different Email
```
1. Try with Gmail account (for testing)
2. If Gmail works → problem is with .edu provider
3. Contact university IT or use SMTP provider
```

### Fix 4: Check App Logs
Add temporary logging to see what's happening:

In `SignUpView.swift`, line 219, the app logs:
```swift
print("✅ Sign-up successful! Email confirmation required.")
```

**If you see this log** → Supabase received the request successfully
**If you don't see this log** → Problem is in the app/auth flow

---

## Real-Time Testing Checklist

Run this with your tester:

```
□ Open Supabase Dashboard → Logs → Auth logs (keep open)
□ Tester enters email and clicks "Create Account"
□ Watch logs in real-time for email send event
□ Email send event appears → Check spam/junk folder
□ No email send event → Check rate limits or user already exists
□ Email arrives but no code → Check email template configuration
```

---

## Production Recommendations

For production launch, you MUST:

1. **Use Custom SMTP Provider** (not Supabase default)
   - Supabase's email service is NOT production-ready
   - Rate limits are too strict
   - Delivery is unreliable
   - No detailed delivery logs

2. **Monitor Email Delivery**
   - Track successful sends
   - Track failures and bounces
   - Alert on delivery issues

3. **Have Fallback Options**
   - SMS verification (Twilio)
   - Manual verification by admin
   - Support email for issues

4. **Test with Multiple Universities**
   - Different .edu domains have different policies
   - Some block transactional emails entirely
   - Test early with target users

---

## Most Likely Solution for Your Issue

Based on your description (worked for you, not for tester):

**DIAGNOSIS:** Rate limiting (you used 3 emails, tester's didn't send)

**IMMEDIATE FIX:**
1. Wait 1 hour
2. Try again

**LONG-TERM FIX:**
1. Set up custom SMTP provider (SendGrid free tier is perfect)
2. Configure in Supabase
3. Test with both users
4. Deploy to production

---

## Need More Help?

Check these Supabase-specific issues:
- https://supabase.com/docs/guides/auth/auth-smtp
- https://github.com/supabase/auth/issues (known email issues)
- Supabase Discord support channel

