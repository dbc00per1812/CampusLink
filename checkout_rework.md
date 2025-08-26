# 🛡️ Direct Checkout (No Cart) with Escrow & Seller Payouts

## Money Model (simple + safe)

* **Campus Wallet (platform ledger)**
  * Every user has a wallet: `available_cents`, `escrow_cents`.
  * Buyer pays → money moves into **escrow** on the order.
  * On completion → **escrow → seller.available**.
  * Users can **withdraw available** to a bank (Stripe Connect) or **spend** it in-app.

* **Stripe Connect (optional withdrawals)**
  * Sellers link a bank/debit via Connect onboarding.
  * Payouts initiated from seller's **available** balance → ACH to bank.
  * Service workers who don't want a bank on file can keep balance in wallet and spend on-platform.

---

## End-to-End Flow

1. **Buy Now → Reserve**
   * 10–15 min reservation prevents double sale.

2. **Checkout (Meetup / Service Details)**
   * Select time window, location, notes to seller.
   * Pick payment: **Wallet (escrow)**, **Card → escrow**, or **Cash at meetup** (reduced protection).

3. **Pay → Escrow**
   * Funds are held: `escrow_status='held'`. Seller sees "Payment Secured."

4. **Seller Accepts (SLA e.g., 24h)**
   * If no response → auto-cancel + refund.

5. **Fulfillment**
   * Meetup or service performed. In-order chat for coordination.

6. **Complete or Dispute**
   * Buyer taps **Confirm Received** → escrow releases to seller's **available**.
   * If buyer forgets: **auto-release after N days** unless a dispute is opened.
   * If dispute opened: funds stay frozen until resolution.

7. **Seller Payouts**
   * When seller has **available** funds, they can:
     * **Withdraw to bank** (Stripe Connect payout).
     * **Keep in wallet** to spend on other listings.

---

## Payouts: the practical bits

**When can a seller cash out?**

* Immediately after a **completed** order (post any fraud buffer you set, e.g., 24h).
* Funds move: `escrow_cents → seller.available_cents`.
* Seller taps **Withdraw**:
  * If **Connected account linked** → create Stripe payout (ACH; typical T+2 business days).
  * If not linked → prompt Connect onboarding.

**Fees & limits (you set policy):**

* Platform fee (e.g., 5–10%) is taken **at capture** or on **escrow release**.
* Minimum withdrawal (e.g., $10).
* Weekly payout cap for new sellers (trust ramp).
* High-risk categories may have longer auto-release windows.

**KYC/Compliance:**

* Stripe Connect handles KYC (SSN last-4 or full, depending on volume).
* Hold payouts if KYC incomplete.
* Track 1099-K thresholds (Stripe helps), if applicable.

---

## Fraud & Abuse Controls

* **Escrow, not direct pay** — Sellers can't access funds until completion.
* **Clocked confirmations** — Auto-release after N days; auto-refund if seller never accepts.
* **Reputation system** — Completion rate, dispute rate, verified ID, campus email.
* **Policy enforcement** — No off-platform payments (filter messages), ban repeat offenders.
* **Service proof (optional)** — Photo upload, one-tap "met at X" geotag (privacy-respecting), or code exchange.

---

## Supabase Schema (aligned with existing database)

**users** (existing - enhanced)
* `id (pk)`, `name`, `bio`, `profile_pic`, `email`, `created_at`
* **New fields to add**: `campus_email_verified bool`, `trust_score int`, `stripe_connect_id text null`

**wallets** (new table to create)
* `user_id (pk)`, `available_cents int`, `escrow_cents int`, `updated_at`

**listings** (existing - enhanced)
* `id`, `user_id` (seller), `title`, `description`, `price`, `category`, `photo`, `is_sold`, `created_at`, `listing_type`, `service_duration`, `service_location`, `service_availability`
* **New fields to add**: `status ('active|reserved|sold')`, `reserved_by uuid`, `reserved_until timestamptz`

**payments** (existing - enhanced)
* `id`, `listing_id`, `buyer_id`, `seller_id`, `payment_intent_id`, `amount`, `status`, `created_at`, `escrow_release_at`, `delivered_at`, `buyer_confirmed_at`, `seller_proof_urls`, `dispute_status`, `dispute_reason`, `dispute_notes`
* **New fields to add**: `order_id uuid`, `payment_method ('wallet|card|cash')`, `auto_release_at timestamptz`

**orders** (new table to create)
* `id`, `listing_id`, `buyer_id`, `seller_id`, `price_cents`,
* `payment_method ('wallet|card|cash')`,
* `payment_status ('escrow_hold|released|refunded|failed|pending_cash')`,
* `order_status ('placed|seller_confirmed|ready_to_meet|completed|cancelled|disputed')`,
* `auto_release_at timestamptz`, `created_at`

**payouts** (new table to create)
* `id`, `seller_id`, `amount_cents`, `destination ('stripe_connect')`, `status ('requested|processing|paid|failed')`, `created_at`

**disputes** (new table to create)
* `id`, `order_id`, `opened_by`, `reason`, `status ('open|resolved_buyer|resolved_seller|admin_required')`, `created_at`

**conversations** (existing - enhanced)
* `id`, `listing_id`, `buyer_id`, `seller_id`, `last_message_at`, `created_at`
* **New field to add**: `order_id uuid` (to link conversations to orders)

**messages** (existing - enhanced)
* `id`, `conversation_id`, `sender_id`, `content`, `message_type`, `created_at`
* **New field to add**: `order_id uuid` (for order-specific chat)

**service_bookings** (existing - enhanced)
* `id`, `transaction_id`, `scheduled_at`, `duration_minutes`, `location`, `special_requests`, `status`, `created_at`
* **New field to add**: `order_id uuid` (to link to new order system)

---

## Core RPCs (transaction-safe)

1. `reserve_then_order(buyer_id, listing_id, payment_method, details_json)`
   * Checks listing `active` & unreserved → sets `reserved` with TTL.
   * Creates order + payment record + (if wallet/card) moves **buyer.available → escrow** atomically.
   * Sets `auto_release_at = now() + interval '3 days'`.
   * Links existing `conversations` and `service_bookings` to the new order.

2. `seller_accept(order_id, seller_id)`
   * Moves order status `placed → seller_confirmed`.
   * Updates payment status to `requires_capture`.
   * No money moves.

3. `buyer_confirm(order_id, buyer_id)`
   * **Escrow release**: `order.price_cents` (minus fees) from **escrow → seller.available**.
   * Updates `payment_status='released'`, `order_status='completed'`.
   * Sets `delivered_at` and `buyer_confirmed_at` timestamps.

4. `open_dispute(order_id, user_id, reason)`
   * Sets `order_status='disputed'`, freezes escrow (no release).
   * Updates payment `dispute_status='open'` and `dispute_reason`.

5. `auto_release_job()` (cron)
   * Releases escrow if `now() > auto_release_at` AND no dispute.
   * Updates both order and payment statuses.

6. `request_payout(seller_id, amount_cents)`
   * Validates `amount ≤ available`.
   * Creates `payouts` row and calls Stripe payout; deducts from **available** (lock row).

7. `link_existing_conversation_to_order(conversation_id, order_id)`
   * Links existing conversations to new orders for seamless chat continuity.
   * Updates conversation with `order_id` reference.

8. `link_service_booking_to_order(booking_id, order_id)`
   * Links existing service bookings to new orders.
   * Updates booking with `order_id` reference.

> All money-moving RPCs should run **in a single transaction** with row-level locks (`FOR UPDATE`) and tight RLS.

---

## RLS Essentials

* `wallets`: user can read their own; **writes only via RPC** (use `security definer`).
* `orders`: visible to `buyer_id` or `seller_id` only.
* `payments`: visible to `buyer_id` or `seller_id` only; **writes only via RPC**.
* `payouts`: only `seller_id` owner + admins.
* `conversations`: only participants can read/write (existing policy).
* `messages`: only participants of the conversation (existing policy).
* `service_bookings`: only participants can read/write.
* Block messages containing payment handles (regex) to enforce on-platform flow.

---

## Swift UX (what users see)

* **Order detail timeline**: Placed → Seller Confirmed → Meetup → Completed / Disputed.
* **Escrow banners**:
  * Buyer: "Your payment is secured in escrow until you confirm."
  * Seller: "Funds will be released after buyer confirmation or auto-release on <date>."
* **Wallet tab**: balance, escrow, transactions, **Withdraw** CTA (guides Connect onboarding).
* **Trust surfaces**: verified campus email badge, completion rate, ratings.

---

## Defaults that work well on campus

* Reservation TTL: **15 minutes**
* Seller acceptance window: **24 hours** → auto-refund
* Auto-release: **3 days** after seller confirmation
* New seller cap: **$200/day** withdrawals until trust ↑
* Platform fee: **8%** (example), taken on **escrow release**

---

## Migration Strategy (Current → New System)

### Phase 1: Database Schema Updates
1. **Add new fields to existing tables**:
   - `users`: Add `campus_email_verified`, `trust_score`, `stripe_connect_id`
   - `listings`: Add `status`, `reserved_by`, `reserved_until`
   - `payments`: Add `order_id`, `payment_method`, `auto_release_at`
   - `conversations`: Add `order_id`
   - `messages`: Add `order_id`
   - `service_bookings`: Add `order_id`

2. **Create new tables**:
   - `wallets` (user balance management)
   - `orders` (order lifecycle management)
   - `payouts` (seller withdrawal tracking)
   - `disputes` (dispute resolution)

### Phase 2: Data Migration
1. **Existing payments**: Link to new orders table
2. **Existing conversations**: Link to new orders where applicable
3. **Existing service bookings**: Link to new orders where applicable
4. **Initialize wallets**: Set `available_cents = 0`, `escrow_cents = 0` for all users

### Phase 3: Feature Rollout
1. **Enable new checkout flow** for new transactions
2. **Maintain backward compatibility** for existing payments
3. **Gradual migration** of existing transactions to new order system

---

## Implementation Notes

* **Backward Compatibility**: Existing payments continue to work while new system is built
* **Incremental Rollout**: New features can be enabled gradually without breaking existing functionality
* **Data Integrity**: All money movements use existing `payments` table structure
* **Chat Continuity**: Existing conversations seamlessly link to new orders

---

If you want, I can drop in:

* the SQL for `wallet`/`escrow` movements,
* example **RLS policies**, and
* a **Stripe Connect** skeleton (serverless endpoint + Supabase RPC) to make withdrawals a one-button flow.

