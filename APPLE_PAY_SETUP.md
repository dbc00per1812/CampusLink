# Apple Pay Setup Guide for CampusLink

## Overview
Your app already has Apple Pay code integration via Stripe. This guide will help you complete the setup.

## Current Status
✅ **Code Integration**: Already implemented in `PaymentService.swift` (line 146)
- Merchant ID configured: `merchant.campuslink.com.campuslink`
- Country: US
- Integrated with Stripe PaymentSheet

❌ **Missing**: Apple Developer Portal & Entitlements configuration

---

## Step-by-Step Setup

### 1. Apple Developer Portal Setup

#### A. Create Merchant ID
1. Go to [Apple Developer Portal](https://developer.apple.com/account)
2. Navigate to **Certificates, Identifiers & Profiles**
3. Click **Identifiers** → **+** button
4. Select **Merchant IDs** → Click **Continue**
5. Fill in:
   - **Description**: `CampusLink Merchant`
   - **Identifier**: `merchant.campuslink.com.campuslink`
   - ⚠️ **IMPORTANT**: Use the exact identifier above (already in your code)
6. Click **Continue** → **Register**

#### B. Create Merchant Identity Certificate
1. In the Merchant IDs list, click on `merchant.campuslink.com.campuslink`
2. Click **Create Certificate** under "Apple Pay Payment Processing Certificate"
3. **You'll need a CSR (Certificate Signing Request)**:
   - Open **Keychain Access** on your Mac
   - Menu: **Keychain Access → Certificate Assistant → Request a Certificate from a Certificate Authority**
   - Enter your email
   - Select **"Saved to disk"**
   - Click **Continue** and save the `.certSigningRequest` file
4. Upload the CSR to Apple Developer Portal
5. Download the certificate (`.cer` file)
6. Double-click to install it in Keychain Access

#### C. Enable Apple Pay for Your App ID
1. In Apple Developer Portal, go to **Identifiers**
2. Find your app identifier (com.campuslink.CampusLink or similar)
3. Check the **Apple Pay** capability
4. Click **Edit** → Select your merchant ID
5. Click **Save**

---

### 2. Stripe Configuration

#### A. Upload Apple Pay Certificate to Stripe (REQUIRED for iOS)
**⚠️ CRITICAL**: This step is required for Apple Pay to work. Stripe needs the certificate to decrypt Apple Pay tokens.

1. Go to [Stripe Dashboard](https://dashboard.stripe.com)
2. Navigate to **Settings → Payment methods → Apple Pay**
3. Under "iOS certificates", click **"Add new certificate"**
4. Click **"Continue"** to download Stripe's CSR file
5. Save the CSR file to your computer
6. Go to [Apple Developer Portal → Merchant IDs](https://developer.apple.com/account/resources/identifiers/list/merchant)
7. Click on `merchant.campuslink.com.campuslink`
8. Under "Apple Pay Payment Processing Certificate":
   - Click **"Create Certificate"** (or "Create New Certificate" if one exists)
   - Upload the **CSR file from Stripe** (not from Keychain!)
   - Download the certificate (.cer file)
9. Back in Stripe Dashboard, upload the .cer file
10. Click **Save**

**Without this certificate, you'll get "unable to decrypt your request" errors!**

#### B. Add Apple Pay Domain (Optional - Web only)
If you plan to use Apple Pay on web:
1. In Stripe Dashboard, under Apple Pay settings
2. Click **"Add domain"**
3. Add your domain (e.g., `campuslink.com`)
4. Download the verification file and host it on your domain

---

### 3. Xcode Project Configuration

#### A. Enable Apple Pay Capability (Do this in Xcode)
1. Open `CampusLink.xcodeproj` in Xcode
2. Select the **CampusLink** target
3. Go to **Signing & Capabilities** tab
4. Click **+ Capability**
5. Add **Apple Pay**
6. Under Apple Pay, click **+** and add:
   - `merchant.campuslink.com.campuslink`

This will automatically update your entitlements file.

#### B. Verify Entitlements
After adding the capability, your `CampusLink.entitlements` should include:
```xml
<key>com.apple.developer.in-app-payments</key>
<array>
    <string>merchant.campuslink.com.campuslink</string>
</array>
```

---

### 4. Testing Apple Pay

#### A. Testing on Simulator (iOS 15.5+)
1. Open **Settings** app in Simulator
2. Go to **Wallet & Apple Pay**
3. Add a test card:
   - Click **Add Card**
   - Use test card: `4242 4242 4242 4242`
   - Any future expiry date
   - Any 3-digit CVC

#### B. Testing on Physical Device
1. Add a real card to Apple Wallet
2. OR use Stripe test cards (Stripe supports test mode on device)
3. Run your app
4. Go to purchase a listing
5. Select "Credit/Debit Card" payment method
6. The Stripe PaymentSheet will show Apple Pay as an option

#### C. Test Card Numbers
Stripe test cards that work with Apple Pay in test mode:
- **Success**: `4242 4242 4242 4242`
- **Requires Auth**: `4000 0025 0000 3155`
- **Decline**: `4000 0000 0000 9995`

---

### 5. Verification Checklist

Before going live, verify:

- [ ] Merchant ID created in Apple Developer Portal
- [ ] Apple Pay Payment Processing Certificate created in Apple Developer Portal
- [ ] **Certificate uploaded to Stripe Dashboard** (most commonly missed!)
- [ ] App ID has Apple Pay capability enabled
- [ ] Merchant ID linked to App ID in Apple Developer Portal
- [ ] Apple Pay capability added in Xcode
- [ ] Entitlements file includes merchant ID
- [ ] App builds and runs without errors
- [ ] Apple Pay button appears in Stripe PaymentSheet
- [ ] Test purchase completes successfully (no "decrypt" errors)
- [ ] Real card test on physical device works

---

## Troubleshooting

### "Apple Pay is not available"
- Ensure you're testing on iOS 15.5+ (Simulator or device)
- Verify a card is added to Apple Wallet
- Check that the merchant ID matches exactly in code and Apple Developer Portal

### "Invalid Merchant ID"
- Verify the merchant ID in Apple Developer Portal matches your code
- Ensure the merchant ID certificate is installed in Keychain
- Check that your App ID is linked to the merchant ID

### Apple Pay button doesn't appear
- Verify Stripe publishable key is correct
- Check that Apple Pay is enabled in Stripe Dashboard
- Ensure device/simulator has Apple Pay set up

### "Merchant validation failed" or "Unable to decrypt your request"
- **Most Common**: Certificate not uploaded to Stripe Dashboard
- Go to Stripe Dashboard → Settings → Payment methods → Apple Pay
- Add iOS certificate using Stripe's CSR (not Keychain CSR)
- Upload the .cer file from Apple Developer Portal to Stripe
- Certificate issue: Regenerate merchant identity certificate
- Verify App ID configuration in Apple Developer Portal

---

## Production Considerations

### Before App Store Submission:
1. Test with real cards on physical devices
2. Verify merchant account is properly set up with Stripe
3. Ensure all certificates are valid and not expiring soon
4. Test the full payment flow end-to-end
5. Review Apple's [App Store Review Guidelines](https://developer.apple.com/app-store/review/guidelines/) for payment requirements

### After Launch:
1. Monitor payment success rates in Stripe Dashboard
2. Track Apple Pay adoption vs. card payments
3. Set up fraud monitoring
4. Consider adding analytics to track payment method selection

---

## Support Resources

- [Apple Pay Programming Guide](https://developer.apple.com/documentation/passkit/apple_pay)
- [Stripe Apple Pay Documentation](https://stripe.com/docs/apple-pay)
- [Stripe iOS SDK](https://stripe.com/docs/payments/accept-a-payment?platform=ios)
- [CampusLink Payment Service Code](./CampusLink/Features/Payments/Managers/PaymentService.swift)

---

## Quick Start Summary

**Minimum steps to get Apple Pay working:**

1. Create merchant ID in Apple Developer Portal: `merchant.campuslink.com.campuslink`
2. **In Stripe Dashboard**: Download CSR from Apple Pay settings
3. **In Apple Developer Portal**: Create certificate using Stripe's CSR
4. **In Stripe Dashboard**: Upload the .cer file ← CRITICAL STEP!
5. Enable Apple Pay for your App ID in Apple Developer Portal
6. In Xcode: Add Apple Pay capability and select the merchant ID
7. Add a test card to Wallet in Simulator/Device
8. Test a purchase!

---

**Questions or issues?** Check the troubleshooting section or Stripe/Apple documentation.

