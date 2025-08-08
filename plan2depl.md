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
  - Run: `git status -sb`; if modified files aren’t intended, run: `git stash push -u -m "wip"` OR `git reset --hard origin/main && git clean -fd`

- TASK 1.2 — Confirm Secrets.swift is in place and ignored
  - Verify `Secrets.supabaseURL` and `Secrets.supabaseKey` exist; ensure `.gitignore` excludes it

- TASK 1.3 — Create app schemes for environments
  - Create Xcode schemes: Debug (dev), Staging, Release (prod)
  - Add per-scheme config (xcconfig or build settings) for: SUPABASE_URL, SUPABASE_KEY, STRIPE_PUBLISHABLE_KEY

---


---

## 3) Payments Backend (Supabase Edge Functions)

- TASK 3.1 — Create Edge Function: `create_payment_intent`
  - **Input:** `listing_id`
  - **Behavior:** Fetches listing details (price, seller_id). Creates a Stripe PaymentIntent with `manual_capture_method`. Inserts a new row into `payments` with `buyer_id` (from auth), `seller_id`, `amount`, and `payment_intent_id`. Returns the `client_secret`.
  - **Prompt:** Implement Supabase Edge Function `create_payment_intent`. It takes a `listing_id`, finds the listing's price and seller, creates a Stripe PaymentIntent with manual capture, inserts a new `payments` record, and returns the PaymentIntent's `client_secret`.

- TASK 3.2 — Create Edge Function: `capture_payment`
  - **Input:** `payment_intent_id`
  - **Behavior:** Calls Stripe to capture the funds for the given PaymentIntent. Should only be callable by the seller or an admin/service role.
  - **Prompt:** Implement Supabase Edge Function `capture_payment`. It takes a `payment_intent_id` and calls the Stripe API to capture the payment. Ensure it's securely callable.

- TASK 3.3 — Create Edge Function: `stripe_webhook`
  - **Behavior:** Handles incoming events from Stripe (`payment_intent.succeeded`, `payment_intent.capture_declined`, `charge.dispute.created`, etc.). Updates the `status` column in the `payments` table accordingly.
  - **Prompt:** Implement a Supabase Edge Function to act as a Stripe webhook. It should handle events like `payment_intent.succeeded` and `charge.dispute.created` and update the corresponding row in the `payments` table.

- TASK 3.4 — Secure functions and set secrets
  - Store `STRIPE_SECRET_KEY`, `STRIPE_WEBHOOK_SECRET` in Supabase project secrets.

---

## 4) iOS Payments Integration

- TASK 4.1 — Add Stripe SDK via SPM
  - Package: `stripe-ios`.

- TASK 4.2 — Create `PaymentService.swift`
  - Methods: `preparePaymentSheet(listingId)` (calls `create_payment_intent`, returns client secret), `presentPaymentSheet()`, `confirmPayment()`.

- TASK 4.3 — Wire “Buy Now” button in `ListingDetailView`
  - On tap, call `PaymentService.preparePaymentSheet()`. On success, present the Stripe Payment Sheet UI.

- TASK 4.4 — Add `PurchaseConfirmationView`
  - Show a simple success/failure message after a payment attempt.

- TASK 4.5 — Test payments end-to-end with Stripe test cards.
  - Validate success, 3DS, and decline flows.

---

## 5) Messaging (Realtime)

- TASK 5.1 — Add Swift models for `Conversation` and `Message`.
- TASK 5.2 — Create `ConversationListViewModel` and `ChatViewModel`.
- TASK 5.3 — Build `ConversationListView` and `ChatView` UI.
- TASK 5.4 — Hook up “Contact Seller” button to create/find a conversation and navigate to the `ChatView`.
- TASK 5.5 — Implement Supabase Realtime subscriptions to listen for new messages.

---

## 6) Delivery/Completion & Escrow Release

- TASK 6.1 — Add transaction status UI
  - In a "My Purchases" or "My Sales" view, show the `status` from the `payments` table.

- TASK 6.2 — Implement "Confirm Received" button for buyers
  - This button will call the `capture_payment` Edge Function to release the funds to the seller.

- TASK 6.3 — (Server-side) Document need for an auto-release cron job.
  - For now, manual capture is sufficient for the MVP.

---

## 7) Compliance & Settings

- TASK 7.1 — Implement "Delete Account" flow.
- TASK 7.2 — Add basic "Report User" UI.

---

## 8) QA & Performance

- TASK 8.1 — Implement pagination in `HomeTabView` using `.range()`.
- TASK 8.2 — Implement client-side image resizing before upload.

---

## 9) App Store Readiness

- TASK 9.1 — Prepare all App Store Connect metadata (screenshots, descriptions, etc.).
- TASK 9.2 — Fill out App Privacy questionnaire.
- TASK 9.3 — Write clear reviewer notes explaining the app, payment flow (for goods/services), and provide a test account.

---

## 10) Release Steps

- TASK 10.1 — Switch Stripe to Live mode.
- TASK 10.2 — Archive and upload to TestFlight.
- TASK 10.3 — Submit for review.
