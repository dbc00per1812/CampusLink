import Foundation
import Combine

/// Production-grade data cache with TTL (Time To Live) for instant perceived performance
/// Caches listings, orders, users, conversations with configurable expiration times
class DataCacheManager: ObservableObject {
    static let shared = DataCacheManager()
    
    // MARK: - Cache Storage
    
    private var listingsCache: [String: CachedData<[ListingWithUser]>] = [:]
    private var ordersCache: [String: CachedData<[Order]>] = [:] // Separate cache for purchases/sales
    private var userCache: [String: CachedData<User>] = [:]
    private var userProfileCache: [String: CachedData<User>] = [:] // For profile views
    private var userListingsCache: [String: CachedData<[ListingWithUser]>] = [:] // For user's own listings
    private var conversationsCache: CachedData<[Conversation]>?
    
    // Thread-safe access
    private let queue = DispatchQueue(label: "com.campuslink.datacache", attributes: .concurrent)
    
    private init() {
        #if DEBUG
        print("📦 DataCacheManager: Initialized")
        #endif
    }
    
    // MARK: - Cached Data Wrapper
    
    struct CachedData<T> {
        let data: T
        let timestamp: Date
        let ttl: TimeInterval
        
        var isValid: Bool {
            Date().timeIntervalSince(timestamp) < ttl
        }
        
        var age: TimeInterval {
            Date().timeIntervalSince(timestamp)
        }
    }
    
    // MARK: - Listings Cache
    
    /// Cache listings for a specific filter/page combination
    /// - Parameters:
    ///   - listings: The listings to cache
    ///   - key: Unique key (e.g., "home_page_0", "offer_page_0", "campus_IU_page_0")
    ///   - ttl: Time to live in seconds (default: 5 minutes)
    func cacheListings(_ listings: [ListingWithUser], forKey key: String, ttl: TimeInterval = 300) {
        queue.async(flags: .barrier) {
            self.listingsCache[key] = CachedData(data: listings, timestamp: Date(), ttl: ttl)
            #if DEBUG
            print("📦 DataCache: Cached \(listings.count) listings for key '\(key)' (TTL: \(Int(ttl))s)")
            #endif
        }
    }
    
    /// Retrieve cached listings if still valid
    /// - Parameter key: The cache key
    /// - Returns: Cached listings if valid, nil otherwise
    func getListings(forKey key: String) -> [ListingWithUser]? {
        queue.sync {
            guard let cached = listingsCache[key], cached.isValid else {
                #if DEBUG
                if let cached = listingsCache[key] {
                    print("📦 DataCache: EXPIRED - Listings for key '\(key)' (age: \(Int(cached.age))s)")
                } else {
                    print("📦 DataCache: MISS - No listings for key '\(key)'")
                }
                #endif
                return nil
            }
            
            #if DEBUG
            print("📦 DataCache: HIT - \(cached.data.count) listings for key '\(key)' (age: \(Int(cached.age))s)")
            #endif
            return cached.data
        }
    }
    
    /// Invalidate all listing caches (call when creating/deleting listings)
    func invalidateListings() {
        queue.async(flags: .barrier) {
            self.listingsCache.removeAll()
            #if DEBUG
            print("📦 DataCache: INVALIDATED all listing caches")
            #endif
        }
    }
    
    /// Invalidate specific listing cache key
    func invalidateListings(forKey key: String) {
        queue.async(flags: .barrier) {
            self.listingsCache.removeValue(forKey: key)
            #if DEBUG
            print("📦 DataCache: INVALIDATED listings for key '\(key)'")
            #endif
        }
    }
    
    // MARK: - Orders Cache
    
    /// Cache orders (purchases or sales)
    /// - Parameters:
    ///   - orders: The orders to cache
    ///   - key: "purchases" or "sales"
    ///   - ttl: Time to live in seconds (default: 1 minute for fresh transaction data)
    func cacheOrders(_ orders: [Order], forKey key: String, ttl: TimeInterval = 60) {
        queue.async(flags: .barrier) {
            self.ordersCache[key] = CachedData(data: orders, timestamp: Date(), ttl: ttl)
            #if DEBUG
            print("📦 DataCache: Cached \(orders.count) orders for '\(key)' (TTL: \(Int(ttl))s)")
            #endif
        }
    }
    
    /// Retrieve cached orders if still valid
    func getOrders(forKey key: String) -> [Order]? {
        queue.sync {
            guard let cached = ordersCache[key], cached.isValid else {
                #if DEBUG
                if let cached = ordersCache[key] {
                    print("📦 DataCache: EXPIRED - Orders for '\(key)' (age: \(Int(cached.age))s)")
                } else {
                    print("📦 DataCache: MISS - No orders for '\(key)'")
                }
                #endif
                return nil
            }
            
            #if DEBUG
            print("📦 DataCache: HIT - \(cached.data.count) orders for '\(key)' (age: \(Int(cached.age))s)")
            #endif
            return cached.data
        }
    }
    
    /// Invalidate all order caches (call when order status changes)
    func invalidateOrders() {
        queue.async(flags: .barrier) {
            self.ordersCache.removeAll()
            #if DEBUG
            print("📦 DataCache: INVALIDATED all order caches")
            #endif
        }
    }
    
    // MARK: - User Cache
    
    /// Cache user profile
    /// - Parameters:
    ///   - user: The user to cache
    ///   - userId: User ID
    ///   - ttl: Time to live in seconds (default: 10 minutes)
    func cacheUser(_ user: User, userId: String, ttl: TimeInterval = 600) {
        queue.async(flags: .barrier) {
            self.userCache[userId] = CachedData(data: user, timestamp: Date(), ttl: ttl)
            #if DEBUG
            print("📦 DataCache: Cached user '\(user.name ?? "Unknown")' (TTL: \(Int(ttl))s)")
            #endif
        }
    }
    
    /// Retrieve cached user if still valid
    func getUser(userId: String) -> User? {
        queue.sync {
            guard let cached = userCache[userId], cached.isValid else {
                #if DEBUG
                if let cached = userCache[userId] {
                    print("📦 DataCache: EXPIRED - User \(userId) (age: \(Int(cached.age))s)")
                } else {
                    print("📦 DataCache: MISS - No user \(userId)")
                }
                #endif
                return nil
            }
            
            #if DEBUG
            print("📦 DataCache: HIT - User \(cached.data.name ?? "Unknown") (age: \(Int(cached.age))s)")
            #endif
            return cached.data
        }
    }
    
    /// Invalidate user cache (call when profile updated)
    func invalidateUser(userId: String) {
        queue.async(flags: .barrier) {
            self.userCache.removeValue(forKey: userId)
            self.userProfileCache.removeValue(forKey: userId)
            #if DEBUG
            print("📦 DataCache: INVALIDATED user \(userId)")
            #endif
        }
    }
    
    // MARK: - User Listings Cache (for profile view)
    
    /// Cache a user's own listings
    func cacheUserListings(_ listings: [ListingWithUser], userId: String, ttl: TimeInterval = 300) {
        queue.async(flags: .barrier) {
            self.userListingsCache[userId] = CachedData(data: listings, timestamp: Date(), ttl: ttl)
            #if DEBUG
            print("📦 DataCache: Cached \(listings.count) user listings for \(userId) (TTL: \(Int(ttl))s)")
            #endif
        }
    }
    
    /// Retrieve cached user listings
    func getUserListings(userId: String) -> [ListingWithUser]? {
        queue.sync {
            guard let cached = userListingsCache[userId], cached.isValid else {
                #if DEBUG
                if let cached = userListingsCache[userId] {
                    print("📦 DataCache: EXPIRED - User listings for \(userId) (age: \(Int(cached.age))s)")
                } else {
                    print("📦 DataCache: MISS - No user listings for \(userId)")
                }
                #endif
                return nil
            }
            
            #if DEBUG
            print("📦 DataCache: HIT - \(cached.data.count) user listings (age: \(Int(cached.age))s)")
            #endif
            return cached.data
        }
    }
    
    /// Invalidate user's own listings (call when they create/update/delete a listing)
    func invalidateUserListings(userId: String) {
        queue.async(flags: .barrier) {
            self.userListingsCache.removeValue(forKey: userId)
            #if DEBUG
            print("📦 DataCache: INVALIDATED user listings for \(userId)")
            #endif
        }
    }
    
    // MARK: - Conversations Cache
    
    /// Cache conversations list
    func cacheConversations(_ conversations: [Conversation], ttl: TimeInterval = 300) {
        queue.async(flags: .barrier) {
            self.conversationsCache = CachedData(data: conversations, timestamp: Date(), ttl: ttl)
            #if DEBUG
            print("📦 DataCache: Cached \(conversations.count) conversations (TTL: \(Int(ttl))s)")
            #endif
        }
    }
    
    /// Retrieve cached conversations
    func getConversations() -> [Conversation]? {
        queue.sync {
            guard let cached = conversationsCache, cached.isValid else {
                #if DEBUG
                if let cached = conversationsCache {
                    print("📦 DataCache: EXPIRED - Conversations (age: \(Int(cached.age))s)")
                } else {
                    print("📦 DataCache: MISS - No conversations")
                }
                #endif
                return nil
            }
            
            #if DEBUG
            print("📦 DataCache: HIT - \(cached.data.count) conversations (age: \(Int(cached.age))s)")
            #endif
            return cached.data
        }
    }
    
    /// Invalidate conversations cache
    func invalidateConversations() {
        queue.async(flags: .barrier) {
            self.conversationsCache = nil
            #if DEBUG
            print("📦 DataCache: INVALIDATED conversations")
            #endif
        }
    }
    
    // MARK: - Cache Management
    
    /// Clear all caches (useful for logout or force refresh)
    func clearAllCaches() {
        queue.async(flags: .barrier) {
            self.listingsCache.removeAll()
            self.ordersCache.removeAll()
            self.userCache.removeAll()
            self.userProfileCache.removeAll()
            self.userListingsCache.removeAll()
            self.conversationsCache = nil
            
            #if DEBUG
            print("📦 DataCache: CLEARED all caches")
            #endif
        }
    }
    
    /// Get cache statistics for debugging
    func getCacheStats() -> CacheStats {
        queue.sync {
            return CacheStats(
                listingsCacheCount: listingsCache.count,
                ordersCacheCount: ordersCache.count,
                usersCacheCount: userCache.count,
                userListingsCacheCount: userListingsCache.count,
                hasConversations: conversationsCache != nil
            )
        }
    }
    
    struct CacheStats {
        let listingsCacheCount: Int
        let ordersCacheCount: Int
        let usersCacheCount: Int
        let userListingsCacheCount: Int
        let hasConversations: Bool
        
        var description: String {
            """
            📦 Cache Stats:
            - Listings: \(listingsCacheCount) keys
            - Orders: \(ordersCacheCount) keys
            - Users: \(usersCacheCount) cached
            - User Listings: \(userListingsCacheCount) cached
            - Conversations: \(hasConversations ? "cached" : "not cached")
            """
        }
    }
}

// MARK: - Cache Key Helpers

extension DataCacheManager {
    /// Generate cache key for home listings
    static func homeListingsKey(page: Int, filter: String = "all", campus: String? = nil) -> String {
        if let campus = campus {
            return "home_\(filter)_\(campus)_page_\(page)"
        }
        return "home_\(filter)_page_\(page)"
    }
    
    /// Generate cache key for category listings
    static func categoryListingsKey(category: String, type: String, page: Int) -> String {
        return "category_\(category)_\(type)_page_\(page)"
    }
    
    /// Generate cache key for search results
    static func searchListingsKey(query: String, page: Int) -> String {
        return "search_\(query.lowercased())_page_\(page)"
    }
}

