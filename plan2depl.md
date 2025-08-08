# Deployment Sprint Plan — CampusLink

Audience: AI agents and developers. Copy any task line under each section into your assistant to execute step-by-step. Keep changes small and incremental.

## 0) Verified Current State

- **iOS Codebase:**
  - Auth & Routing: Implemented. Files: `CampusLink/App/CampusLinkTestApp.swift`, `CampusLink/Core/Auth/AuthManager.swift`, `CampusLink/App/ContentView.swift`
  - Profiles: Implemented (`ProfileTabView` with photo upload). File: `CampusLink/Features/Profile/ProfileTabView.swift`
  - Listing Models: Implemented with product/service differentiation. File: `CampusLink/Core/Models/ProductModels.swift`
  - Home Feed with Navigation to Detail: Implemented. Files: `CampusLink/Features/Home/HomeTabView.swift`, `CampusLink/Features/Marketplace/Views/ListingDetailView.swift`
  - Post/Create Listing with image upload: Implemented. File: `CampusLink/Core/Navigation/TabViews.swift` (section `PostView`)
  - My Listings (mark sold/delete): Implemented. File: `CampusLink/Core/Navigation/TabViews.swift` (section `PaymentsView`)
  - Action Buttons (Contact/Buy/Book): Implemented. File: `CampusLink/Shared/Views/ActionButton.swift`

- **Supabase Backend:**
  - Tables `users`, `listings`, `conversations`, `messages`, and `payments` are **CREATED**.
  - `payments` table (called `transactions` in initial plan) is missing `seller_id` and `escrow_release_at` columns.
  - `service_bookings` table is **MISSING**.
  - RLS policies are partially implemented. `payments` table needs INSERT/UPDATE policies.

- **Immediate Goal:** Finalize database schema, implement backend payment logic, and then connect it to the iOS UI.

---

## 1) Repo Hygiene & Environment

- TASK 1.1 — Verify clean main and stash or reset - COMPLETED
  - **Human Explanation:** This task ensures we start with a clean slate, without any uncommitted changes, to avoid conflicts or accidentally including unrelated work.
  - **IDE Steps:** Run: `git status -sb`; if modified files aren’t intended, run: `git stash push -u -m "wip"` OR `git reset --hard origin/main && git clean -fd`
  - **External Steps:** None. This is handled entirely in the terminal.

- TASK 1.2 — Confirm Secrets.swift is in place and ignored
  - **Human Explanation:** This step ensures that our secret keys for connecting to the backend (Supabase) are stored in a special `Secrets.swift` file. Crucially, we also check that this file is listed in `.gitignore` so that it never gets accidentally uploaded to a public code repository, which would be a major security risk.
  - **IDE Steps:** Verify `Secrets.supabaseURL` and `Secrets.supabaseKey` exist; ensure `.gitignore` excludes `Secrets.swift`.
  - **External Steps:** If `Secrets.swift` does not exist, you will need to get the URL and `anon` key from your Supabase Project Dashboard (Settings -> API) and create the file manually.

- TASK 1.3 — Create app schemes for environments
  - **Human Explanation:** We're setting up different "modes" for our app: one for daily development (`Debug`), one for testing (`Staging`), and one for the live App Store version (`Release`). This lets us use different backend URLs and API keys for each mode without changing code.
  - **IDE Steps:** Create Xcode schemes: Debug (dev), Staging, Release (prod). Add per-scheme configuration (using `.xcconfig` files or direct build settings) for: `SUPABASE_URL`, `SUPABASE_KEY`, `STRIPE_PUBLISHABLE_KEY`.
  - **External Steps:** This is handled entirely within the Xcode IDE.

---

## 3) Payments Backend (Supabase Edge Functions)

- TASK 3.1 — Create Edge Function: `create_payment_intent` — COMPLETED
  - **Human Explanation:** This is the first step of a purchase. When a user clicks "Buy", this secure backend function creates a payment session with Stripe and records a new transaction in our database. It returns a secret key for the app to securely load the payment UI.
  - **IDE Steps (Prompt):** Implement Supabase Edge Function `create_payment_intent`. It takes a `listing_id`, finds the listing's price and seller, creates a Stripe PaymentIntent with manual capture, inserts a new `payments` record, and returns the PaymentIntent's `client_secret`.
  - **External Steps:** Use the Supabase CLI (`supabase functions new`, `supabase deploy`) to create and deploy the Edge Function. You will need your Stripe secret key available.

- TASK 3.2 — Create Edge Function: `capture_payment` — COMPLETED
  - **Human Explanation:** After a buyer confirms they've received their item, this function tells Stripe to actually move the money from the buyer's account to the seller's. It's a manual capture process that acts like an escrow service, protecting both parties.
  - **IDE Steps (Prompt):** Implement Supabase Edge Function `capture_payment`. It takes a `payment_intent_id` and calls the Stripe API to capture the payment. Ensure it's securely callable.
  - **External Steps:** Deploy the function via the Supabase CLI or dashboard.

- TASK 3.3 — Create Edge Function: `stripe_webhook` — COMPLETED
  - **Human Explanation:** This function is a listener for automatic updates from Stripe. Stripe calls this function to notify our app about events like a successful payment, a failed payment, or a dispute. This keeps our database in sync with what's happening at Stripe.
  - **IDE Steps (Prompt):** Implement a Supabase Edge Function to act as a Stripe webhook. It should handle events like `payment_intent.succeeded` and `charge.dispute.created` and update the corresponding row in the `payments` table.
  - **External Steps:** After deploying the function, you must take its URL and add it to your Stripe Dashboard under "Webhooks".

- TASK 3.4 — Secure functions and set secrets — ACTION REQUIRED
  - **Human Explanation:** Provide secrets to the Edge Functions runtime. Never store keys in code.
  - **IDE Steps:** None.
  - **External Steps:**
    - Set secrets via CLI (replace values):
      - `supabase secrets set STRIPE_SECRET_KEY=sk_test_...`
      - `supabase secrets set STRIPE_WEBHOOK_SECRET=whsec_...`
    - Verify secrets in Dashboard: Settings -> Secrets.
    - Add Webhook endpoint in Stripe (Test mode):
      - URL: `https://vnmzijluyctlufnzxast.functions.supabase.co/stripe_webhook`
      - Events: `payment_intent.succeeded`, `payment_intent.payment_failed`, `payment_intent.canceled`, `payment_intent.amount_capturable_updated`, `charge.dispute.created`

---

## 4) iOS Payments Integration

- TASK 4.1 — Add Stripe SDK via SPM
  - **Human Explanation:** We're adding Stripe's official library to our iOS project using the Swift Package Manager. This gives us all the pre-built tools and user interfaces to handle payments securely in the app.
  - **IDE Steps:** In Xcode, go to File -> Add Packages... and enter the URL for the `stripe-ios` SDK.
  - **External Steps:** None. This is handled entirely within the Xcode IDE.

- TASK 4.2 — Create `PaymentService.swift`
  - **Human Explanation:** We're creating a dedicated helper file in our app to handle all the logic related to payments, such as communicating with our backend functions. This keeps the code organized.
  - **IDE Steps:** Create the `PaymentService.swift` file. It will have methods like `preparePaymentSheet(listingId)` which calls our `create_payment_intent` function.
  - **External Steps:** None.

- TASK 4.3 — Wire “Buy Now” button in `ListingDetailView`
  - **Human Explanation:** This task connects the "Buy Now" button in the user interface to the payment logic we're building. When a user taps it, the payment process will start.
  - **IDE Steps:** On tap of the "Buy Now" button, call `PaymentService.preparePaymentSheet()`. On success, present the Stripe Payment Sheet UI to the user.
  - **External Steps:** None.

- TASK 4.4 — Add `PurchaseConfirmationView`
  - **Human Explanation:** We'll create a new screen to show the user whether their purchase was successful or if something went wrong, providing clear feedback.
  - **IDE Steps:** Create a new SwiftUI view to show a simple success/failure message after a payment attempt.
  - **External Steps:** None.

- TASK 4.5 — Test payments end-to-end with Stripe test cards.
  - **Human Explanation:** This is a crucial step to test the entire payment flow from start to finish using Stripe's special test credit card numbers. This ensures everything works before using real money.
  - **IDE Steps:** Run the app on a simulator or device and perform test purchases using Stripe's provided test card numbers.
  - **External Steps:** Watch the logs in the Supabase dashboard and the payment events in the Stripe Test Mode dashboard to see the data flow in real-time and diagnose any issues.

---

## 5) Messaging (Realtime)

- TASK 5.1 — Add Swift models for `Conversation` and `Message`.
  - **Human Explanation:** This task defines the data structure for conversations and messages within the iOS app. This ensures the app knows what kind of data to expect (e.g., text content, timestamp, sender ID).
  - **IDE Steps:** Create new Swift files for the `Conversation` and `Message` structs, conforming to `Codable` and `Identifiable`.
  - **External Steps:** None.

- TASK 5.2 — Create `ConversationListViewModel` and `ChatViewModel`.
  - **Human Explanation:** These are the logic handlers for the messaging screens. They will be responsible for fetching conversation and message data from Supabase and preparing it for the UI.
  - **IDE Steps:** Create the `ObservableObject` view model classes that will contain the logic for fetching and sending messages.
  - **External Steps:** None.

- TASK 5.3 — Build `ConversationListView` and `ChatView` UI.
  - **Human Explanation:** This task involves building the actual user interfaces for the messaging feature: a screen showing all of a user's conversations, and the screen for an individual chat.
  - **IDE Steps:** Create the SwiftUI views for the list and chat screens.
  - **External Steps:** None.

- TASK 5.4 — Hook up “Contact Seller” button to create/find a conversation and navigate to the `ChatView`.
  - **Human Explanation:** We will connect the "Contact Seller" button on a listing page to our messaging logic. When tapped, it will either find an existing chat with that seller or create a new one, then take the user to the chat screen.
  - **IDE Steps:** Add navigation logic to the "Contact Seller" button to route the user to the correct `ChatView`.
  - **External Steps:** None.

- TASK 5.5 — Implement Supabase Realtime subscriptions to listen for new messages.
  - **Human Explanation:** To make the chat feel instant, we will use Supabase's Realtime feature. This allows the app to "subscribe" to database changes, so new messages appear automatically without the user needing to manually refresh.
  - **IDE Steps:** In the `ChatViewModel`, implement a Supabase Realtime subscription to listen for new rows in the `messages` table for the current conversation.
  - **External Steps:** Ensure the Supabase project has Realtime enabled for the `messages` table (this is usually on by default).

---

## 6) Delivery/Completion & Escrow Release

- TASK 6.1 — Add transaction status UI
  - **Human Explanation:** To keep users informed, we will create a "My Purchases" or "My Sales" screen where they can see the current status of their transactions (e.g., "Paid," "Shipped," "Completed").
  - **IDE Steps:** In a "My Purchases" or "My Sales" view, fetch and display the `status` from the `payments` table.
  - **External Steps:** None.

- TASK 6.2 — Implement "Confirm Received" button for buyers
  - **Human Explanation:** This is the final step of the escrow system. The buyer gets a button to confirm they have received their item. Pressing this button will trigger the payment capture, releasing the funds to the seller.
  - **IDE Steps:** Create a button that, when tapped, calls the `capture_payment` Edge Function to release the funds to the seller.
  - **External Steps:** None.

- TASK 6.3 — (Server-side) Document need for an auto-release cron job.
  - **Human Explanation:** For a real-world app, we would need an automatic system (a "cron job") to release funds after a certain number of days if the buyer forgets to confirm. For now, we will just make a note of this requirement.
  - **IDE Steps:** Add a comment or a ticket in your project management system noting the need for a future server-side cron job for auto-releasing escrow payments.
  - **External Steps:** None for now.

---

## 7) Compliance & Settings

- TASK 7.1 — Implement "Delete Account" flow.
  - **Human Explanation:** App Store guidelines require a way for users to delete their accounts. This task involves creating the UI and backend logic to handle account deletion securely.
  - **IDE Steps:** Implement the UI and logic for the "Delete Account" flow. This will likely involve calling a Supabase function to scrub user data.
  - **External Steps:** You may need to create a `delete_user` database function in the Supabase dashboard that can be called from the app.

- TASK 7.2 — Add basic "Report User" UI.
  - **Human Explanation:** This provides a way for users to report inappropriate behavior or listings, which is important for community safety.
  - **IDE Steps:** Create a simple UI that allows a user to report another user or a listing. This might save the report to a new `reports` table in Supabase.
  - **External Steps:** You may need to create a `reports` table in the Supabase dashboard.

---

## 8) QA & Performance

- TASK 8.1 — Implement pagination in `HomeTabView` using `.range()`.
  - **Human Explanation:** To prevent the app from loading hundreds of listings at once and becoming slow, we will implement pagination. The app will load a small number of listings initially and then load more as the user scrolls.
  - **IDE Steps:** Update the data-fetching logic in `HomeTabView` to use Supabase's `.range()` modifier to fetch listings in batches.
  - **External Steps:** None.

- TASK 8.2 — Implement client-side image resizing before upload.
  - **Human Explanation:** To save on upload time and storage costs, we will resize large images on the user's device before uploading them to our server.
  - **IDE Steps:** Before uploading an image, use Swift libraries to create a smaller, compressed version of the selected image.
  - **External Steps:** None.

---

## 9) App Store Readiness

- TASK 9.1 — Prepare all App Store Connect metadata.
  - **Human Explanation:** This involves writing the app's description, taking screenshots, and preparing all the other materials required for the App Store listing.
  - **IDE Steps:** None.
  - **External Steps:** This is all done on the App Store Connect website (appstoreconnect.apple.com).

- TASK 9.2 — Fill out App Privacy questionnaire.
  - **Human Explanation:** Apple requires developers to declare what data their app collects and what it's used for. We will need to fill out this "nutrition label" for privacy.
  - **IDE Steps:** None.
  - **External Steps:** This is done on the App Store Connect website.

- TASK 9.3 — Write clear reviewer notes explaining the app, payment flow (for goods/services), and provide a test account.
  - **Human Explanation:** To ensure a smooth review process, we need to provide Apple's review team with clear instructions on how to use the app, especially the payment and messaging features. A test account with pre-populated data is essential.
  - **IDE Steps:** None.
  - **External Steps:** This information is entered in the "Notes for Reviewer" section on App Store Connect. You should create a test user in your Supabase project for them to use.

---

## 10) Release Steps

- TASK 10.1 — Switch Stripe to Live mode.
  - **Human Explanation:** This is the big step! We will switch our app from using Stripe's testing environment to the live environment to process real payments.
  - **IDE Steps:** Change the Stripe publishable key in your Release scheme/configuration to the live key.
  - **External Steps:** In the Supabase dashboard, update the `STRIPE_SECRET_KEY` secret to the live secret key from your Stripe dashboard.

- TASK 10.2 — Archive and upload to TestFlight.
  - **Human Explanation:** We will create a final build of the app and upload it to App Store Connect for distribution via TestFlight, allowing internal or external testers to try it before release.
  - **IDE Steps:** In Xcode, use the "Archive" function to build the app with the Release scheme, and then upload it to the App Store.
  - **External Steps:** Manage testers and builds on the App Store Connect website.

- TASK 10.3 — Submit for review.
  - **Human Explanation:** Once everything is tested and ready, this is the final step: submitting the app to Apple for review and, hopefully, approval for sale on the App Store.
  - **IDE Steps:** None.
  - **External Steps:** On App Store Connect, select the build you uploaded and click "Submit for Review".
