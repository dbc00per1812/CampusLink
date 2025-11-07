<!-- 38841d7b-4e5e-4e46-a421-c0a482e14821 50d0dd71-7ae6-4715-9198-0bd0bebe28d4 -->
# Smart Recommendations & Search Implementation

## Overview

Transform CampusLink's home feed and search from simple chronological listing to intelligent, diversified recommendations with semantic search capabilities. This creates a superior discovery experience and reusable infrastructure for future personalization features.

---

## Phase 0: Category Diversification (Quick Fix - Now)

### Goal

Fix "4 iPhone cases in a row" problem by ensuring the initial 2x2 grid shows variety across categories and types.

### Implementation

#### 1. Create Diversification Service

**New file:** `CampusLink/Core/Services/RecommendationService.swift`

```swift
class RecommendationService {
    static let shared = RecommendationService()
    
    /// Diversify listings to show variety of categories and types
    func diversifyListings(_ listings: [ListingWithUser], count: Int = 4) -> [ListingWithUser] {
        // Algorithm:
        // 1. Split into products and services
        // 2. Aim for 3 products + 1 service (or best available mix)
        // 3. Within products, pick different categories
        // 4. Prefer recent and available items
    }
}
```

**Algorithm Details:**

- Target: 3 products (different categories) + 1 service
- If <4 total items, return all
- Products: Pick one from each category (Electronics, Books, Furniture, etc.)
- Services: Pick most recent service
- Within each category, prefer: newer, available quantity > 0, not expired

#### 2. Update HomeTabView

**File:** `CampusLink/Features/Home/HomeTabView.swift`

**Changes:**

- Add `@State private var diversifiedTopListings: [ListingWithUser] = []`
- After loading first page, call `RecommendationService.shared.diversifyListings(listings, count: 4)`
- Display diversified listings in 2x2 grid, then regular listings after
- Apply to: `.forYou`, `.all`, `.forSale` tabs

**Maintain:**

- Pagination still works (load full 20 items, just reorder top 4)
- Infinite scroll unchanged
- Campus filtering, blocked users filtering

#### 3. SQL Optimization

**New file:** `optimize_listing_queries.sql`

Add indexes for faster category filtering:

```sql
-- Index for category-based diversification
CREATE INDEX IF NOT EXISTS idx_listings_category_created 
ON listings(category, created_at DESC) 
WHERE status = 'active' AND archived = false AND is_sold = false;

-- Index for listing type + category
CREATE INDEX IF NOT EXISTS idx_listings_type_category 
ON listings(listing_type, category, created_at DESC)
WHERE status = 'active' AND archived = false AND is_sold = false;
```

### Success Criteria

- ✅ First 4 listings show at least 3 different categories
- ✅ Mix of products and services when both available
- ✅ No performance degradation (<100ms diversification)
- ✅ Works across For You, All, and Selling tabs

---

## Phase 1: Vector Embeddings Foundation (1-2 days)

### Goal

Add semantic understanding infrastructure to enable hybrid search and similarity-based recommendations.

### Database Setup

#### 1. Enable pgvector Extension

**New file:** `enable_vector_search.sql`

```sql
-- Enable pgvector extension for semantic search
CREATE EXTENSION IF NOT EXISTS vector;

-- Add embedding column to listings table
ALTER TABLE listings 
ADD COLUMN IF NOT EXISTS embedding vector(384);

-- Create index for fast similarity search (HNSW algorithm)
CREATE INDEX IF NOT EXISTS idx_listings_embedding 
ON listings USING hnsw (embedding vector_cosine_ops)
WHERE status = 'active' AND archived = false AND is_sold = false;
```

**Note:** Supabase's built-in embeddings use `gte-small` model (384 dimensions).

#### 2. Create Embedding Generation Function

**New file:** `create_embedding_function.sql`

```sql
-- Function to generate embeddings using Supabase AI
CREATE OR REPLACE FUNCTION generate_listing_embedding(
    listing_id UUID
)
RETURNS void
LANGUAGE plpgsql
SECURITY DEFINER
AS $$
DECLARE
    listing_text TEXT;
    embedding_result vector(384);
BEGIN
    -- Combine title, description, and category for embedding
    SELECT 
        title || ' ' || COALESCE(description, '') || ' ' || COALESCE(category, '')
    INTO listing_text
    FROM listings
    WHERE id = listing_id;
    
    -- Generate embedding using Supabase's built-in function
    SELECT ai.openai_embed(
        'text-embedding-3-small',
        listing_text
    ) INTO embedding_result;
    
    -- Update listing with embedding
    UPDATE listings
    SET embedding = embedding_result
    WHERE id = listing_id;
END;
$$;

-- Trigger to auto-generate embeddings on insert/update
CREATE OR REPLACE FUNCTION auto_generate_embedding()
RETURNS TRIGGER
LANGUAGE plpgsql
AS $$
BEGIN
    -- Generate embedding asynchronously (don't block insert)
    PERFORM generate_listing_embedding(NEW.id);
    RETURN NEW;
END;
$$;

-- Create trigger
DROP TRIGGER IF EXISTS trigger_generate_embedding ON listings;
CREATE TRIGGER trigger_generate_embedding
AFTER INSERT OR UPDATE OF title, description, category ON listings
FOR EACH ROW
EXECUTE FUNCTION auto_generate_embedding();
```

#### 3. Backfill Existing Listings

**New file:** `backfill_embeddings.sql`

```sql
-- Backfill embeddings for existing active listings
-- Run in batches to avoid timeout
DO $$
DECLARE
    listing_record RECORD;
BEGIN
    FOR listing_record IN 
        SELECT id 
        FROM listings 
        WHERE status = 'active' 
        AND archived = false 
        AND embedding IS NULL
        ORDER BY created_at DESC
        LIMIT 100  -- Process 100 at a time
    LOOP
        PERFORM generate_listing_embedding(listing_record.id);
    END LOOP;
END $$;

-- Check progress
SELECT 
    COUNT(*) FILTER (WHERE embedding IS NOT NULL) as with_embeddings,
    COUNT(*) FILTER (WHERE embedding IS NULL) as without_embeddings,
    COUNT(*) as total
FROM listings
WHERE status = 'active' AND archived = false;
```

**Run this multiple times until all listings have embeddings.**

---

## Phase 2: Hybrid Search Implementation (1-2 days)

### Goal

Replace keyword-only search with hybrid search (keyword + semantic) for better discovery.

### Database Functions

#### 1. Create Hybrid Search Function

**New file:** `create_hybrid_search.sql`

```sql
-- Hybrid search: combines keyword (ts_rank) + semantic (vector similarity)
CREATE OR REPLACE FUNCTION hybrid_search_listings(
    query_text TEXT DEFAULT NULL,
    category_filter TEXT DEFAULT NULL,
    min_price DECIMAL DEFAULT NULL,
    max_price DECIMAL DEFAULT NULL,
    intent_filter TEXT DEFAULT NULL,
    service_location_filter TEXT DEFAULT NULL,
    trust_min INTEGER DEFAULT NULL,
    trust_max INTEGER DEFAULT NULL,
    sort_by TEXT DEFAULT 'relevance',
    limit_count INTEGER DEFAULT 20,
    offset_count INTEGER DEFAULT 0
)
RETURNS TABLE (
    id UUID,
    user_id UUID,
    title TEXT,
    description TEXT,
    price DECIMAL,
    category TEXT,
    photo TEXT,
    photos TEXT[],
    intent TEXT,
    status TEXT,
    archived BOOLEAN,
    service_location TEXT,
    created_at TIMESTAMP WITH TIME ZONE,
    relevance_score REAL,
    user_name TEXT,
    user_email TEXT,
    user_campus TEXT,
    user_avatar_url TEXT,
    user_trust_score INTEGER
)
LANGUAGE plpgsql
AS $$
DECLARE
    query_embedding vector(384);
    keyword_weight FLOAT := 0.6;  -- 60% keyword, 40% semantic
    semantic_weight FLOAT := 0.4;
BEGIN
    -- Generate embedding for search query (if text provided)
    IF query_text IS NOT NULL AND query_text != '' THEN
        SELECT ai.openai_embed('text-embedding-3-small', query_text)
        INTO query_embedding;
    END IF;
    
    RETURN QUERY
    SELECT 
        l.id,
        l.user_id,
        l.title,
        l.description,
        l.price,
        l.category,
        l.photo,
        l.photos,
        l.intent,
        l.status,
        l.archived,
        l.service_location::text,
        l.created_at,
        -- Hybrid relevance score
        CASE 
            WHEN query_text IS NOT NULL AND query_text != '' THEN
                (
                    keyword_weight * ts_rank(l.tsv, plainto_tsquery('english', query_text)) +
                    semantic_weight * (1 - (l.embedding <=> query_embedding))
                )::REAL
            ELSE 
                1.0::REAL
        END as relevance_score,
        u.name as user_name,
        u.email as user_email,
        u.campus as user_campus,
        u.profile_pic as user_avatar_url,
        u.trust_score as user_trust_score
    FROM listings l
    INNER JOIN users u ON l.user_id = u.id::uuid
    WHERE 
        -- Only active, non-archived, non-sold listings
        l.status = 'active'
        AND l.archived = false
        AND l.is_sold = false
        -- Hybrid text search filter
        AND (
            query_text IS NULL 
            OR query_text = '' 
            OR l.tsv @@ plainto_tsquery('english', query_text)
            OR (l.embedding <=> query_embedding) < 0.5  -- Semantic similarity threshold
        )
        -- Category filter
        AND (category_filter IS NULL OR l.category = category_filter)
        -- Price range filter
        AND (min_price IS NULL OR l.price >= min_price)
        AND (max_price IS NULL OR l.price <= max_price)
        -- Intent filter (offer/seek)
        AND (intent_filter IS NULL OR l.intent = intent_filter)
        -- Service location filter
        AND (service_location_filter IS NULL OR l.service_location = service_location_filter)
        -- Trust score filter
        AND (trust_min IS NULL OR u.trust_score >= trust_min)
        AND (trust_max IS NULL OR u.trust_score <= trust_max)
    ORDER BY
        CASE 
            WHEN sort_by = 'relevance' AND query_text IS NOT NULL AND query_text != '' THEN
                relevance_score
        END DESC NULLS LAST,
        CASE WHEN sort_by = 'price_asc' THEN l.price END ASC NULLS LAST,
        CASE WHEN sort_by = 'price_desc' THEN l.price END DESC NULLS LAST,
        CASE WHEN sort_by = 'recent' OR sort_by IS NULL THEN l.created_at END DESC
    LIMIT limit_count
    OFFSET offset_count;
END;
$$;
```

### Swift Implementation

#### 2. Update SearchService

**File:** `CampusLink/Core/Services/SearchService.swift`

**Changes:**

- Update `searchListings()` to call `hybrid_search_listings` RPC instead of `search_listings`
- Add feature flag: `AppConfig.enableHybridSearch` (default: true)
- Fallback to keyword search if hybrid fails
- Keep all existing filters and parameters

#### 3. Test Hybrid Search

**File:** `test_hybrid_search.sql`

```sql
-- Test hybrid search with common queries
SELECT title, category, relevance_score
FROM hybrid_search_listings(
    query_text := 'laptop computer',
    limit_count := 10
)
ORDER BY relevance_score DESC;

-- Compare with keyword-only search
SELECT title, category, 
    ts_rank(tsv, plainto_tsquery('english', 'laptop computer')) as keyword_score
FROM listings
WHERE tsv @@ plainto_tsquery('english', 'laptop computer')
ORDER BY keyword_score DESC
LIMIT 10;
```

---

## Phase 3: Smart Recommendations (2-3 days)

### Goal

Use embeddings for "similar items" and personalized recommendations.

### Features

#### 1. Similar Items Function

**New file:** `create_similar_items_function.sql`

```sql
-- Find similar items based on vector similarity
CREATE OR REPLACE FUNCTION get_similar_listings(
    target_listing_id UUID,
    limit_count INTEGER DEFAULT 10
)
RETURNS TABLE (
    id UUID,
    title TEXT,
    price DECIMAL,
    category TEXT,
    similarity_score REAL
)
LANGUAGE sql
AS $$
    SELECT 
        l.id,
        l.title,
        l.price,
        l.category,
        (1 - (l.embedding <=> target.embedding))::REAL as similarity_score
    FROM listings l
    CROSS JOIN (
        SELECT embedding 
        FROM listings 
        WHERE id = target_listing_id
    ) target
    WHERE l.id != target_listing_id
    AND l.status = 'active'
    AND l.archived = false
    AND l.is_sold = false
    AND l.embedding IS NOT NULL
    ORDER BY l.embedding <=> target.embedding
    LIMIT limit_count;
$$;
```

#### 2. Add to RecommendationService

**File:** `CampusLink/Core/Services/RecommendationService.swift`

**Add methods:**

```swift
/// Get listings similar to a given listing (for "You might also like")
func getSimilarListings(to listingId: UUID, limit: Int = 10) async throws -> [ListingWithUser]

/// Get personalized recommendations based on user's viewed listings
func getPersonalizedRecommendations(for userId: String, limit: Int = 20) async throws -> [ListingWithUser]
```

**Implementation:**

- Call `get_similar_listings` RPC for similar items
- Track user views in UserDefaults (Phase 3 only)
- For personalized: average embeddings of viewed items, find similar listings

#### 3. Update Listing Detail View

**File:** `CampusLink/Features/Marketplace/Views/ListingDetailView.swift`

**Add:**

- "Similar items" section at bottom
- Load via `RecommendationService.shared.getSimilarListings()`
- Horizontal scroll of 5-10 similar listings

---

## Phase 4: Advanced Optimizations (Future)

### Potential Enhancements

1. **User Interaction Tracking**

   - Track views, clicks, purchases
   - Build user preference profile
   - Collaborative filtering

2. **Real-time Personalization**

   - User embedding (average of interacted items)
   - Session-based recommendations
   - A/B testing different algorithms

3. **Search Improvements**

   - Query expansion (synonyms)
   - Typo tolerance (fuzzy matching)
   - Filter recommendations based on common searches

4. **Performance Optimizations**

   - Cache embeddings in Redis
   - Pre-compute popular recommendations
   - Batch embedding generation

---

## Implementation Order

### Week 1: Phase 0 (Quick Win)

1. ✅ Create RecommendationService with diversification logic
2. ✅ Update HomeTabView to use diversified listings
3. ✅ Add SQL indexes for category filtering
4. ✅ Test on For You, All, and Selling tabs

### Week 2: Phase 1 (Foundation)

1. ✅ Enable pgvector extension
2. ✅ Add embedding column to listings
3. ✅ Create embedding generation function
4. ✅ Backfill embeddings for existing listings
5. ✅ Create embedding trigger for new listings

### Week 3: Phase 2 (Hybrid Search)

1. ✅ Create hybrid search function
2. ✅ Update SearchService to use hybrid search
3. ✅ Test search quality improvements
4. ✅ Monitor performance

### Week 4: Phase 3 (Recommendations)

1. ✅ Create similar items function
2. ✅ Add to RecommendationService
3. ✅ Update Listing Detail View
4. ✅ Test recommendation quality

---

## Files to Create

### Swift Files

1. `CampusLink/Core/Services/RecommendationService.swift` - Diversification + recommendations
2. `CampusLink/Core/Config/FeatureFlags.swift` - Add `enableHybridSearch` flag

### SQL Files (Run in Supabase SQL Editor)

1. `optimize_listing_queries.sql` - Indexes for diversification
2. `enable_vector_search.sql` - Enable pgvector + add embedding column
3. `create_embedding_function.sql` - Auto-generate embeddings
4. `backfill_embeddings.sql` - Backfill existing listings
5. `create_hybrid_search.sql` - Hybrid search function
6. `create_similar_items_function.sql` - Similar items function
7. `test_hybrid_search.sql` - Test queries

### Files to Modify

1. `CampusLink/Features/Home/HomeTabView.swift` - Use diversified listings
2. `CampusLink/Core/Services/SearchService.swift` - Use hybrid search
3. `CampusLink/Features/Marketplace/Views/ListingDetailView.swift` - Add similar items
4. `CampusLink/Core/Config/AppConfig.swift` - Add feature flags

---

## External Work (Supabase)

### Required SQL Scripts (In Order)

1. **optimize_listing_queries.sql** - Run immediately (no downtime)
2. **enable_vector_search.sql** - Run before Phase 1 (adds column, ~1min downtime)
3. **create_embedding_function.sql** - Run for Phase 1 (no downtime)
4. **backfill_embeddings.sql** - Run multiple times until complete (~5min per 100 listings)
5. **create_hybrid_search.sql** - Run for Phase 2 (no downtime)
6. **create_similar_items_function.sql** - Run for Phase 3 (no downtime)

### Supabase Dashboard Setup

**Enable AI features:**

1. Go to Supabase Dashboard → Project Settings → AI
2. Enable "Inference API" (free tier)
3. Select model: `gte-small` (384 dimensions)

**Monitor:**

- Check embedding generation progress in SQL editor
- Monitor function performance in Database → Performance Insights

---

## Success Metrics

### Phase 0

- Average categories in first 4 listings: >2.5
- User engagement (clicks on first 4): +20%
- Bounce rate: -15%

### Phase 1

- Embedding generation: 100% of active listings
- Embedding performance: <100ms per listing
- Index build time: <5min

### Phase 2

- Search relevance: User feedback improvement
- Hybrid vs keyword: A/B test shows +25% click-through
- Search performance: <500ms for hybrid queries

### Phase 3

- Similar items accuracy: >70% same category
- Recommendation click-through: >10%
- Detail view engagement: +30% time on page

---

## Risk Mitigation

### Performance

- **Risk:** Vector search slow on large datasets
- **Mitigation:** HNSW index, limit to active listings only, cache results

### Cost

- **Risk:** Embedding API costs too high
- **Mitigation:** Supabase built-in is free; only generate on insert/update

### Quality

- **Risk:** Poor recommendation quality
- **Mitigation:** A/B test against baseline, gather user feedback, tune weights

### Data

- **Risk:** Missing embeddings for old listings
- **Mitigation:** Backfill script with progress tracking, graceful fallback

---

## Rollout Strategy

1. **Phase 0:** Deploy to 100% immediately (low risk, high value)
2. **Phase 1:** Deploy embeddings infrastructure, monitor generation
3. **Phase 2:** A/B test hybrid search at 10% → 50% → 100%
4. **Phase 3:** Feature flag for similar items, gradual rollout

**Rollback Plan:**

- Phase 0: Remove diversification, revert to chronological
- Phase 2: Disable hybrid search flag, use keyword-only
- Phase 3: Disable similar items feature flag

### To-dos

- [ ] Create RecommendationService.swift with category diversification algorithm (3 products + 1 service from different categories)
- [ ] Update HomeTabView to use diversified listings for first 4 items in For You, All, and Selling tabs
- [ ] Create and run optimize_listing_queries.sql to add category-based indexes
- [ ] Test diversification across all tabs, verify no performance degradation
- [ ] Create and run enable_vector_search.sql to enable pgvector extension and add embedding column
- [ ] Create and deploy create_embedding_function.sql for auto-generating embeddings using Supabase AI
- [ ] Run backfill_embeddings.sql multiple times to generate embeddings for all existing active listings
- [ ] Enable Inference API in Supabase Dashboard and configure gte-small model
- [ ] Create and deploy create_hybrid_search.sql with hybrid search combining keyword + semantic
- [ ] Update SearchService.swift to call hybrid_search_listings RPC instead of search_listings
- [ ] Add enableHybridSearch feature flag to AppConfig.swift with fallback to keyword search
- [ ] Test hybrid search quality and performance, compare with keyword-only search
- [ ] Create and deploy create_similar_items_function.sql for vector-based similarity search
- [ ] Add getSimilarListings() and getPersonalizedRecommendations() to RecommendationService.swift
- [ ] Add 'Similar items' section to ListingDetailView.swift using RecommendationService
- [ ] Test similar items quality and engagement metrics on detail view