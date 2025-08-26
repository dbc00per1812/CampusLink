# Checkout Rework Implementation Plan — CampusLink

Audience: AI agents and developers. Copy any task line under each section into your assistant to execute step-by-step. Keep changes small and incremental.

## 0) Verified Current State

- **iOS Codebase:**
  - Payment System: Basic Stripe integration exists. Files: `CampusLink/Features/Payments/Managers/PaymentService.swift`, `CampusLink/Core/Payments/PaymentLogic.swift`
  - Payment Models: Basic structure exists. File: `CampusLink/Core/Models/PaymentModels.swift`
  - Transaction Views: Basic UI exists. Files: `CampusLink/Features/Payments/Views/MyTransactionsView.swift`, `CampusLink/Features/Payments/Views/PurchaseConfirmationView.swift`
  - Edge Functions: Basic payment flow exists. Files: `supabase/functions/create_payment_intent/index.ts`, `supabase/functions/capture_payment/index.ts`

- **Supabase Backend:**
  - Tables `users`, `listings`, `conversations`, `messages`, `payments`, `service_bookings` are **CREATED**.
  - `payments` table has escrow fields: `escrow_release_at`, `delivered_at`, `buyer_confirmed_at`, `dispute_status`, `dispute_reason`, `dispute_notes`.
  - **MISSING:** `wallets`, `orders`, `payouts`, `disputes` tables.
  - **MISSING:** New fields in existing tables for wallet/order integration.

- **Immediate Goal:** Implement campus wallet system with escrow protection and Stripe Connect payouts.

---

## 1) Database Schema Migration

- TASK 1.1 — Add new fields to existing tables
  - **Human Explanation:** We're enhancing existing tables to support the new wallet and order system without breaking current functionality.
  - **IDE Steps:** Run SQL to add fields to `users` (`campus_email_verified`, `trust_score`, `stripe_connect_id`), `listings` (`status`, `reserved_by`, `reserved_until`), `payments` (`order_id`, `payment_method`, `auto_release_at`), `conversations` (`order_id`), `messages` (`order_id`), `service_bookings` (`order_id`).
  - **External Steps:** Execute in Supabase SQL editor. Create migration file for version control.

- TASK 1.2 — Create wallets table
  - **Human Explanation:** This table tracks each user's available balance and funds held in escrow, enabling the campus wallet system.
  - **IDE Steps:** Create `wallets` table with fields: `user_id` (PK, FK to users), `available_cents`, `escrow_cents`, `updated_at`. Add RLS policies for user read-only access.
  - **External Steps:** Execute in Supabase SQL editor. Enable RLS with proper policies.

- TASK 1.3 — Create orders table
  - **Human Explanation:** Central table for managing the complete transaction lifecycle from reservation to completion.
  - **IDE Steps:** Create `orders` table with fields: `id`, `listing_id`, `buyer_id`, `seller_id`, `price_cents`, `payment_method`, `payment_status`, `order_status`, `auto_release_at`, `created_at`. Add RLS for buyer/seller access only.
  - **External Steps:** Execute in Supabase SQL editor. Create indexes on `buyer_id`, `seller_id`, `listing_id`.

- TASK 1.4 — Create payouts table
  - **Human Explanation:** Tracks seller withdrawal requests and their status for audit and reconciliation.
  - **IDE Steps:** Create `payouts` table with fields: `id`, `seller_id`, `amount_cents`, `destination`, `status`, `created_at`. Add RLS for seller-only access.
  - **External Steps:** Execute in Supabase SQL editor. Create index on `seller_id`.

- TASK 1.5 — Create disputes table
  - **Human Explanation:** Dedicated table for dispute tracking and resolution workflow.
  - **IDE Steps:** Create `disputes` table with fields: `id`, `order_id`, `opened_by`, `reason`, `status`, `created_at`. Add RLS for participants only.
  - **External Steps:** Execute in Supabase SQL editor. Create index on `order_id`.

---

## 2) Core RPCs Implementation

- TASK 2.1 — Implement reserve_then_order RPC
  - **Human Explanation:** Atomic transaction that reserves a listing and creates an order with escrow hold in one operation.
  - **IDE Steps:** Create Supabase RPC that: validates listing availability, sets reservation with TTL, creates order record, creates payment record, moves funds to escrow (if wallet/card payment), links existing conversations/bookings.
  - **External Steps:** Deploy to Supabase. Test with various payment methods.

- TASK 2.2 — Implement seller_accept RPC
  - **Human Explanation:** Allows seller to confirm they can fulfill the order, starting the escrow countdown.
  - **IDE Steps:** Create RPC that updates order status to `seller_confirmed`, updates payment status to `requires_capture`, validates seller authorization.
  - **External Steps:** Deploy to Supabase. Test authorization checks.

- TASK 2.3 — Implement buyer_confirm RPC
  - **Human Explanation:** Buyer confirms receipt, triggering escrow release to seller's available balance.
  - **IDE Steps:** Create RPC that: validates buyer authorization, calculates platform fees, moves funds from escrow to seller's available balance, updates order/payment statuses, sets completion timestamps.
  - **External Steps:** Deploy to Supabase. Test fee calculations.

- TASK 2.4 — Implement open_dispute RPC
  - **Human Explanation:** Freezes escrow funds when buyer or seller reports an issue.
  - **IDE Steps:** Create RPC that: validates participant authorization, sets order status to `disputed`, updates payment dispute fields, prevents auto-release, creates dispute record.
  - **External Steps:** Deploy to Supabase. Test dispute freeze logic.

- TASK 2.5 — Implement auto_release_job cron function
  - **Human Explanation:** Automatically releases escrow after timeout if no dispute is filed.
  - **IDE Steps:** Create scheduled function that: finds orders past `auto_release_at`, checks for disputes, releases escrow to seller, updates statuses.
  - **External Steps:** Deploy to Supabase. Configure cron schedule (every hour).

- TASK 2.6 — Implement request_payout RPC
  - **Human Explanation:** Allows sellers to withdraw available balance to their bank via Stripe Connect.
  - **IDE Steps:** Create RPC that: validates available balance, creates payout record, initiates Stripe Connect transfer, deducts from available balance (with row lock).
  - **External Steps:** Deploy to Supabase. Test with Stripe Connect test accounts.

---

## 3) Stripe Connect Integration

- TASK 3.1 — Create connect_onboarding Edge Function
  - **Human Explanation:** Initiates Stripe Connect onboarding flow for sellers to link their bank account.
  - **IDE Steps:** Create Edge Function that: creates Stripe Connect account, generates onboarding link, stores `stripe_connect_id` in user profile, handles return/refresh URLs.
  - **External Steps:** Deploy function. Configure Stripe Connect settings in dashboard.

- TASK 3.2 — Create process_payout Edge Function
  - **Human Explanation:** Processes approved payout requests by creating Stripe transfers.
  - **IDE Steps:** Create Edge Function that: validates payout request, creates Stripe transfer to connected account, updates payout status, handles errors/retries.
  - **External Steps:** Deploy function. Test with various amounts and edge cases.

- TASK 3.3 — Update stripe_webhook for Connect events
  - **Human Explanation:** Handles Stripe Connect webhooks for payout status updates.
  - **IDE Steps:** Update existing webhook to handle: `transfer.created`, `transfer.paid`, `transfer.failed`, `account.updated` events. Update payout records accordingly.
  - **External Steps:** Deploy function. Register webhook endpoint in Stripe dashboard.

---

## 4) iOS Wallet Implementation

- TASK 4.1 — Create Wallet models and service
  - **Human Explanation:** Swift models and service layer for wallet operations.
  - **IDE Steps:** Create `WalletModels.swift` with `Wallet` struct. Create `WalletService.swift` with methods: `fetchBalance()`, `requestPayout()`, `getTransactionHistory()`.
  - **External Steps:** None. Test with mock data first.

- TASK 4.2 — Create WalletView UI
  - **Human Explanation:** New tab showing user's balance, transaction history, and withdrawal options.
  - **IDE Steps:** Create `WalletView.swift` with: balance display (available/escrow), transaction list, withdraw button, Stripe Connect onboarding flow.
  - **External Steps:** None. Ensure UI matches app design system.

- TASK 4.3 — Update MainTabView with Wallet tab
  - **Human Explanation:** Add wallet as a primary navigation option.
  - **IDE Steps:** Update `MainTabView.swift` to include wallet tab with badge for available balance.
  - **External Steps:** None. Test navigation flow.

---

## 5) Order Management System

- TASK 5.1 — Create Order models
  - **Human Explanation:** Swift models for the new order lifecycle system.
  - **IDE Steps:** Create `OrderModels.swift` with `Order` struct including all statuses and timestamps. Add computed properties for status display.
  - **External Steps:** None. Ensure Codable conformance.

- TASK 5.2 — Create OrderService
  - **Human Explanation:** Service layer for order operations.
  - **IDE Steps:** Create `OrderService.swift` with methods: `createOrder()`, `acceptOrder()`, `confirmDelivery()`, `openDispute()`, `getOrderDetails()`.
  - **External Steps:** None. Include proper error handling.

- TASK 5.3 — Create OrderDetailView
  - **Human Explanation:** Comprehensive view showing order timeline and actions.
  - **IDE Steps:** Create `OrderDetailView.swift` with: status timeline, escrow banners, action buttons (confirm/dispute), chat integration, service booking details.
  - **External Steps:** None. Test all order states.

- TASK 5.4 — Update MyTransactionsView
  - **Human Explanation:** Enhance existing view to show new order-based transactions.
  - **IDE Steps:** Update `MyTransactionsView.swift` to: display orders instead of just payments, show order status badges, link to OrderDetailView.
  - **External Steps:** None. Maintain backward compatibility.

---

## 6) Checkout Flow Update

- TASK 6.1 — Update ListingDetailView checkout
  - **Human Explanation:** Replace direct Stripe payment with new reservation and order flow.
  - **IDE Steps:** Update "Buy Now" button to: create reservation, show payment method selection (wallet/card/cash), create order via RPC, handle wallet payments.
  - **External Steps:** None. Test all payment methods.

- TASK 6.2 — Create PaymentMethodSheet
  - **Human Explanation:** Bottom sheet for selecting payment method during checkout.
  - **IDE Steps:** Create `PaymentMethodSheet.swift` with options: wallet (if sufficient balance), card (Stripe), cash at meetup. Show escrow protection info.
  - **External Steps:** None. Ensure clear UX.

- TASK 6.3 — Update PurchaseConfirmationView
  - **Human Explanation:** Show order details and next steps after purchase.
  - **IDE Steps:** Update to show: order ID, escrow protection message, expected timeline, link to order details, seller contact option.
  - **External Steps:** None. Test success and error states.

---

## 7) Testing & Migration

- TASK 7.1 — Create test scenarios
  - **Human Explanation:** Comprehensive test cases for the new payment flow.
  - **IDE Steps:** Write test cases for: wallet funding, order creation, escrow release, disputes, payouts, edge cases (insufficient funds, timeouts).
  - **External Steps:** Document in test plan. Use Stripe test cards.

- TASK 7.2 — Migrate existing transactions
  - **Human Explanation:** Link historical payments to new order system.
  - **IDE Steps:** Write migration script to: create orders for existing payments, set appropriate statuses, link conversations where applicable.
  - **External Steps:** Run in staging first. Create rollback plan.

- TASK 7.3 — Feature flag implementation
  - **Human Explanation:** Allow gradual rollout of new checkout system.
  - **IDE Steps:** Add feature flag: `useNewCheckoutFlow`. Gate new UI behind flag. Maintain old flow as fallback.
  - **External Steps:** Configure in Supabase or remote config.

---

## 8) Documentation & Compliance

- TASK 8.1 — Update Terms of Service
  - **Human Explanation:** Legal documentation for wallet and escrow features.
  - **IDE Steps:** Add sections for: wallet terms, escrow policy, dispute resolution, payout terms, platform fees.
  - **External Steps:** Legal review required before production.

- TASK 8.2 — Create user help documentation
  - **Human Explanation:** Help content for new payment features.
  - **IDE Steps:** Create help articles for: how escrow works, withdrawal process, dispute filing, payment methods.
  - **External Steps:** Add to help center or in-app help.

- TASK 8.3 — Implement KYC/AML checks
  - **Human Explanation:** Compliance requirements for money transmission.
  - **IDE Steps:** Add KYC triggers for: high-value transactions, withdrawal thresholds, suspicious patterns. Use Stripe Identity if needed.
  - **External Steps:** Review compliance requirements by jurisdiction.

---

## Success Metrics

- **Technical:**
  - All RPCs execute in < 500ms
  - Zero money-loss bugs in testing
  - Successful migration of 100% existing transactions

- **Business:**
  - < 2% dispute rate
  - > 90% successful order completion
  - < 24hr average payout time

- **User Experience:**
  - < 3 taps to complete purchase
  - Clear escrow status visibility
  - Intuitive dispute process

---

## Rollback Plan

If critical issues arise:
1. Disable feature flag to revert to old flow
2. Freeze new order creation
3. Complete in-progress orders manually
4. Fix issues in staging
5. Re-deploy with fixes

---

## Next Steps After Completion

1. Monitor metrics dashboard
2. Gather user feedback
3. Optimize fee structure
4. Add advanced features (scheduled payouts, multi-currency)
5. Expand payment methods (Apple Pay, crypto)
