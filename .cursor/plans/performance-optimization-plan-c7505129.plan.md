<!-- c7505129-d482-483e-8697-2cdf510fa2eb 41cf48a5-3522-4f9a-a48e-19a014aa97a1 -->
# Performance Optimization Plan: Instant-Feel Loading

## Goal

Achieve Instagram/TikTok level instant loading across the entire app through aggressive caching, prefetching, optimistic UI updates, and database query optimization.

## Current Performance Analysis

### What's Working

- ✅ Pagination on home feed (20 items/page)
- ✅ Basic image caching (memory + disk)
- ✅ Server-side campus filtering
- ✅ Blocked users filtering

### What Needs Optimization

- ❌ No data caching (re-fetches on every view)
- ❌ Sequential loading (blocking UI)
- ❌ N+1 queries in transactions
- ❌ No prefetching strategy
- ❌ Spinners instead of skeletons
- ❌ Chat loads all messages each time
- ❌ Profile re-fetches listings every appear

---

## Phase 1: Quick Wins - Perceived Performance (Days 1-2)

### 1.1 Loading Skeletons

Replace all `ProgressView()` with skeleton screens for instant perceived loading.

**Files to modify:**

- `HomeTabView.swift` - Replace loading view with grid skeleton
- `MyTransactionsView.swift` - Add transaction row skeletons
- `ProfileTabView.swift` - Add profile + listings skeleton
- `ChatView.swift` - Add message skeleton

**Implementation:**

```swift
struct ListingCardSkeleton: View {
    @State private var isAnimating = false
    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Rectangle()
                .fill(Color.gray.opacity(0.3))
                .aspectRatio(1, contentMode: .fit)
                .shimmer(isAnimating: $isAnimating)
            VStack(alignment: .leading, spacing: 6) {
                Rectangle().fill(Color.gray.opacity(0.3))
                    .frame(height: 20)
                Rectangle().fill(Color.gray.opacity(0.3))
                    .frame(height: 16)
            }.padding(12)
        }
        .cornerRadius(12)
        .onAppear { isAnimating = true }
    }
}
```

### 1.2 Optimistic UI Updates

Show UI immediately, update in background.

**HomeTabView changes:**

- Show cached listings instantly on appear
- Refresh in background
- Only show skeleton on true first load

---

## Phase 2: Data Caching Layer (Days 2-4)

### 2.1 Create DataCacheManager

Centralized cache for all data types with TTL (Time To Live).

**New file:** `Core/Services/DataCacheManager.swift`

**Features:**

- Memory cache with configurable TTL
- Cache listings, orders, users, conversations
- Automatic cache invalidation
- Cache warming on app launch

**Implementation approach:**

```swift
class DataCacheManager {
    static let shared = DataCacheManager()
    
    private var listingsCache: [String: CachedData<[ListingWithUser]>] = [:]
    private var ordersCache: CachedData<[Order]>?
    private var userCache: [String: CachedData<User>] = [:]
    
    struct CachedData<T> {
        let data: T
        let timestamp: Date
        let ttl: TimeInterval
        
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < ttl
        }
    }
    
    // Cache listings by filter key
    func cacheListings(_ listings: [ListingWithUser], forKey key: String, ttl: TimeInterval = 300) // 5min
    func getListings(forKey key: String) -> [ListingWithUser]?
    
    // Cache orders
    func cacheOrders(_ orders: [Order], ttl: TimeInterval = 60) // 1min for fresh transactions
    func getOrders() -> [Order]?
    
    // Invalidation
    func invalidateListings()
    func invalidateOrders()
}
```

### 2.2 Integrate Cache into Views

**HomeTabView:**

- Check cache first on appear
- Show cached data instantly
- Fetch fresh data in background
- Update cache after successful fetch

**MyTransactionsView:**

- Cache purchases and sales separately
- Aggressive caching (1 min TTL) since orders change frequently
- Invalidate on pull-to-refresh

**ProfileTabView:**

- Cache user profile (longer TTL: 10 min)
- Cache user listings (5 min TTL)

---

## Phase 3: Database Query Optimization (Days 4-5)

### 3.1 Reduce N+1 Queries in Transactions

**Current issue:** MyTransactionsView fetches orders with nested listing in a single query, which is good. But we could optimize further.

**Optimization:**

```sql
-- Ensure database has proper indexes
CREATE INDEX IF NOT EXISTS idx_orders_buyer_created ON orders(buyer_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_orders_seller_created ON orders(seller_id, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_listings_user_id ON listings(user_id);
```

**New file:** `optimize_transaction_queries.sql`

### 3.2 Optimize Home Feed Queries

**Current:** Good pagination, but could add:

- Index on campus + created_at for faster campus filtering
- Composite index for common queries
```sql
CREATE INDEX IF NOT EXISTS idx_listings_campus_created ON listings(status, archived, is_sold, created_at DESC);
CREATE INDEX IF NOT EXISTS idx_users_campus ON users(campus);
```


**New file:** `optimize_home_feed_queries.sql`

### 3.3 Add Database Views for Complex Queries

Create materialized views for frequently accessed data combinations.

```sql
-- Fast access to active listings with user info
CREATE OR REPLACE VIEW active_listings_with_users AS
SELECT 
    l.*,
    u.name as user_name,
    u.campus as user_campus,
    u.profile_picture_url as user_profile_picture
FROM listings l
JOIN users u ON l.user_id = u.id
WHERE l.status = 'active' 
  AND l.archived = false 
  AND l.is_sold = false;
```

---

## Phase 4: Intelligent Prefetching (Days 5-6)

### 4.1 Enhanced Image Prefetching

**Current:** Basic prefetching exists but could be smarter.

**Improvements:**

- Prefetch next page of images when user scrolls to 50% of current page
- Prefetch in chunks (next 10 listings)
- Cancel prefetch if user navigates away

**HomeTabView enhancement:**

```swift
.onAppear {
    if listing.id == listings[listings.count / 2].id {
        // User is at 50% - prefetch next page
        Task { await prefetchNextPageImages() }
    }
}

private func prefetchNextPageImages() async {
    let nextPageStart = (currentPage + 1) * pageSize
    let nextPageEnd = nextPageStart + pageSize
    
    // Estimate URLs for next page
    let urlsToPrefetch = estimateNextPageImageURLs()
    ImageCacheManager.shared.prefetchImages(urls: urlsToPrefetch)
}
```

### 4.2 Predictive Data Prefetching

**New file:** `Core/Services/PrefetchService.swift`

**Strategy:**

- When user opens transactions, prefetch conversation data for top 3 orders
- When user scrolls home feed, prefetch listing details for visible items
- When user enters chat, prefetch user profile

---

## Phase 5: Background Refresh (Days 6-7)

### 5.1 Implement Smart Background Refresh

**New file:** `Core/Services/BackgroundRefreshManager.swift`

**Features:**

- Refresh data when app returns to foreground (already partially implemented in MyTransactionsView)
- Refresh silently without blocking UI
- Use cached data while refreshing
- Show subtle indicator when fresh data loads

**Pattern:**

```swift
class BackgroundRefreshManager {
    static let shared = BackgroundRefreshManager()
    
    func refreshHomeListings(silently: Bool = true, onComplete: @escaping ([ListingWithUser]) -> Void)
    func refreshOrders(silently: Bool = true, onComplete: @escaping ([Order]) -> Void)
    
    // Track last refresh time to avoid over-refreshing
    private var lastRefreshTimes: [String: Date] = [:]
    
    func shouldRefresh(forKey key: String, minInterval: TimeInterval = 60) -> Bool {
        guard let lastRefresh = lastRefreshTimes[key] else { return true }
        return Date().timeIntervalSince(lastRefresh) > minInterval
    }
}
```

### 5.2 Add to All Major Views

**HomeTabView:** Refresh on scene phase change

**MyTransactionsView:** Already implemented, enhance with cache

**ChatView:** Refresh messages on appear

**ProfileTabView:** Refresh user data on appear

---

## Phase 6: Messaging Optimization (Days 7-8)

### 6.1 Optimize ChatView Loading

**Current issue:** Loads all messages each time view appears

**Optimizations:**

- Cache messages locally
- Only fetch new messages since last load
- Implement pagination for old messages
- Use realtime subscriptions instead of polling

**ChatViewModel enhancement:**

```swift
class ChatViewModel: ObservableObject {
    private var messageCache: [String: [Message]] = [:]
    private var lastMessageTimestamp: Date?
    
    func loadMessages() async {
        // 1. Show cached messages instantly
        if let cached = messageCache[conversationId] {
            await MainActor.run { self.messages = cached }
        }
        
        // 2. Fetch only new messages
        if let lastTimestamp = lastMessageTimestamp {
            let newMessages = try await fetchMessagesSince(lastTimestamp)
            await MainActor.run { 
                self.messages.append(contentsOf: newMessages)
                messageCache[conversationId] = self.messages
            }
        } else {
            // First load - fetch recent 50
            let recentMessages = try await fetchRecentMessages(limit: 50)
            await MainActor.run {
                self.messages = recentMessages
                messageCache[conversationId] = recentMessages
            }
        }
    }
}
```

### 6.2 Implement Message Pagination

**New feature:** Load old messages on scroll-to-top

- Initial load: 50 most recent
- On scroll up: Load 50 older messages
- Cache all loaded messages

---

## Phase 7: Image Optimization (Days 8-9)

### 7.1 Optimize Image Compression

**Current:** Images cached at 0.8 quality - could be optimized per use case.

**ImageCacheManager enhancements:**

```swift
enum ImageQuality {
    case thumbnail  // 0.5 quality, max 200x200
    case medium     // 0.7 quality, max 800x800
    case full       // 0.9 quality, original size
}

func getImage(for urlString: String, quality: ImageQuality = .medium) async -> UIImage?

// Generate thumbnail URLs from full URLs
func thumbnailURL(from fullURL: String) -> String {
    // If using Supabase storage, can add transform params
    // Example: ?width=200&height=200&quality=50
}
```

**HomeTabView update:**

- Use thumbnail quality for grid cards
- Use medium quality for detail view
- Preload thumbnails aggressively

### 7.2 Add Progressive Image Loading

Show low-quality placeholder, then swap to high-quality.

**CachedAsyncImage enhancement:**

```swift
struct CachedAsyncImage: View {
    @State private var thumbnailImage: UIImage?
    @State private var fullImage: UIImage?
    
    var body: some View {
        Group {
            if let full = fullImage {
                content(Image(uiImage: full))
            } else if let thumb = thumbnailImage {
                content(Image(uiImage: thumb))
                    .onAppear { loadFullImage() }
            } else {
                placeholder()
            }
        }
    }
}
```

---

## Phase 8: Advanced Optimizations (Days 9-10)

### 8.1 Implement Request Deduplication

Prevent multiple simultaneous requests for same data.

**New file:** `Core/Services/RequestDeduplicator.swift`

**Features:**

```swift
class RequestDeduplicator {
    static let shared = RequestDeduplicator()
    
    private var inflightRequests: [String: Task<Any, Error>] = [:]
    
    func deduplicate<T>(
        key: String,
        request: @escaping () async throws -> T
    ) async throws -> T {
        // If request in flight, wait for it
        if let existing = inflightRequests[key] as? Task<T, Error> {
            return try await existing.value
        }
        
        // Start new request
        let task = Task { try await request() }
        inflightRequests[key] = task
        
        defer { inflightRequests.removeValue(forKey: key) }
        
        return try await task.value
    }
}
```

### 8.2 Add Batch Loading for Related Data

When loading orders, batch fetch all related listings in one query instead of individual fetches.

### 8.3 Implement Smart Polling

For real-time features (new messages, order updates), implement smart polling:

- Poll every 5s when app active and view visible
- Stop polling when view dismissed
- Use exponential backoff on errors

---

## Phase 9: Monitoring & Metrics (Day 10)

### 9.1 Add Performance Monitoring

**New file:** `Core/Services/PerformanceMonitor.swift`

Track:

- Time to first render
- Time to data load
- Cache hit rates
- Network request counts
- Average load times per view

### 9.2 Add Debug Performance Overlay

Show in debug builds:

- Cache hit/miss indicators
- Load times
- Network activity

---

## Implementation Priority

### High Priority (Do First)

1. Loading skeletons (Phase 1.1) - Immediate perceived performance boost
2. Data caching layer (Phase 2) - Biggest impact on actual speed
3. Database indexes (Phase 3.1, 3.2) - Server-side speed improvements

### Medium Priority

4. Enhanced prefetching (Phase 4)
5. Background refresh (Phase 5)
6. Messaging optimization (Phase 6)

### Lower Priority (Polish)

7. Image quality optimization (Phase 7)
8. Advanced optimizations (Phase 8)
9. Monitoring (Phase 9)

---

## Success Metrics

### Target Performance

- Home feed: Instant on return (cached), <500ms fresh load
- Transactions: Instant on tab switch
- Messages: Instant chat open, <300ms message send
- Profile: Instant load with cached data
- Search: <200ms for cached results, <1s for fresh

### User Experience

- No spinners on cached views
- Smooth 60fps scrolling
- Instant tab switches
- Background refresh without blocking UI

---

## Files to Create

1. `Core/Services/DataCacheManager.swift` - Centralized data caching
2. `Core/Services/PrefetchService.swift` - Intelligent prefetching
3. `Core/Services/BackgroundRefreshManager.swift` - Background data refresh
4. `Core/Services/RequestDeduplicator.swift` - Prevent duplicate requests
5. `Core/Services/PerformanceMonitor.swift` - Performance tracking
6. `Core/Views/Skeletons/ListingCardSkeleton.swift` - Loading skeleton
7. `Core/Views/Skeletons/TransactionRowSkeleton.swift` - Transaction skeleton
8. `Core/Views/Skeletons/ProfileSkeleton.swift` - Profile skeleton
9. `optimize_transaction_queries.sql` - Database indexes for transactions
10. `optimize_home_feed_queries.sql` - Database indexes for home feed

## Files to Modify

1. `HomeTabView.swift` - Add caching, skeletons, prefetching
2. `MyTransactionsView.swift` - Add caching, skeletons
3. `ProfileTabView.swift` - Add caching, skeletons
4. `ChatView.swift` + `ChatViewModel.swift` - Message caching, pagination
5. `ImageCacheManager.swift` - Enhanced prefetching, quality levels
6. `OrderService.swift` - Add caching layer integration

---

## External Work (Database)

Run these SQL scripts in Supabase SQL Editor:

1. **optimize_transaction_queries.sql** - Add indexes for order queries
2. **optimize_home_feed_queries.sql** - Add indexes for listing queries
3. **create_listing_views.sql** - Create optimized database views

These can run in production without downtime (concurrent index creation).

### To-dos

- [ ] Create loading skeleton components for all major views (ListingCard, TransactionRow, Profile, Chat)
- [ ] Replace all ProgressView spinners with skeleton screens in HomeTabView, MyTransactionsView, ProfileTabView, ChatView
- [ ] Create DataCacheManager service with TTL-based caching for listings, orders, users, conversations
- [ ] Integrate DataCacheManager into HomeTabView - show cached listings instantly, refresh in background
- [ ] Integrate DataCacheManager into MyTransactionsView for purchases and sales caching
- [ ] Integrate DataCacheManager into ProfileTabView for user profile and listings
- [ ] Create and run SQL scripts for database indexes on orders and listings tables
- [ ] Enhance image prefetching to prefetch next page when user reaches 50% of current page
- [ ] Create PrefetchService for predictive data loading (conversations, listing details)
- [ ] Create BackgroundRefreshManager for silent data refresh on app foreground
- [ ] Implement message caching in ChatViewModel - show cached instantly, fetch only new messages
- [ ] Add pagination to ChatView for loading older messages on scroll-to-top
- [ ] Add quality levels to ImageCacheManager (thumbnail, medium, full) for different use cases
- [ ] Create RequestDeduplicator to prevent multiple simultaneous requests for same data
- [ ] Create PerformanceMonitor service to track load times, cache hit rates, and performance metrics