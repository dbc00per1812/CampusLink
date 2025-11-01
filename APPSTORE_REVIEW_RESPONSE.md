# App Store Review Response - Apple Pay Issues

**Date:** October 18, 2025  
**Review Issues:** Guideline 2.1 (Information Needed) & Guideline 5.1.1 (Privacy Policy)

---

## Summary of Issues

### Issue 1: Guideline 2.1 - Information Needed
**Problem:** The app binary includes the PassKit framework for Apple Pay, but reviewers were unable to verify any integration within the app.

### Issue 2: Guideline 5.1.1 - Legal - Privacy - Data Collection and Storage
**Problem:** The app uses Apple Pay but does not include the required and functional privacy policy.

---

## ✅ Status: Both Issues Can Be Resolved

---

## Issue 1: Apple Pay Integration - Where to Find It

### Current Implementation Status

**Apple Pay IS implemented in the app** via Stripe PaymentSheet integration.

#### Where Reviewers Can Find Apple Pay:

**Path to Test Apple Pay:**
1. Open CampusLink app
2. Navigate to the **Marketplace** tab
3. Browse and tap on any **listing**
4. Tap the **"Make an Offer"** button
5. Enter an offer amount and submit
6. Wait for the seller to accept the offer
7. Once accepted, tap **"Pay Now"** or similar payment button
8. The **Stripe PaymentSheet** will appear
9. **Apple Pay button will be visible** at the top of the payment sheet (if device has Apple Pay set up)

#### Technical Implementation Details:

**File:** `CampusLink/Features/Payments/Managers/PaymentService.swift`
- **Line 189:** Apple Pay configuration  
  ```swift
  configuration.applePay = .init(merchantId: "merchant.campuslink.com.campuslink", merchantCountryCode: "US")
  ```

**Merchant ID:** `merchant.campuslink.com.campuslink`

**Entitlements:** Apple Pay entitlements are configured in `CampusLink.entitlements`

### What to Include in Review Notes

**Suggested Review Notes for Resubmission:**

```
APPLE PAY INTEGRATION LOCATION:

To test Apple Pay in CampusLink:

1. Create or sign in to a test account with a .edu email address
2. Navigate to the Marketplace tab
3. Tap on any product listing
4. Make an offer by tapping "Make an Offer" button
5. Enter an amount and submit the offer
6. (For testing purposes, you can accept your own offer by switching to seller view)
7. Once the offer is accepted, tap the payment button
8. The Stripe Payment Sheet will display with Apple Pay as the primary payment method
9. Apple Pay button appears at the top of the payment sheet

Apple Pay is integrated via Stripe's PaymentSheet SDK and uses merchant ID: merchant.campuslink.com.campuslink

IMPORTANT: The device or simulator must have Apple Pay configured with at least one card for the Apple Pay button to appear.

Test Account Credentials (if needed):
Email: [provide test account email]
Password: [provide test account password]
```

---

## Issue 2: Privacy Policy URL

### Current Status

✅ **Privacy policy exists** at: `/Users/eileenmurphy/CampusLink/docs/PRIVACY.md`

❌ **Not hosted online** with a publicly accessible URL

### Solution Required

You need to:

1. **Host the privacy policy online** at a publicly accessible URL
2. **Update App Store Connect** with this URL

### Options for Hosting Privacy Policy

#### Option 1: GitHub Pages (Recommended - Free)

**Steps:**
1. Create a GitHub repository or use existing one
2. Enable GitHub Pages in repository settings
3. Create/upload privacy policy as `privacy.html` or `privacy.md`
4. Your URL will be: `https://[your-username].github.io/[repo-name]/privacy.html`

**I can see you have `index.html` in your project root**, which suggests you may already have GitHub Pages set up.

#### Option 2: Simple Static Hosting (Free Options)
- **Netlify:** Drop files and get instant URL
- **Vercel:** Fast deployment, works with git
- **Cloudflare Pages:** Simple and reliable

#### Option 3: Your Own Domain
If you own `campuslink.app` or `campuslink.com`:
- Host at: `https://campuslink.app/privacy`
- Host at: `https://campuslink.com/privacy-policy`

### What URL to Provide

Once hosted, update **App Store Connect**:

1. Go to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app
3. Go to **App Information** section
4. Find **Privacy Policy URL** field
5. Enter your hosted privacy policy URL (e.g., `https://yourdomain.com/privacy`)
6. **Save** changes

---

## Privacy Policy Already Mentions Apple Pay

Your current privacy policy (docs/PRIVACY.md) already covers payment processing:

**From lines 37-40:**
```markdown
### Payment Information
- **Stripe Connect Account Data:** For sellers (handled by Stripe)
- **Transaction Records:** Order history, payment amounts, escrow information
- **Bank Account Information:** For payouts (stored securely by Stripe)
```

**Recommendation:** Consider adding a specific mention of Apple Pay for clarity:

```markdown
### Payment Information
- **Payment Methods:** Credit/debit cards and Apple Pay (processed securely via Stripe)
- **Stripe Connect Account Data:** For sellers (handled by Stripe)
- **Transaction Records:** Order history, payment amounts, escrow information
- **Bank Account Information:** For payouts (stored securely by Stripe)
```

---

## Action Items Checklist

### Immediate Actions Required:

- [ ] **Host Privacy Policy Online**
  - [ ] Convert `docs/PRIVACY.md` to HTML or host as-is
  - [ ] Upload to GitHub Pages, Netlify, or your domain
  - [ ] Get public URL (e.g., `https://campuslink.app/privacy`)
  
- [ ] **Update App Store Connect**
  - [ ] Log in to [App Store Connect](https://appstoreconnect.apple.com)
  - [ ] Go to App Information → Privacy Policy URL
  - [ ] Enter your hosted privacy policy URL
  - [ ] Save changes

- [ ] **Add Review Notes**
  - [ ] Copy the suggested review notes from "Issue 1" section above
  - [ ] Paste into the "Review Notes" section in App Store Connect
  - [ ] Provide clear step-by-step instructions for finding Apple Pay
  - [ ] Consider providing test account credentials for easier review

- [ ] **Verify Apple Pay Setup**
  - [ ] Ensure merchant ID is registered in Apple Developer Portal
  - [ ] Verify Apple Pay certificate is uploaded to Stripe Dashboard
  - [ ] Test Apple Pay flow on physical device
  - [ ] Confirm Apple Pay button appears in payment sheet

### Optional Enhancements:

- [ ] Add explicit "Apple Pay" mention in privacy policy
- [ ] Create a screen recording showing Apple Pay flow
- [ ] Add "Apple Pay accepted" badge to app marketing materials

---

## Technical Verification

### Apple Pay Is Already Configured

✅ **Code Implementation:** PaymentService.swift line 189  
✅ **Merchant ID:** merchant.campuslink.com.campuslink  
✅ **Entitlements:** Configured in CampusLink.entitlements  
✅ **Privacy Policy:** Exists at docs/PRIVACY.md (needs hosting)

### What's Working
- Apple Pay code is integrated via Stripe SDK
- Payment flow supports Apple Pay
- Configuration is in place

### What's Needed
- **Privacy policy URL** (host online)
- **Clear review notes** (tell reviewers where to find Apple Pay)
- **Potential:** Test account for reviewers

---

## Response Strategy

### For Guideline 2.1 (Information Needed)

**Response via App Store Connect Review Notes:**
```
We acknowledge that our app includes the PassKit framework for Apple Pay integration. 

Apple Pay is available in our app through the Stripe PaymentSheet during the checkout process. To locate and test this feature:

[Insert step-by-step instructions from "Suggested Review Notes" section above]

If you need any assistance testing this feature or require a test account, please let us know and we'll be happy to provide one.
```

### For Guideline 5.1.1 (Privacy Policy)

**Action:** Update the Privacy Policy URL in App Store Connect before resubmitting.

**Response (if needed):**
```
We have updated our Privacy Policy URL in App Store Connect. The privacy policy is now accessible at: [YOUR_URL_HERE]

Our privacy policy covers all aspects of data collection, including payment processing via Stripe and Apple Pay.
```

---

## Next Steps Summary

1. **Host Privacy Policy** → Get public URL
2. **Update App Store Connect** → Add privacy policy URL
3. **Add Review Notes** → Explain where Apple Pay is in the app
4. **Resubmit App** → Address both guidelines
5. **Test Before Submission** → Verify Apple Pay works on device

---

## Timeline

- **Hosting Privacy Policy:** 15-30 minutes
- **Updating App Store Connect:** 5-10 minutes
- **Writing Review Notes:** 10-15 minutes
- **Total Time to Resolve:** ~1 hour

**New Review Time:** Typically 24-48 hours after resubmission

---

## Need Help?

- **Apple Developer Forums:** https://developer.apple.com/forums/
- **Stripe Support:** https://support.stripe.com/
- **GitHub Pages Setup:** See `GITHUB_PAGES_DOMAIN_SETUP.md` in your project

---

**Status:** Ready to resolve both issues  
**Confidence:** High - Issues are straightforward to address  
**Blocker:** None - All required assets exist, just need to be deployed



