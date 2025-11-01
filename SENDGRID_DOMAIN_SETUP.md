# SendGrid Domain Authentication Setup

## Problem
Using `darragh.b3272@gmail.com` as sender email causes deliverability issues:
- ❌ Gmail doesn't allow third-party sending (SPF/DMARC failures)
- ❌ Universities block as potential phishing/spoofing
- ❌ Low trust score from email providers
- ❌ Looks unprofessional

## Solution
Set up a custom domain with proper email authentication (SPF, DKIM, DMARC).

---

## Step 1: Get a Domain (If You Don't Have One)

### Option A: Purchase Domain
**Recommended registrars:**
- **Namecheap** - ~$10/year (.com)
- **Google Domains** (now Squarespace) - ~$12/year
- **Cloudflare** - ~$10/year (at cost pricing)

**Domain suggestions:**
- `campuslink.com` (if available)
- `getcampuslink.com`
- `mycampuslink.com`
- `campuslink.app`

### Option B: Use Existing Domain
If you already own a domain, use that!

---

## Step 2: Set Up Domain Authentication in SendGrid

### 2.1 Access Domain Authentication
1. Log in to SendGrid: https://app.sendgrid.com
2. Go to **Settings** → **Sender Authentication**
3. Click **Authenticate Your Domain**

### 2.2 Configure Domain
1. **DNS Host:** Select your domain registrar (Namecheap, Cloudflare, etc.)
2. **Domain:** Enter your domain (e.g., `campuslink.com`)
3. **Use Subdomain:** ✅ YES (recommended)
   - This uses `em.campuslink.com` for sending
   - Doesn't affect your main domain's email
4. **Brand Links:** ✅ Enable (for click tracking)
5. Click **Next**

### 2.3 Add DNS Records
SendGrid will show you DNS records to add. You'll get something like:

**CNAME Records to Add:**
```
Host: em3762.campuslink.com
Value: u12345.wl123.sendgrid.net

Host: s1._domainkey.campuslink.com
Value: s1.domainkey.u12345.wl123.sendgrid.net

Host: s2._domainkey.campuslink.com
Value: s2.domainkey.u12345.wl123.sendgrid.net
```

**How to Add DNS Records:**

#### For Namecheap:
1. Go to Namecheap dashboard
2. Click **Domain List** → Select your domain
3. Click **Advanced DNS**
4. Click **Add New Record**
5. For each record:
   - Type: CNAME
   - Host: (the host value from SendGrid)
   - Value: (the value from SendGrid)
   - TTL: Automatic
6. Click **Save all changes**

#### For Cloudflare:
1. Go to Cloudflare dashboard
2. Select your domain
3. Click **DNS** → **Records**
4. Click **Add record**
5. For each record:
   - Type: CNAME
   - Name: (the host value from SendGrid)
   - Target: (the value from SendGrid)
   - Proxy status: DNS only (gray cloud)
6. Click **Save**

### 2.4 Verify Domain in SendGrid
1. Wait 5-10 minutes for DNS propagation
2. Return to SendGrid → **Sender Authentication**
3. Click **Verify** next to your domain
4. ✅ Should show "Verified" with green checkmark

---

## Step 3: Create Sender Identity

### 3.1 Set Up Sender
1. SendGrid → **Settings** → **Sender Authentication**
2. Click **Create New Sender**
3. Fill in details:
   ```
   From Name: CampusLink
   From Email: noreply@campuslink.com
   Reply To: support@campuslink.com (optional)
   Company Name: CampusLink
   Address: Your business address
   City/State/Zip: Your location
   Country: United States
   ```
4. Click **Create**
5. **Verify email** - SendGrid sends verification to noreply@campuslink.com

### 3.2 Handle Verification Email
You need to receive email at `noreply@campuslink.com` to verify it.

**Quick Fix - Forward to Gmail:**
1. In your domain DNS settings, add:
   ```
   Type: MX
   Host: @ (or campuslink.com)
   Value: gmr-smtp-in.l.google.com
   Priority: 1
   ```
2. Set up Gmail forwarding OR use email forwarding from your registrar

**Better Option - Use Gmail Workspace (Free for 1 user):**
- OR just use ImprovMX (free email forwarding): https://improvmx.com
  - Add domain
  - Forward `noreply@campuslink.com` → `darragh.b3272@gmail.com`
  - Instant setup, no DNS complexity

---

## Step 4: Update Supabase Configuration

### 4.1 Update Sender Email
In your current Supabase SMTP settings screen:

**Change:**
```
Sender email: darragh.b3272@gmail.com
Sender name: CampusLink
```

**To:**
```
Sender email: noreply@campuslink.com
Sender name: CampusLink
```

### 4.2 Test Configuration
1. Click **Save changes** in Supabase
2. In Supabase, click **Send test email**
3. Enter your test .edu email address
4. Check if email arrives (inbox, not spam)

---

## Step 5: Set Up DMARC (Important!)

DMARC tells email providers how to handle emails that fail authentication.

**Add this DNS record to your domain:**
```
Type: TXT
Host: _dmarc
Value: v=DMARC1; p=none; rua=mailto:darragh.b3272@gmail.com
TTL: 1 Hour
```

**What this does:**
- `p=none` - Don't reject emails yet (monitoring mode)
- `rua=mailto:...` - Send reports to your email
- After a week of monitoring, change `p=none` to `p=quarantine` or `p=reject`

---

## Step 6: Optimize Email Content

Even with proper authentication, content matters:

### Update Email Templates in Supabase
**Location:** Supabase Dashboard → Authentication → Email Templates

**For "Confirm signup" template:**
```html
<!DOCTYPE html>
<html>
<head>
    <meta charset="UTF-8">
    <meta name="viewport" content="width=device-width, initial-scale=1.0">
</head>
<body style="font-family: -apple-system, BlinkMacSystemFont, 'Segoe UI', Roboto, sans-serif; line-height: 1.6; color: #333; max-width: 600px; margin: 0 auto; padding: 20px;">
    
    <div style="background: linear-gradient(135deg, #667eea 0%, #764ba2 100%); padding: 30px; text-align: center; border-radius: 10px 10px 0 0;">
        <h1 style="color: white; margin: 0; font-size: 28px;">Welcome to CampusLink!</h1>
    </div>
    
    <div style="background: #ffffff; padding: 40px; border: 1px solid #e0e0e0; border-top: none; border-radius: 0 0 10px 10px;">
        <h2 style="color: #333; margin-top: 0;">Verify Your Email Address</h2>
        
        <p style="font-size: 16px; color: #555;">
            Thanks for signing up! To complete your registration, please enter this verification code in the app:
        </p>
        
        <div style="background: #f5f5f5; border: 2px dashed #667eea; border-radius: 8px; padding: 20px; text-align: center; margin: 30px 0;">
            <p style="font-size: 14px; color: #666; margin: 0 0 10px 0;">Your Verification Code</p>
            <p style="font-size: 36px; font-weight: bold; color: #667eea; letter-spacing: 8px; margin: 0; font-family: 'Courier New', monospace;">
                {{ .Token }}
            </p>
        </div>
        
        <p style="font-size: 14px; color: #888;">
            This code expires in 1 hour.
        </p>
        
        <p style="font-size: 14px; color: #888; margin-top: 30px;">
            If you didn't create a CampusLink account, you can safely ignore this email.
        </p>
    </div>
    
    <div style="text-align: center; padding: 20px; color: #888; font-size: 12px;">
        <p>CampusLink - Campus Marketplace</p>
        <p>This is an automated message, please do not reply.</p>
    </div>
    
</body>
</html>
```

**Key improvements:**
- Professional HTML formatting
- Clear call-to-action
- No suspicious links
- Brand consistent
- Plain text alternative (add separately)

---

## Step 7: Additional Deliverability Tips

### Monitor Sender Reputation
1. SendGrid Dashboard → **Email Activity**
2. Watch for bounces, spam reports
3. Keep bounce rate < 5%
4. Keep spam complaint rate < 0.1%

### Warm Up Your Domain
For the first week:
- Start with low volume (< 100 emails/day)
- Gradually increase volume
- This builds IP/domain reputation

### Test with Multiple Universities
Different .edu domains have different policies:
- Test with 3-5 different universities
- Some are stricter than others
- Document which ones have issues

### Add Unsubscribe Option
Even for transactional emails, consider adding:
```html
<p style="font-size: 11px; color: #999;">
    <a href="{{ .SiteURL }}/unsubscribe">Manage email preferences</a>
</p>
```

---

## Alternative: SMS Verification Backup

If email still has issues with some schools, add SMS as backup:

### Using Twilio (Recommended)
```swift
// Add to your project
import Twilio

class SMSVerificationService {
    func sendVerificationSMS(phone: String, code: String) async throws {
        // Implement Twilio SMS sending
    }
}
```

**Cost:** ~$0.01 per SMS (very cheap)
**Benefit:** 99.9% delivery rate, no spam filters

---

## Timeline & Costs

### Setup Time:
- Domain purchase: 10 minutes
- DNS configuration: 20 minutes
- SendGrid setup: 15 minutes
- Supabase update: 5 minutes
- Testing: 30 minutes
**Total: ~1.5 hours**

### Ongoing Costs:
- Domain: ~$10-12/year
- SendGrid: Free tier (100 emails/day) or $15/month for 40k emails
- SMS backup (optional): ~$20/month for moderate usage

---

## Testing Checklist

After setup, test:
- [ ] Send test email from Supabase → Your .edu email
- [ ] Email arrives in inbox (not spam)
- [ ] Email displays correctly on mobile
- [ ] OTP code is clearly visible
- [ ] Send to friend's different .edu domain
- [ ] Check SendGrid analytics for delivery status
- [ ] Verify SPF/DKIM/DMARC pass (use mail-tester.com)

---

## Troubleshooting

### Email still goes to spam?
1. Check SPF/DKIM/DMARC: https://mxtoolbox.com/dmarc.aspx
2. Test email quality: https://www.mail-tester.com
3. Check SendGrid reputation: Dashboard → Email Activity
4. Add plain text version of email
5. Remove any suspicious words (urgent, act now, click here, etc.)

### DNS records not verifying?
1. Wait 24 hours (DNS propagation can be slow)
2. Check DNS with: https://dnschecker.org
3. Ensure no typos in DNS records
4. Try "DNS only" mode if using Cloudflare

### Still having university-specific issues?
1. Contact university IT department
2. Ask to whitelist noreply@campuslink.com
3. Provide SPF/DKIM records for verification
4. Some universities maintain approved sender lists

---

## Production Deployment Checklist

Before launching:
- [ ] Custom domain set up and verified
- [ ] SPF, DKIM, DMARC records configured
- [ ] Sender identity verified in SendGrid
- [ ] Supabase updated with new sender email
- [ ] Email templates updated with professional content
- [ ] Tested with 5+ different .edu domains
- [ ] Deliverability rate > 95%
- [ ] Monitoring set up in SendGrid
- [ ] Backup verification method ready (SMS)
- [ ] Support email set up for issues (support@campuslink.com)

---

## Next Steps

1. **TODAY:** Purchase domain (10 min)
2. **TODAY:** Set up DNS records (20 min)
3. **TODAY:** Configure SendGrid domain auth (15 min)
4. **TODAY:** Update Supabase sender email (5 min)
5. **TODAY:** Test with both .edu emails (30 min)
6. **THIS WEEK:** Monitor deliverability and adjust
7. **BEFORE LAUNCH:** Add SMS backup option

---

## Support Resources

- SendGrid Domain Authentication: https://docs.sendgrid.com/ui/account-and-settings/how-to-set-up-domain-authentication
- SPF/DKIM Setup: https://www.cloudflare.com/learning/dns/dns-records/dns-spf-record/
- Email Deliverability Best Practices: https://sendgrid.com/blog/email-deliverability-best-practices/
- Test Email Quality: https://www.mail-tester.com

