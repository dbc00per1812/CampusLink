# GitHub Pages Custom Domain Setup for CampusLink

## Problem
GitHub Pages shows "DNS check unsuccessful" for `campusconnect.services` because DNS records aren't configured.

## What You Need
This domain hosts your Stripe Connect redirect pages:
- `https://campusconnect.services/stripe-return.html`
- `https://campusconnect.services/stripe-refresh.html`

## Step 1: Configure DNS Records at Your Domain Registrar

Go to your domain registrar (where you bought `campusconnect.services` - like GoDaddy, Namecheap, Google Domains, etc.)

### For Apex Domain (campusconnect.services) - Add These A Records:

Add **4 A records** pointing to GitHub Pages servers:

```
Type: A
Name: @ (or leave blank for root domain)
Value: 185.199.108.153
TTL: 3600 (or automatic)

Type: A
Name: @ (or leave blank for root domain)
Value: 185.199.109.153
TTL: 3600

Type: A  
Name: @ (or leave blank for root domain)
Value: 185.199.110.153
TTL: 3600

Type: A
Name: @ (or leave blank for root domain)
Value: 185.199.111.153
TTL: 3600
```

### For WWW subdomain (optional but recommended):

```
Type: CNAME
Name: www
Value: dbc00per1812.github.io
TTL: 3600
```

## Step 2: Wait for DNS Propagation

- DNS changes can take **15 minutes to 48 hours** to propagate globally
- Usually works within 1-2 hours
- You can check propagation status at: https://www.whatsmydns.net/

## Step 3: Verify in GitHub Pages

After DNS propagates:

1. Go back to GitHub Pages settings
2. Click "Check again" button
3. You should see ✅ "DNS check successful"
4. Then you can enable "Enforce HTTPS"

## Step 4: Test Your Domain

Once DNS is working, verify these URLs load:
- `https://campusconnect.services/` (should show the index page)
- `https://campusconnect.services/stripe-return.html`
- `https://campusconnect.services/stripe-refresh.html`

## Troubleshooting

### Still showing DNS error after 2+ hours?

1. **Verify your DNS records are correct:**
   - Check at your domain registrar's DNS management page
   - Make sure you added ALL 4 A records
   - Make sure the IP addresses are exactly correct

2. **Check DNS propagation:**
   ```bash
   # On Mac/Linux terminal:
   dig campusconnect.services
   
   # Should show the GitHub IPs: 185.199.108-111.153
   ```

3. **Common mistakes:**
   - Using wrong IP addresses (must be GitHub's IPs)
   - Setting TTL too high (should be 3600 or less)
   - Typos in domain name
   - Not saving changes at registrar

### Alternative: Use a Subdomain

If you have issues with the apex domain, you can use a subdomain instead:

```
Type: CNAME
Name: app (creates app.campusconnect.services)
Value: dbc00per1812.github.io
TTL: 3600
```

Then update your Stripe URLs to use `https://app.campusconnect.services/`

## Current Status

- ✅ GitHub Pages repository created
- ✅ HTML files committed
- ✅ Custom domain configured in GitHub settings
- ⏳ **WAITING FOR DNS PROPAGATION** ← You are here
- ⏳ Enable HTTPS (available after DNS works)
- ⏳ Update app code with domain

## Next Steps After DNS Works

Once GitHub shows "DNS check successful":

1. ✅ Enable "Enforce HTTPS" in GitHub Pages settings
2. Update these files with `campusconnect.services`:
   - `CampusLink/Features/Wallet/ViewModels/WalletViewModel.swift`
   - `CampusLink/Core/Navigation/TabViews.swift`
3. Test Stripe Connect onboarding in live mode

## Important Notes

⚠️ **Do not remove the custom domain from GitHub Pages while waiting for DNS**  
⚠️ **DNS propagation is completely normal and cannot be rushed**  
⚠️ **The error you're seeing is expected until DNS propagates**

## Expected Timeline

- DNS configuration: **5 minutes** ✅ (done by you)
- DNS propagation: **1-24 hours** ⏳ (waiting)
- GitHub verification: **Instant** (after propagation)
- HTTPS certificate: **5-10 minutes** (after verification)

You've done everything correctly - just need to wait for DNS to propagate globally!


