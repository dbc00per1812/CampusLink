<!-- 3c65ee47-0d92-4bf6-a6f7-9845507492bf c3a67da4-4583-4da2-bba8-efee24f24795 -->
# App Store Submission Plan

## Prerequisites Confirmed

- ✅ App functional and tested on physical device
- ✅ Legal documents added (Privacy Policy, Terms, Community Guidelines)
- ✅ Privacy manifest files complete (PrivacyInfo.xcprivacy)
- ✅ App in TestFlight with Apple Developer account active
- ✅ Screenshots and assets ready
- 🔄 Supabase: Free tier (needs upgrade)
- 🔄 Stripe: Sandbox/Test mode (needs production activation)

## Step 1: Upgrade Supabase to Paid Plan

**Action:** Go to [Supabase Dashboard](https://app.supabase.com/project/vnmzijluyctlufnzxast/settings/billing)

1. Navigate to Project Settings → Billing
2. Select **Pro Plan** ($25/month recommended for launch)

   - Includes: 8GB database, 50GB bandwidth, 2M edge function invocations
   - Auto-scaling available if you exceed limits

3. Add payment method and confirm upgrade
4. Wait for confirmation (usually immediate)

**Why Pro Plan:** The free tier has limitations that could cause issues during launch:

- Limited database connections
- Lower edge function quotas
- No support SLA

## Step 2: Activate Stripe Production Mode

**Action:** Go to [Stripe Dashboard](https://dashboard.stripe.com/)

### 2.1 Complete Business Profile

1. Click "Activate your account" banner at top
2. Complete all required information:

   - Business details (CampusLink Labs, LLC)
   - Tax information
   - Bank account for payouts
   - Verify identity documents if required

### 2.2 Get Production API Keys

1. Navigate to Developers → API Keys (make sure you're NOT in test mode)
2. Copy your **Publishable Key** (starts with `pk_live_...`)
3. Save it securely - you'll update the app in Step 3

### 2.3 Configure Production Webhooks

1. Navigate to Developers → Webhooks
2. Click "Add endpoint"
3. Enter URL: `https://vnmzijluyctlufnzxast.supabase.co/functions/v1/stripe-webhook`
4. Select events to listen for:

   - `payment_intent.succeeded`
   - `payment_intent.payment_failed`
   - `payment_intent.canceled`
   - `charge.dispute.created`
   - `charge.succeeded`

5. Click "Add endpoint"
6. Copy the **Webhook Signing Secret** (starts with `whsec_...`)
7. Store in Supabase Edge Function environment variables:

   - Go to Supabase → Edge Functions → Settings
   - Add secret: `STRIPE_WEBHOOK_SECRET` = `whsec_...`

## Step 3: Update App with Production Stripe Key

**File:** `CampusLink/App/Secrets.swift`

Update line 9:

```swift
// OLD (test key):
static let stripePublishableKey: String = "pk_test_51RqnpoLM2sOMgIvXOL8GxyAb6xguEmsOw4sQEf2bmdZIFOXzueAnmZqAU46nd4AWbX9va47MJhsE7ftTGhavDhBP00x1SmVZXC"

// NEW (production key from Step 2.2):
static let stripePublishableKey: String = "pk_live_YOUR_PRODUCTION_KEY_HERE"
```

**Important:** Never commit production keys to git. Consider using Xcode build configurations or environment variables for production vs. development keys.

## Step 4: Verify App Configuration

### 4.1 Check Xcode Project Settings

1. Open `CampusLink.xcodeproj` in Xcode
2. Select project → CampusLink target → General
3. Verify:

   - **Display Name:** CampusLink
   - **Bundle Identifier:** Matches App Store Connect (e.g., `com.campuslinklabs.campuslink`)
   - **Version:** 1.0 ✅
   - **Build:** 1 ✅

4. Go to Signing & Capabilities

   - Ensure "Automatically manage signing" is enabled
   - Select your Production distribution certificate
   - Verify all entitlements are correct

### 4.2 Check Info.plist Permissions

File already looks good with proper usage descriptions:

- ✅ Camera access
- ✅ Photo library access  
- ✅ Push notifications

### 4.3 Verify No Debug Code

- Remove or disable any test/debug features
- Check for console logs in production (optional cleanup)
- Verify `AppConfig.swift` feature flags are set correctly for launch

## Step 5: Create Production Build

### 5.1 Clean Build

1. In Xcode: Product → Clean Build Folder (⇧⌘K)
2. Close and reopen Xcode to ensure fresh state

### 5.2 Archive

1. Select "Any iOS Device (arm64)" as destination
2. Product → Archive (⇧⌘I)
3. Wait for build to complete
4. Organizer window will open automatically

### 5.3 Distribute

1. In Organizer, select the archive
2. Click "Distribute App"
3. Select "App Store Connect"
4. Choose "Upload"
5. Follow prompts (accept defaults)
6. Wait for upload to complete (can take 5-30 minutes)

## Step 6: Prepare App Store Connect Listing

**Action:** Go to [App Store Connect](https://appstoreconnect.apple.com/)

1. Navigate to My Apps → CampusLink
2. Verify/complete the following sections:

### App Information

- **Name:** CampusLink
- **Subtitle:** Campus Marketplace for Students
- **Privacy Policy URL:** (host your `docs/PRIVACY.md` somewhere public)
- **Category:** Primary = Shopping, Secondary = Social Networking
- **Content Rights:** Check if you own all content

### Pricing and Availability

- **Price:** Free
- **Availability:** United States (or your target countries)

### App Privacy

Fill out the Privacy Questionnaire based on `PrivacyInfo.xcprivacy`:

- **Data Collection:** Yes
- **Email Address:** Collected, Linked to User, for App Functionality
- **Name:** Collected, Linked to User, for App Functionality
- **Photos:** Collected, Linked to User, for App Functionality
- **Purchase History:** Collected, Linked to User, for App Functionality
- **Device ID:** Collected, Linked to User, for Analytics & App Functionality
- **Usage Data:** Collected, Linked to User, for Analytics
- **Crash Data:** Collected, Linked to User, for Analytics
- **Tracking:** No (confirm false)

### Age Rating

Based on marketplace app:

- **Rating:** 17+ (unrestricted web access, user-generated content)

## Step 7: Submit for Review

1. In App Store Connect → CampusLink → iOS App
2. Click "+ Version or Platform" if no version exists
3. Select "iOS"
4. Enter version: **1.0**
5. Fill out "What's New in This Version":
   ```
   Welcome to CampusLink - the trusted marketplace for college students!
   
   • Buy and sell goods & services on campus
   • Secure payments with Stripe
   • Verified .edu email addresses only
   • Direct messaging with buyers and sellers
   • In-app wallet for easy transactions
   • Push notifications for orders and messages
   ```

6. Upload screenshots (you indicated these are ready)
7. Set App Review Information:

   - **Sign-in required:** Yes
   - Provide demo account credentials for reviewers
   - **Notes:** "Please use a .edu email address for sign-up. A test account can be provided upon request."

8. Click "Submit for Review"

## Step 8: Post-Submission Checklist

### Monitor Review Status

- Check App Store Connect daily for status updates
- Typical review time: 24-48 hours
- Be ready to respond to any reviewer questions

### Prepare for Common Review Issues

1. **Demo Account:** Apple may request a working .edu test account

   - Have one ready with sample listings

2. **Payment Testing:** Ensure Stripe works in production (test with small purchase)
3. **Content Moderation:** Be ready to explain how you handle inappropriate listings

### After Approval

1. App will go live automatically (or on scheduled release date)
2. Monitor Supabase usage to ensure you're within Pro plan limits
3. Monitor Stripe transactions for any payment issues
4. Set up app analytics if desired
5. Respond to user reviews and feedback

## Critical Files Modified

- `CampusLink/App/Secrets.swift` (production Stripe key)

## External Services Updated

- Supabase: Upgraded to Pro plan
- Stripe: Activated production mode with webhooks configured

## Estimated Timeline

- Supabase upgrade: 5 minutes
- Stripe activation: 15-30 minutes (depends on verification)
- App update & build: 15 minutes
- Upload to App Store Connect: 30-60 minutes
- App review: 24-48 hours

**Total time to submission: ~1-2 hours**

**Total time to approval: 1-3 days**

### To-dos

- [ ] Upgrade Supabase from free tier to Pro plan ($25/month)
- [ ] Activate Stripe production mode and complete business profile
- [ ] Get production Stripe publishable key and webhook secret
- [ ] Configure production Stripe webhooks pointing to Supabase edge functions
- [ ] Update Secrets.swift with production Stripe publishable key
- [ ] Verify Xcode project settings (bundle ID, version, signing)
- [ ] Clean, archive, and upload production build to App Store Connect
- [ ] Verify App Store Connect metadata (privacy, pricing, description)
- [ ] Submit app for App Store review with demo account info