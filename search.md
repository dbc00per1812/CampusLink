# 🔍 Search & Discovery Implementation Plan

## 🎯 **Goal**
Add powerful search and discovery capabilities to the home page that enable users to quickly find relevant listings through text search, advanced filtering, and smart suggestions. Enhance the marketplace experience with intuitive search patterns similar to modern e-commerce platforms.

**Schema awareness**: Leverage existing `public.listings.tsv` tsvector field for full-text search, existing category/price/location fields for filtering, and current pagination patterns. No breaking database changes required.

---

## 📋 **Implementation Steps**

### **Phase 0 — Search Foundation & Feature Flag**
**Human explanation:**
- Add search infrastructure with feature flag to safely deploy search UI while ensuring backend readiness.

**Steps done in IDE by AI:**
- Add `enableSearch` config flag (default false)
- Create SearchModels.swift with search query, filter, and result models  
- Add SearchService stub for database operations
- Create basic SearchBarView component behind feature flag

**Steps done outside IDE by human:**
- Run database optimization SQL for search performance

### **Phase 1 — Basic Text Search**
**Human explanation:**
- Implement core text search using PostgreSQL full-text search capabilities with the existing tsv field.

**Steps done in IDE by AI:**
- Implement SearchService with full-text search queries
- Add SearchBarView to HomeTabView header
- Create SearchResultsView for displaying search results
- Integrate search with existing listing pagination
- Add search state management and debouncing

### **Phase 2 — Advanced Filters & Sorting**
**Human explanation:**
- Add comprehensive filtering options and sorting capabilities to refine search results.

**Steps done in IDE by AI:**
- Create SearchFiltersSheet with category, price range, location, type filters
- Add SortOptionsSheet with relevance, price, date, trust score sorting
- Integrate filters with search queries
- Add filter chips and active filter indicators
- Implement filter persistence across sessions

### **Phase 3 — Search Suggestions & History**
**Human explanation:**
- Add intelligent search suggestions, recent searches, and popular search terms.

**Steps done in IDE by AI:**
- Implement search suggestions based on existing listing titles/categories
- Add recent search history storage and display
- Create SearchSuggestionsView for autocomplete
- Add popular searches and trending categories
- Implement search analytics tracking

### **Phase 4 — Smart Discovery & Recommendations**
**Human explanation:**
- Add personalized recommendations and smart discovery features based on user behavior.

**Steps done in IDE by AI:**
- Implement "Recommended for You" based on search/view history
- Add "Similar Items" suggestions on listing details
- Create discovery sections (trending, new, popular)
- Add location-based recommendations
- Implement saved searches and alerts

---

## 🗄️ **Database Schema (Postgres/Supabase)**

```sql
-- No new tables required! Using existing schema optimally

-- Phase 0: Performance optimization indexes (safe to run now)
BEGIN;

-- Optimize existing full-text search
CREATE INDEX IF NOT EXISTS idx_listings_tsv_gin ON public.listings USING GIN(tsv);

-- Search performance indexes
CREATE INDEX IF NOT EXISTS idx_listings_search_active ON public.listings(status, archived) 
WHERE status = 'active' AND archived = false;

CREATE INDEX IF NOT EXISTS idx_listings_price_range ON public.listings(price) 
WHERE price IS NOT NULL;

CREATE INDEX IF NOT EXISTS idx_listings_category_search ON public.listings(category, status)
WHERE status = 'active';

CREATE INDEX IF NOT EXISTS idx_listings_location_search ON public.listings(service_location, status)
WHERE status = 'active' AND service_location IS NOT NULL;

-- Compound index for filtered searches
CREATE INDEX IF NOT EXISTS idx_listings_search_compound ON public.listings(
  status, archived, category, intent, created_at
) WHERE status = 'active' AND archived = false;

COMMIT;

-- Search ranking function (Phase 1)
CREATE OR REPLACE FUNCTION search_listings(
  search_term text DEFAULT '',
  category_filter text DEFAULT NULL,
  intent_filter text DEFAULT NULL,
  min_price numeric DEFAULT NULL,
  max_price numeric DEFAULT NULL,
  location_filter text DEFAULT NULL,
  listing_type_filter text DEFAULT NULL,
  trust_score_min integer DEFAULT NULL,
  sort_by text DEFAULT 'relevance',
  limit_count integer DEFAULT 20,
  offset_count integer DEFAULT 0
)
RETURNS TABLE(
  listing_data json,
  search_rank real
) AS $$
BEGIN
  RETURN QUERY
  SELECT 
    row_to_json(listings_with_user.*) as listing_data,
    CASE 
      WHEN search_term = '' THEN 0
      ELSE ts_rank(tsv, plainto_tsquery('simple', search_term))
    END as search_rank
  FROM (
    SELECT 
      l.*,
      u.name as user_name,
      u.email as user_email,
      u.trust_score as user_trust_score,
      u.profile_pic as user_profile_pic
    FROM public.listings l
    JOIN public.users u ON l.user_id = u.id
    WHERE l.status = 'active' 
      AND l.archived = false
      AND (search_term = '' OR tsv @@ plainto_tsquery('simple', search_term))
      AND (category_filter IS NULL OR l.category = category_filter)
      AND (intent_filter IS NULL OR l.intent = intent_filter)
      AND (min_price IS NULL OR l.price >= min_price)
      AND (max_price IS NULL OR l.price <= max_price)
      AND (location_filter IS NULL OR l.service_location = location_filter)
      AND (listing_type_filter IS NULL OR l.listing_type = listing_type_filter)
      AND (trust_score_min IS NULL OR u.trust_score >= trust_score_min)
  ) as listings_with_user
  ORDER BY 
    CASE sort_by
      WHEN 'relevance' THEN search_rank
      WHEN 'price_low' THEN -COALESCE(price, 0)
      WHEN 'price_high' THEN COALESCE(price, 0)
      WHEN 'newest' THEN EXTRACT(EPOCH FROM created_at)
      WHEN 'trust_score' THEN COALESCE(user_trust_score, 0)
      ELSE search_rank
    END DESC
  LIMIT limit_count
  OFFSET offset_count;
END;
$$ LANGUAGE plpgsql;

-- Search suggestions function (Phase 3)
CREATE OR REPLACE FUNCTION get_search_suggestions(partial_term text, max_suggestions integer DEFAULT 10)
RETURNS TABLE(suggestion text, category text, count bigint) AS $$
BEGIN
  RETURN QUERY
  WITH word_suggestions AS (
    SELECT DISTINCT
      unnest(string_to_array(title, ' ')) as word,
      category,
      1 as count
    FROM public.listings
    WHERE status = 'active' 
      AND archived = false
      AND unnest(string_to_array(lower(title), ' ')) LIKE lower(partial_term) || '%'
      AND char_length(unnest(string_to_array(title, ' '))) > 2
  ),
  title_suggestions AS (
    SELECT DISTINCT
      title as word,
      category,
      1 as count
    FROM public.listings
    WHERE status = 'active'
      AND archived = false  
      AND lower(title) LIKE '%' || lower(partial_term) || '%'
  )
  SELECT w.word, w.category, SUM(w.count)::bigint
  FROM (
    SELECT * FROM word_suggestions
    UNION ALL
    SELECT * FROM title_suggestions
  ) w
  GROUP BY w.word, w.category
  ORDER BY SUM(w.count) DESC, char_length(w.word) ASC
  LIMIT max_suggestions;
END;
$$ LANGUAGE plpgsql;
```

---

## 📱 **Swift Models**

```swift
// MARK: - Search Models

struct SearchQuery: Codable {
    var text: String = ""
    var filters: SearchFilters = SearchFilters()
    var sortBy: SortOption = .relevance
    var isActive: Bool {
        !text.isEmpty || filters.hasActiveFilters
    }
}

struct SearchFilters: Codable {
    var category: String?
    var intent: ListingIntent?
    var priceRange: PriceRange?
    var location: ServiceLocation?
    var listingType: ListingType?
    var minTrustScore: Int?
    
    var hasActiveFilters: Bool {
        category != nil || intent != nil || priceRange != nil || 
        location != nil || listingType != nil || minTrustScore != nil
    }
    
    var activeFilterCount: Int {
        [category != nil, intent != nil, priceRange != nil, 
         location != nil, listingType != nil, minTrustScore != nil]
        .filter { $0 }.count
    }
}

struct PriceRange: Codable {
    var min: Double?
    var max: Double?
    
    var isValid: Bool {
        if let min = min, let max = max {
            return min <= max && min >= 0
        }
        return (min ?? 0) >= 0 && (max ?? Double.greatestFiniteMagnitude) > 0
    }
}

enum SortOption: String, CaseIterable, Codable {
    case relevance = "relevance"
    case priceLow = "price_low"
    case priceHigh = "price_high"
    case newest = "newest"
    case trustScore = "trust_score"
    
    var displayName: String {
        switch self {
        case .relevance: return "Relevance"
        case .priceLow: return "Price: Low to High"
        case .priceHigh: return "Price: High to Low"
        case .newest: return "Newest First"
        case .trustScore: return "Highest Rated"
        }
    }
    
    var icon: String {
        switch self {
        case .relevance: return "star.fill"
        case .priceLow: return "arrow.up.circle"
        case .priceHigh: return "arrow.down.circle"
        case .newest: return "clock.fill"
        case .trustScore: return "shield.checkered"
        }
    }
}

struct SearchSuggestion: Codable, Identifiable {
    let id = UUID()
    let text: String
    let category: String?
    let count: Int
    let type: SuggestionType
    
    enum SuggestionType: String, Codable {
        case recent, suggestion, trending, category
    }
}

struct SearchResult: Codable {
    let listings: [ListingWithUser]
    let totalCount: Int
    let searchRank: [UUID: Float] // listing_id -> relevance score
    let suggestions: [SearchSuggestion]
    let hasMore: Bool
}

struct RecentSearch: Codable, Identifiable {
    let id = UUID()
    let query: SearchQuery
    let timestamp: Date
    let resultCount: Int
}
```

---

## 🎨 **UI Components & Flow**

### **1. Search Interface**
- **SearchBarView**: Modern search bar with voice input and clear button
- **SearchSuggestionsView**: Dropdown with autocomplete and recent searches  
- **SearchFiltersSheet**: Comprehensive filter panel with sections
- **SortOptionsSheet**: Sort selection with visual indicators

### **2. Results Display**
- **SearchResultsView**: Grid/list toggle with infinite scroll
- **SearchEmptyStateView**: No results with suggestions and clear filters
- **SearchLoadingView**: Skeleton loading with search context
- **ActiveFiltersView**: Horizontal scrollable filter chips

### **3. Discovery Features**
- **TrendingSearchesView**: Popular search terms and categories
- **RecommendedListingsView**: Personalized suggestions
- **SavedSearchesView**: Manage search alerts and bookmarks
- **SearchAnalyticsView**: User search insights (optional)

### **4. Integration Points**
- **HomeTabView**: Search bar in header, trending below filters
- **ListingDetailView**: "Search similar" button and related items
- **CategoryView**: Pre-filtered search integration
- **Navigation**: Deep link support for search URLs

---

## 🔍 **Search Algorithm & Relevance**

**Full-Text Search Scoring (PostgreSQL tsv):**
- **Exact title matches**: Highest weight (boost: 1.0)
- **Partial title matches**: High weight (boost: 0.8)  
- **Description matches**: Medium weight (boost: 0.4)
- **Category matches**: Low weight (boost: 0.2)

**Ranking Factors:**
- **Text relevance**: Base ts_rank score from PostgreSQL
- **Recency boost**: Newer listings get slight boost (0.1x days_fresh)
- **Trust score**: High-trust users get visibility boost (0.05x trust_score)
- **Engagement**: View count and interaction frequency (future)
- **Location**: Campus-specific boosts for local services

**Filter Priority:**
1. Active status and non-archived (hard filter)
2. Exact category matches (when specified)
3. Price range (when specified)  
4. Intent type (offer/seek)
5. Location and listing type
6. Trust score threshold

---

## 📊 **Success Metrics**

### **User Engagement**
- **Search usage**: >60% of users perform searches weekly
- **Search satisfaction**: <10% of searches result in filter changes
- **Discovery rate**: >30% of purchases come from search
- **Conversion**: Search results have 2x higher conversion than browse

### **Performance Metrics**
- **Search speed**: <200ms for text search, <500ms with filters
- **Relevance**: >80% of top 5 results considered relevant by users
- **Coverage**: Search finds >95% of active listings with correct keywords
- **Error rate**: <1% of searches result in errors or empty results

### **Business Impact**
- **Listing visibility**: All listings get discovered within 24 hours
- **User retention**: Search users have 40% higher 30-day retention
- **Transaction volume**: 25% increase in overall marketplace transactions
- **Support reduction**: 50% fewer "can't find item" support requests

---

## 🚀 **Implementation Timeline**

**Phase 0** (Week 1): Database optimization + search foundation + feature flag  
**Phase 1** (Week 2): Basic text search + results display + sorting  
**Phase 2** (Week 3): Advanced filters + saved filters + performance tuning  
**Phase 3** (Week 4): Search suggestions + history + analytics integration  
**Phase 4** (Week 5): Smart discovery + recommendations + search alerts  

---

## ✅ **Database Alignment Verification**

**Verified against current schema:**
- ✅ `public.listings.tsv` exists as tsvector for full-text search (line 53)
- ✅ All filter fields exist: category, price, intent, service_location, listing_type (lines 34-41,49)
- ✅ `public.users.trust_score` exists for ranking (line 246)
- ✅ Existing pagination patterns support search results
- ✅ RLS policies allow authenticated search access
- ✅ Foreign key relationships support joined queries (user data)

**Optimization opportunities:**
- 🔄 Add GIN index on tsv for faster text search
- 🔄 Add compound indexes for common filter combinations  
- 🔄 Implement search result caching for popular queries
- 🔄 Add search analytics table for usage tracking (optional)

**Ready for implementation** - All database references are accurate and search can leverage existing schema efficiently.

Darragh