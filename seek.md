### Goal
Add a Seeking mode so users can post what they want to buy (products or services) from the same Post tab, and let sellers respond with offers that can convert into standard orders.

Schema awareness: the current schema in `databasefileforcontext.md` already includes `public.listings.intent` (`offer|seek`), `budget_min`, `budget_max`, `expires_at`, a `tsv` full‑text column, and an `public.offers` table. The only breaking change we must time with the app release is allowing `listings.price` to be `NULL` for seek posts and enforcing a conditional price constraint.

---

## Implementation Steps

### Phased Plan (Prompt-ready)

### Phase 0 — Preparation & Guardrails
Human explanation:
- Add a feature flag so Seek UI can be merged safely and hidden until DB Phase 2.

steps that are done in the ide by AI:
- Introduce `enableSeekMode` config (default false).
- Wrap Seek UI and routes behind the flag.
- Create stubs for `OfferComposeView` and offers list (no backend writes yet).

steps that must be done outside of the ide by the human:
- None.

### Phase 1 — Database Indexes & RLS (safe now)
Human explanation:
- Prepare DB for fast queries and secure offers without changing `price` yet.

steps that are done in the ide by AI:
- None (pure SQL run externally).

steps that must be done outside of the ide by the human:
- Run the Phase 1 SQL block below in Supabase (indexes + RLS for `public.offers`).

### Phase 2 — Client Models & Post UI
Human explanation:
- Add Seek-aware models and UI, but prevent publishing seek posts until DB allows NULL `price`.

steps that are done in the ide by AI:
- Add `ListingIntent` enum and CodingKeys for `intent/budget_min/budget_max/expires_at`.
- Update `PostView` with Sell | Seek toggle and conditional fields.
- Update create call to send the new fields; guard submit behind feature flag.
- Add filters and badges for seeks in feed/profile.
- `ListingDetailView`: “Offer My Item” for non-owners; owner sees offers list (stub).

steps that must be done outside of the ide by the human:
- None.

### Phase 3 — DB Price Rule Flip (requires app ready)
Human explanation:
- Allow `price` to be NULL for seeks and enforce conditional price CHECK.

steps that are done in the ide by AI:
- Ensure UI doesn’t rely on `price` for seeks; show budgets instead.
- Toggle feature flag ON after SQL is applied.

steps that must be done outside of the ide by the human:
- Run the Phase 2 SQL block (ALTER price + conditional CHECK).

### Phase 4 — Offers Flow & Messaging
Human explanation:
- Sellers respond to seeks; acceptance converts to order and opens chat.

steps that are done in the ide by AI:
- Implement `OfferComposeView` and offer creation.
- Implement offers list with Accept/Decline; on Accept create order with `offer_listing_id` (and `time_slot_id` when needed) and archive the seek.

steps that must be done outside of the ide by the human:
- Optional: deploy `create_offer` and `accept_offer` Edge Functions for server-side validation and system messages.

### Phase 5 — QA & Rollout
Human explanation:
- Validate end-to-end and enable for all users.

steps that are done in the ide by AI:
- Add analytics/logs; add empty states and error messaging.
- Final UI polish and accessibility pass.

steps that must be done outside of the ide by the human:
- Device smoke tests with two accounts; verify RLS.
- If stable, leave the feature flag enabled for everyone.

Human explanation:
- We’ll introduce a Sell | Seek toggle in the Post tab, persist seeks using existing columns, let sellers respond via the existing `offers` table, and only flip the database to allow NULL price after the app is updated. This avoids breaking current clients.

steps that are done in the ide by AI:
1. Models
   - Add `ListingIntent` enum and map CodingKeys for `intent`, `budget_min`, `budget_max`, `expires_at`.
   - Keep `price` non-optional until Phase 2.
2. Post tab UI (`PostView`)
   - Add segmented picker for `intent`.
   - Intent = offer: unchanged price entry.
   - Intent = seek: hide price; show budget min/max and expiration.
   - Send `intent/budgetMin/budgetMax/expiresAt` in create call.
3. Feed/Profile/Detail
   - Add filter chips (All | For Sale | Wanted) and “Wanted” badge.
   - On seek detail: show “Offer My Item” for non-owners; owner sees offers list with Accept/Decline.
4. `OfferComposeView`
   - Surface seller’s active offers (`intent='offer' AND status='active' AND archived=false`).
   - Post offer then open chat.
5. Service support
   - Keep slot-based flow; pass `time_slot_id` when applicable.
6. Feature flag
   - Gate seek publishing until Phase 2 SQL is applied.

steps that must be done outside of the ide by the human:
1. Supabase SQL – Phase 1 (safe now)
```sql
CREATE EXTENSION IF NOT EXISTS pgcrypto;

BEGIN;
CREATE INDEX IF NOT EXISTS idx_listings_intent ON public.listings(intent);
CREATE INDEX IF NOT EXISTS idx_listings_expires_at ON public.listings(expires_at);
CREATE INDEX IF NOT EXISTS idx_listings_category_intent ON public.listings(category, intent);
CREATE INDEX IF NOT EXISTS idx_listings_tsv ON public.listings USING GIN(tsv);
CREATE INDEX IF NOT EXISTS idx_offers_seek_status ON public.offers(seek_listing_id, status);
CREATE INDEX IF NOT EXISTS idx_offers_seller_status ON public.offers(seller_id, status);
COMMIT;

ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;
CREATE POLICY IF NOT EXISTS offers_insert ON public.offers FOR INSERT TO authenticated
  WITH CHECK (seller_id = auth.uid() AND seeker_id <> auth.uid());
CREATE POLICY IF NOT EXISTS offers_select ON public.offers FOR SELECT TO authenticated
  USING (seller_id = auth.uid() OR seeker_id = auth.uid());
CREATE POLICY IF NOT EXISTS offers_update ON public.offers FOR UPDATE TO authenticated
  USING (seller_id = auth.uid() OR seeker_id = auth.uid())
  WITH CHECK (seller_id = auth.uid() OR seeker_id = auth.uid());
```
2. Supabase SQL – Phase 2 (run after app update)
```sql
BEGIN;
ALTER TABLE public.listings ALTER COLUMN price DROP NOT NULL;
ALTER TABLE public.listings DROP CONSTRAINT IF EXISTS listings_price_by_intent_chk,
  ADD CONSTRAINT listings_price_by_intent_chk CHECK (
    (intent = 'offer' AND price IS NOT NULL AND price > 0)
    OR (intent = 'seek' AND price IS NULL)
  );
COMMIT;
```
3. Deploy optional Edge Functions: `create_offer`, `accept_offer`.
4. Release cadence: ship app with Seek UI (guarded) → apply Phase 2 SQL → unhide Seek publishing.

---

## UX/Flows

- **Post tab (single screen)**
  - Segmented control: Sell (Offer) | Seek (Wanted)
  - Shared fields: Title, Description, Category, Listing Type (Product/Service), Optional Photo, Campus visibility, Expiration.
  - Validation:
    - Offer: requires price
    - Seek: price hidden; requires budget min/max or at least max
- **Feed & Filters**
  - Toggle: All | For Sale | Wanted
  - Cards:
    - Offer card: current style
    - Seek card: “Wanted” badge + budget range + expiration chip
- **Seek Detail**
  - If viewer is not owner: “Offer My Item” → select one of my active listings (or quick-create) → send Offer + open chat
  - If owner: list of incoming offers with actions Accept / Decline
- **Accept Offer**
  - Converts Offer → Order using seller’s `offer_listing_id` (supports existing product/service + optional `time_slot_id`)
  - Auto-archives the Seek post and marks Offer accepted
- **Expiry**
  - Seek auto-archives at `expires_at` and pending offers move to `expired`

---

## Database Changes (Postgres/Supabase)

Because key columns and `public.offers` already exist, migrations are minimal. Use a phased rollout so current clients aren’t broken by `price` becoming nullable for seek posts.

```sql
-- 0) Pre-req: ensure pgcrypto for gen_random_uuid() exists
CREATE EXTENSION IF NOT EXISTS pgcrypto;

-- Phase 1 (safe now): ensure indexes + RLS on offers. Do NOT change price nullability yet.
BEGIN;

-- Listings helpers (columns already exist in current schema)
CREATE INDEX IF NOT EXISTS idx_listings_intent ON public.listings(intent);
CREATE INDEX IF NOT EXISTS idx_listings_expires_at ON public.listings(expires_at);
CREATE INDEX IF NOT EXISTS idx_listings_category_intent ON public.listings(category, intent);
CREATE INDEX IF NOT EXISTS idx_listings_tsv ON public.listings USING GIN(tsv);

-- Offers table already exists; ensure helpful indexes exist
CREATE INDEX IF NOT EXISTS idx_offers_seek_status ON public.offers(seek_listing_id, status);
CREATE INDEX IF NOT EXISTS idx_offers_seller_status ON public.offers(seller_id, status);

COMMIT;

-- Phase 2 (ship when app supports Seek): make price nullable for seeks and add conditional check
BEGIN;

ALTER TABLE public.listings
  ALTER COLUMN price DROP NOT NULL;

ALTER TABLE public.listings
  DROP CONSTRAINT IF EXISTS listings_price_by_intent_chk,
  ADD CONSTRAINT listings_price_by_intent_chk CHECK (
    (intent = 'offer' AND price IS NOT NULL AND price > 0)
    OR
    (intent = 'seek' AND price IS NULL)
  );

COMMIT;
```

### RLS (sketch aligned to your uuids)
```sql
-- Enable RLS for offers
ALTER TABLE public.offers ENABLE ROW LEVEL SECURITY;

-- Create (seller proposes to seeker)
CREATE POLICY offers_insert ON public.offers
FOR INSERT TO authenticated
WITH CHECK (
  seller_id = auth.uid() AND seeker_id <> auth.uid()
);

-- Read (either party)
CREATE POLICY offers_select ON public.offers
FOR SELECT TO authenticated
USING (seller_id = auth.uid() OR seeker_id = auth.uid());

-- Update status (either party)
CREATE POLICY offers_update ON public.offers
FOR UPDATE TO authenticated
USING (seller_id = auth.uid() OR seeker_id = auth.uid())
WITH CHECK (seller_id = auth.uid() OR seeker_id = auth.uid());
```

---

## Client/Data Models (Swift)

- New intent enum + listing fields; consistent with current models and CodingKeys.

```swift
enum ListingIntent: String, Codable, CaseIterable {
  case offer, seek
  var displayName: String { self == .offer ? "Sell" : "Seek" }
}

struct Listing: Codable, Identifiable {
  // existing fields...
  let intent: ListingIntent           // maps to "intent"
  let budgetMin: Double?              // "budget_min"
  let budgetMax: Double?              // "budget_max"
  let expiresAt: Date?                // "expires_at"
  // NOTE: price remains non-optional in current app; make it optional when Phase 2 is deployed
  // CodingKeys: add intent, budget_min, budget_max, expires_at
}

struct ListingCreate: Codable {
  // existing fields...
  let intent: ListingIntent
  let budgetMin: Double?
  let budgetMax: Double?
  let expiresAt: Date?
}

struct Offer: Codable, Identifiable {
  let id: UUID
  let seekListingId: UUID
  let offerListingId: UUID
  let seekerId: String
  let sellerId: String
  let message: String?
  let status: String
  let createdAt: Date
  let updatedAt: Date
}
```

---

## UI Changes (SwiftUI)

- `PostView`
  - Add segmented picker bound to `intent: .offer | .seek`
  - If `.offer`: existing UI unchanged
  - If `.seek`:
    - Hide price; show budget min/max; show expiration date picker
    - For services: keep duration/location/availability; hide slot config
  - Insert with `intent/budgetMin/budgetMax/expiresAt`
- Feed/Profile
  - Add filter chip/menu: All | For Sale | Wanted
  - Card badges:
    - `.offer`: current
    - `.seek`: “Wanted” with budget range display
- `ListingDetailView`
  - If `.seek` and viewer != owner → button “Offer My Item”
    - Opens `OfferComposeView`: choose one of my active listings, add optional note, submit
  - If owner of a `.seek` → view incoming offers (list), Accept/Decline
- `OfferComposeView`
  - Fetch my active `listings.intent='offer' AND archived=false AND status='active'`
  - Submit → create offer + open chat with seeker

---

## Supabase RPC/Edge Functions

- `create_offer`
  - Validate: seller owns `offer_listing_id`; `seek_listing_id.intent='seek'`; both not archived/expired
  - Prevent duplicate pending offers for same pair
  - Insert into `public.offers`
  - Create/find conversation between seller and seeker for the seek (reusing `public.conversations`)
  - Post first system message (“Seller offered <title> for $X”)
- `accept_offer`
  - Validate ownership (seeker)
  - Update offer status → `accepted`; archive `seek_listing_id`; cancel other pending offers for that seek
  - Create `orders` row using `offer_listing_id` as `listing_id` (and pass `time_slot_id` if service slots)
  - Return necessary data for payment flow (if using card, reuse `create_payment_intent`)
- `decline_offer` / `withdraw_offer`
  - Status transitions with audit

---

## Matching/Discovery

- On new/updated listing (via DB trigger or Edge function):
  - If new `.seek`: find `.offer` matches where:
    - same category, `status='active' AND archived=FALSE`
    - product: `price BETWEEN budget_min AND budget_max`
    - service: lightweight text rank using `tsv` and category
  - If new `.offer`: symmetrically match open seeks
  - Deliver notifications and in-app suggestions (“Offer to 3 seekers” or “3 items match your seek”)

Example query for sellers to find seekers:
```sql
SELECT *
FROM public.listings
WHERE intent = 'seek'
  AND archived IS NOT TRUE
  AND (expires_at IS NULL OR expires_at > now())
  AND category = $1
  AND (budget_min IS NULL OR budget_min <= $price)
  AND (budget_max IS NULL OR budget_max >= $price)
ORDER BY created_at DESC
LIMIT 50;
```

---

## Migration & Rollout

1. Run Phase 1 SQL (indexes; do not change price nullability yet).
2. Ensure/enable RLS policies for `public.offers`.
3. Update Swift models (`ListingIntent`, fields, CodingKeys).
4. Update `PostView` to include intent picker and conditional UI.
5. Add filters in feed/profile; adjust queries to include `intent`.
6. Build `OfferComposeView` and offer list on Seek detail.
7. Implement `create_offer`, `accept_offer` (Edge Functions) and wire into app.
8. Deploy Phase 2 SQL once the app is ready to handle `NULL` price for seeks.
9. QA end-to-end:
   - Create Seek (product and service)
   - Seller makes Offer (product and service/slot)
   - Accept → Order/Payment works; seek auto-archives
   - Expiry cron/trigger works; RLS blocks unauthorized access

---

## QA Checklist

- Seek creation allows NULL `price` and enforces budget ordering.
- Feed filter toggles correctly; cards labeled “Wanted”.
- Offers restricted by RLS to involved parties.
- Accepting an offer creates `orders` referencing the seller’s listing (not the seek).
- Service with time slots flows through with `orders.time_slot_id`.
- Seeks auto-archive on `expires_at` or on accept; pending offers → `expired`.

---

## Notes/Constraints From Current Schema

- `orders` already supports `time_slot_id`, so service/scheduling offers are compatible.
- `listings.status` and `archived` fields already exist; reuse for visibility.
- `conversations/messages` tables exist; reuse for offer messaging.
- Currency fields are `numeric` in `listings`/`payments` (use cents in orders), budget uses `numeric` for consistency.

If you want, I can generate the exact Swift edits for `PostView`, `ProductModels.swift`, and the minimal Deno code for `create_offer`/`accept_offer`. Darragh