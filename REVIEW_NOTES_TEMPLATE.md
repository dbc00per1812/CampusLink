# Quick Copy-Paste: App Store Review Notes

Use this as your **Review Notes** when resubmitting to App Store Connect.

---

## REVIEW NOTES (Copy everything below this line)

---

**APPLE PAY INTEGRATION - HOW TO TEST:**

Apple Pay is integrated in our app via Stripe's PaymentSheet SDK and is visible during the checkout process.

**Step-by-step to locate Apple Pay:**

1. Launch CampusLink app
2. Sign in with test account (or create account with .edu email)
3. Navigate to the "Marketplace" tab (bottom navigation)
4. Tap on any product listing to view details
5. Tap the "Make an Offer" button
6. Enter an offer amount and tap "Submit Offer"
7. For testing purposes: If you're the seller, you can accept your own offer by going to "Orders" tab → "Selling" section
8. Once the offer is accepted, tap the "Pay Now" button
9. The Stripe Payment Sheet will appear
10. **Apple Pay button will be displayed** at the top of the payment sheet

**Important Notes:**
- Apple Pay button only appears if the testing device/simulator has Apple Pay configured with at least one card
- Apple Pay is the primary payment method shown in the Stripe Payment Sheet
- Our Merchant ID: merchant.campuslink.com.campuslink

**Alternative for simulator testing:**
- In iOS Simulator, go to Settings → Wallet & Apple Pay → Add Card
- Use test card: 4242 4242 4242 4242 with any future expiry date

**Test Account (Optional - provide if you want):**
Email: [YOUR_TEST_EMAIL_HERE]
Password: [YOUR_TEST_PASSWORD_HERE]

If you need any assistance testing this feature or have questions, please let us know.

---

**PRIVACY POLICY:**

Our privacy policy has been updated and is available at:
[YOUR_PRIVACY_POLICY_URL_HERE]

The privacy policy includes comprehensive coverage of:
- Apple Pay and payment processing via Stripe
- All data collection practices
- User rights and data protection measures
- Contact information for privacy inquiries

---

## AFTER YOU HOST THE PRIVACY POLICY

Replace `[YOUR_PRIVACY_POLICY_URL_HERE]` with your actual URL, such as:
- `https://campuslink.app/privacy`
- `https://yourusername.github.io/CampusLink/privacy.html`
- `https://your-netlify-site.netlify.app/privacy.html`

---

## AFTER YOU CREATE TEST ACCOUNT (Optional but Recommended)

Replace:
- `[YOUR_TEST_EMAIL_HERE]` with actual test email (e.g., test@university.edu)
- `[YOUR_TEST_PASSWORD_HERE]` with actual test password

Having a test account ready makes the review process much faster!

---

## CHECKLIST BEFORE RESUBMISSION

- [ ] Privacy policy hosted online with public URL
- [ ] Privacy Policy URL updated in App Store Connect → App Information
- [ ] Review notes copied and customized with your privacy policy URL
- [ ] (Optional) Test account created and credentials added to review notes
- [ ] Apple Pay tested on physical device to confirm it works
- [ ] Screenshots/app preview videos show the marketplace and transaction flow

---

## WHERE TO PASTE THESE NOTES

1. Log in to [App Store Connect](https://appstoreconnect.apple.com)
2. Navigate to your app
3. Go to the version that's "Waiting for Review" or "In Review"
4. Find the **"App Review Information"** section
5. Look for the **"Notes"** text box
6. Paste the review notes (the section between the horizontal lines above)
7. Click **Save**
8. Submit for review

---

**Good luck with your resubmission! 🚀**

The issues are straightforward to resolve and your app should be approved quickly once these administrative items are addressed.


