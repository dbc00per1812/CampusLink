# 📊 Ratings & Trust System Implementation Plan

## 🎯 **Goal**
Add a comprehensive ratings system that builds user trust, provides feedback mechanisms, and helps establish reputation within the campus marketplace. Enable mutual ratings between buyers and sellers after completed transactions.

**Schema awareness**: Need to add `public.ratings` table, enhance user `trust_score` calculation, and integrate rating prompts into the order completion flow.

---

## ✅ Current State (aligned with codebase and schema)

- **Feature flag**: Ratings are currently disabled via `AppConfig.enableRatings = false`.
- **Models**: Implemented in `CampusLink/Core/Models/RatingModels.swift` (enums, DTOs, summaries, trust levels).
- **Service**: `CampusLink/Core/Services/RatingService.swift` supports submit, fetch user/order ratings, summary, update, report; all guarded by feature flag and using Supabase queries.
- **UI**:
  - `RatingsHistoryView` exists and loads/report ratings behind the flag.
  - `RatingComponents.swift` includes `RatingSummaryView`, `SellerRatingSummaryView`, and a compose flow used by `OrderDetailView`.
  - `OrderDetailView` checks `canSubmitRating(...)` for buyer/seller and conditionally enables rating.
  - `ProfileTabView` links to ratings history when flag is on.
- **Database (per context file)**: `public.ratings` table exists with expected columns; `public.users.trust_score` exists as `integer`. RLS policies and trust-score trigger functions are not present in the context file.

### Delta vs Original Plan

- Swift-side Phase 0/1 scaffolding is largely implemented and integrated behind a feature flag.
- DB-side automation (RLS, trust score function/trigger) from the plan is not present in `databaseinfoforcontext/databasefileforcontext.md` and needs to be added to the real dev DB before enabling the feature.
- Plan assumed enabling the feature post-DB migration; current state leaves the feature off pending DB verification.

### Minimal Next Actions to Go Live (safe, small steps)

1) Database (outside IDE; run against dev):
- Add RLS policies for `public.ratings` (select/insert) mirroring plan intent.
- Add `calculate_user_trust_score(uuid)` and `ratings_update_trust_score` trigger to auto-maintain `users.trust_score`.
- Verify `orders.order_status` values include `'completed'` used by app logic.

2) App config (IDE):
- Flip `AppConfig.enableRatings` to `true` after DB changes are verified.

3) UX polish (optional after enable):
- Surface seller summary on listing cards consistently and in profile header.
- Add empty-state messaging in `RatingsHistoryView` when no ratings.

## 📋 **Implementation Steps**

### **Phase 0 — Database Schema & Foundation**
**Human explanation:**
- Create ratings table structure and enhance user trust scoring system.

**Steps done in IDE by AI:**
- Create rating models and enums for the Swift app
- Add rating-related UI stubs behind feature flag
- Create RatingService for database operations

**Steps done outside IDE by human:**
- Run database migration to create ratings table and triggers

### **Phase 1 — Rating Submission Flow**
**Human explanation:**
- Allow users to rate each other after order completion with comments and star ratings.

**Steps done in IDE by AI:**
- Create RatingComposeView for submitting ratings
- Add rating prompts to order completion flow
- Implement rating submission to database
- Add mutual rating checks (both buyer and seller can rate)

### **Phase 2 — Rating Display & User Profiles**
**Human explanation:**
- Show user ratings, trust scores, and review history throughout the app.

**Steps done in IDE by AI:**
- Add rating displays to user profiles
- Show seller ratings on listings
- Create rating history views
- Implement trust score calculations

### **Phase 3 — Trust Score Integration**
**Human explanation:**
- Use trust scores for listing visibility, featured placement, and user verification.

**Steps done in IDE by AI:**
- Integrate trust scores into listing algorithms
- Add trust badges and verification indicators
- Implement rating-based filtering options

### **Phase 4 — Moderation & Analytics**
**Human explanation:**
- Add rating moderation, dispute resolution, and analytics dashboard.

**Steps done in IDE by AI:**
- Create rating moderation interfaces
- Add analytics for trust metrics
- Implement rating dispute flow

---

## 🗄️ **Database Schema (Postgres/Supabase)**

```sql
-- Ratings table for mutual user feedback
CREATE TABLE public.ratings (
  id uuid NOT NULL DEFAULT gen_random_uuid(),
  order_id uuid NOT NULL,
  rater_id uuid NOT NULL,      -- User giving the rating
  rated_id uuid NOT NULL,      -- User being rated
  rating integer NOT NULL CHECK (rating >= 1 AND rating <= 5),
  comment text,
  rating_type text NOT NULL CHECK (rating_type = ANY (ARRAY['buyer_to_seller'::text, 'seller_to_buyer'::text])),
  is_anonymous boolean DEFAULT false,
  created_at timestamp with time zone NOT NULL DEFAULT now(),
  updated_at timestamp with time zone DEFAULT now(),
  
  -- Moderation fields
  is_reported boolean DEFAULT false,
  is_hidden boolean DEFAULT false,
  moderation_status text DEFAULT 'approved'::text CHECK (moderation_status = ANY (ARRAY['pending'::text, 'approved'::text, 'rejected'::text])),
  
  CONSTRAINT ratings_pkey PRIMARY KEY (id),
  CONSTRAINT ratings_order_id_fkey FOREIGN KEY (order_id) REFERENCES public.orders(id),
  CONSTRAINT ratings_rater_id_fkey FOREIGN KEY (rater_id) REFERENCES public.users(id),
  CONSTRAINT ratings_rated_id_fkey FOREIGN KEY (rated_id) REFERENCES public.users(id),
  
  -- Prevent self-rating and duplicate ratings per order/user pair
  CONSTRAINT ratings_no_self_rating CHECK (rater_id <> rated_id),
  CONSTRAINT ratings_unique_per_order_user UNIQUE (order_id, rater_id, rated_id)
);

-- Performance indexes
CREATE INDEX idx_ratings_rated_user ON public.ratings(rated_id, moderation_status) WHERE is_hidden = false;
CREATE INDEX idx_ratings_order ON public.ratings(order_id);
CREATE INDEX idx_ratings_created_at ON public.ratings(created_at);

-- RLS Policies
ALTER TABLE public.ratings ENABLE ROW LEVEL SECURITY;

CREATE POLICY ratings_select ON public.ratings FOR SELECT TO authenticated
USING (moderation_status = 'approved' AND is_hidden = false);

CREATE POLICY ratings_insert ON public.ratings FOR INSERT TO authenticated
WITH CHECK (
  rater_id = auth.uid() AND
  EXISTS (
    SELECT 1 FROM public.orders o
    WHERE o.id = order_id 
    AND o.order_status = 'completed'
    AND (o.buyer_id = auth.uid() OR o.seller_id = auth.uid())
    AND (
      (o.buyer_id = auth.uid() AND rated_id = o.seller_id) OR
      (o.seller_id = auth.uid() AND rated_id = o.buyer_id)
    )
  )
);

-- Trust score calculation function
CREATE OR REPLACE FUNCTION calculate_user_trust_score(user_id uuid)
RETURNS numeric AS $$
DECLARE
  avg_rating numeric;
  total_ratings integer;
  trust_score numeric;
BEGIN
  SELECT AVG(rating::numeric), COUNT(*)
  INTO avg_rating, total_ratings
  FROM public.ratings
  WHERE rated_id = user_id 
  AND moderation_status = 'approved' 
  AND is_hidden = false;
  
  IF total_ratings = 0 THEN
    RETURN 50.0;  -- Neutral score for new users
  END IF;
  
  -- Base score from average rating (1-5 stars -> 0-80 points)
  trust_score := (avg_rating - 1) * 20;
  
  -- Volume bonus (up to 20 points)
  trust_score := trust_score + LEAST(total_ratings * 0.5, 20);
  
  RETURN GREATEST(LEAST(trust_score, 100), 0);
END;
$$ LANGUAGE plpgsql;

-- Auto-update trust scores
CREATE OR REPLACE FUNCTION update_user_trust_score()
RETURNS trigger AS $$
BEGIN
  UPDATE public.users 
  SET trust_score = calculate_user_trust_score(COALESCE(NEW.rated_id, OLD.rated_id))
  WHERE id = COALESCE(NEW.rated_id, OLD.rated_id);
  
  RETURN COALESCE(NEW, OLD);
END;
$$ LANGUAGE plpgsql;

CREATE TRIGGER ratings_update_trust_score
  AFTER INSERT OR UPDATE OR DELETE ON public.ratings
  FOR EACH ROW
  EXECUTE FUNCTION update_user_trust_score();
```

---

## 📱 **Swift Models**

```swift
// MARK: - Rating Models

enum RatingType: String, Codable, CaseIterable {
    case buyerToSeller = "buyer_to_seller"
    case sellerToBuyer = "seller_to_buyer"
    
    var displayName: String {
        switch self {
        case .buyerToSeller: return "Rate Seller"
        case .sellerToBuyer: return "Rate Buyer"
        }
    }
}

struct Rating: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let raterId: String
    let ratedId: String
    let rating: Int // 1-5 stars
    let comment: String?
    let ratingType: RatingType
    let isAnonymous: Bool
    let createdAt: Date
    let moderationStatus: String
    
    // Joined data
    var rater: User?
    var order: Order?
    
    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case raterId = "rater_id"
        case ratedId = "rated_id"
        case rating, comment
        case ratingType = "rating_type"
        case isAnonymous = "is_anonymous"
        case createdAt = "created_at"
        case moderationStatus = "moderation_status"
        case rater, order
    }
}

struct RatingCreate: Codable {
    let orderId: UUID
    let raterId: String
    let ratedId: String
    let rating: Int
    let comment: String?
    let ratingType: RatingType
    let isAnonymous: Bool
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case raterId = "rater_id"
        case ratedId = "rated_id"
        case rating, comment
        case ratingType = "rating_type"
        case isAnonymous = "is_anonymous"
    }
}

struct UserRatingsSummary: Codable {
    let averageRating: Double
    let totalRatings: Int
    let trustScore: Double
    let ratingsBreakdown: [Int: Int] // Star count -> Count
    
    enum CodingKeys: String, CodingKey {
        case averageRating = "average_rating"
        case totalRatings = "total_ratings"
        case trustScore = "trust_score"
        case ratingsBreakdown = "ratings_breakdown"
    }
}
```

---

## 🎨 **UI Components & Flow**

### **1. Rating Submission**
- **RatingComposeView**: Star selector + comment field + submit
- **Order completion trigger**: Auto-prompt for ratings
- **Mutual rating system**: Both buyer and seller rate each other

### **2. Display Components**
- **StarRatingView**: Show 1-5 stars (read-only)
- **TrustBadgeView**: Visual trust level indicator
- **RatingCardView**: Individual rating with comment
- **RatingSummaryView**: Average + breakdown

### **3. Integration Points**
- **Listing cards**: Show seller's average rating
- **User profiles**: Full ratings history
- **Order detail**: Rating submission/viewing
- **Search filters**: Filter by minimum trust score

---

## 🏆 **Trust Score Algorithm**

**Scale**: 0-100 points
- **Base Score**: (Average Rating - 1) × 20 = 0-80 points
- **Volume Bonus**: min(Total Ratings × 0.5, 20) = up to 20 points
- **New users**: Start at 50 (neutral)

**Trust Levels:**
- 🥇 **Trusted (80-100)**: Gold badge, priority visibility
- 🥈 **Reliable (60-79)**: Silver badge, normal visibility  
- 🥉 **New (40-59)**: Bronze badge, newer users
- ⚠️ **Caution (20-39)**: Warning indicator
- 🚫 **High Risk (0-19)**: Strong warning, limited visibility

---

## 🛡️ **Moderation Features**

### **Automatic Protection**
- One rating per order per user pair
- 30-day time limit for rating submission
- Profanity detection and filtering
- Spam pattern detection

### **Manual Review**
- User-reported inappropriate ratings
- Appeals process for disputed ratings
- Moderator dashboard for review queue

---

## 📊 **Success Metrics**

- **Engagement**: >70% of completed orders receive ratings
- **Quality**: <5% of ratings require moderation
- **Trust Building**: Average platform trust score increases
- **Business Impact**: Higher trust = more transactions

---

## 🚀 **Implementation Timeline**

**Phase 0** (Week 1): Database schema + basic models  
**Phase 1** (Week 2): Rating submission flow  
**Phase 2** (Week 3): Display throughout app  
**Phase 3** (Week 4): Trust integration & filtering  
**Phase 4** (Week 5): Moderation & analytics  

---

## ✅ **Database Alignment Verification**

**Verified against current schema:**
- ✅ `public.users.trust_score` exists as `integer` (line 227)
- ✅ `public.orders.order_status` exists as `text NOT NULL` (line 93)
- ✅ Foreign key references align with existing tables
- ✅ UUID types match existing patterns
- ✅ Timestamp fields use consistent `timestamp with time zone`
- ✅ RLS policies follow existing patterns

**Ready for implementation** - All database references are accurate and aligned with the current schema.

Darragh