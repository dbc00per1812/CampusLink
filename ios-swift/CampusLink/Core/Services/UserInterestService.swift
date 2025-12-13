import Foundation
import Supabase

/// Helper struct for creating hashable category-type pairs
private struct CategoryTypePair: Hashable {
    let category: String
    let listingType: String
}

/// Service for managing user interests and personalized recommendations
class UserInterestService {
    static let shared = UserInterestService()
    private init() {}
    
    /// Cache for user interests to avoid repeated database queries
    private var interestsCache: [String: [UserInterest]] = [:]
    private let cacheExpiration: TimeInterval = 300 // 5 minutes
    private var cacheTimestamp: [String: Date] = [:]
    
    /// Fetch user's selected interests from database
    func fetchUserInterests(userId: String) async throws -> [UserInterest] {
        // Check cache first
        if let cached = interestsCache[userId],
           let timestamp = cacheTimestamp[userId],
           Date().timeIntervalSince(timestamp) < cacheExpiration {
            print("✅ Using cached interests for user \(userId)")
            return cached
        }
        
        print("🔍 Fetching interests from database for user \(userId)")
        
        let interests: [UserInterest] = try await supabase
            .from("user_interests")
            .select()
            .eq("user_id", value: userId)
            .execute()
            .value
        
        // Update cache
        interestsCache[userId] = interests
        cacheTimestamp[userId] = Date()
        
        print("✅ Fetched \(interests.count) interests for user")
        return interests
    }
    
    /// Clear cache for a specific user (call after updating interests)
    func clearCache(userId: String) {
        interestsCache.removeValue(forKey: userId)
        cacheTimestamp.removeValue(forKey: userId)
    }
    
    /// Prioritize listings based on user interests
    /// Returns listings sorted with interested categories first, then others
    func prioritizeListings(_ listings: [ListingWithUser], userId: String) async -> [ListingWithUser] {
        do {
            let interests = try await fetchUserInterests(userId: userId)
            
            // If no interests, return original order
            guard !interests.isEmpty else {
                print("ℹ️ No interests found, returning original listing order")
                return listings
            }
            
            // Create a set of category-type pairs for fast lookup
            let interestSet = Set(interests.map { CategoryTypePair(category: $0.category, listingType: $0.listingType) })
            
            print("🎯 Prioritizing listings based on \(interests.count) interests")
            print("📋 User interests:")
            for interest in interests {
                print("   - \(interest.category) (\(interest.listingType))")
            }
            
            // Partition listings into interested and not interested
            var interestedListings: [ListingWithUser] = []
            var otherListings: [ListingWithUser] = []
            
            for listing in listings {
                let listingKey = CategoryTypePair(category: listing.category ?? "", listingType: listing.listingType.rawValue)
                let matched = interestSet.contains(listingKey)
                
                if matched {
                    print("   ✅ MATCH: '\(listing.title)' - \(listing.category ?? "no category") (\(listing.listingType.rawValue))")
                    interestedListings.append(listing)
                } else {
                    print("   ⏭️  Skip: '\(listing.title)' - \(listing.category ?? "no category") (\(listing.listingType.rawValue))")
                    otherListings.append(listing)
                }
            }
            
            print("✅ Split listings: \(interestedListings.count) interested, \(otherListings.count) other")
            print("📊 First 3 listings in final order:")
            let finalOrder = interestedListings + otherListings
            for (index, listing) in finalOrder.prefix(3).enumerated() {
                print("   \(index + 1). '\(listing.title)' - \(listing.category ?? "no category") (\(listing.listingType.rawValue))")
            }
            
            // Return interested listings first, then others
            return interestedListings + otherListings
            
        } catch {
            print("❌ Error fetching interests, returning original listing order: \(error)")
            return listings
        }
    }
    
    /// Check if a listing matches user's interests
    func matchesInterests(listing: ListingWithUser, userId: String) async -> Bool {
        do {
            let interests = try await fetchUserInterests(userId: userId)
            guard !interests.isEmpty else { return false }
            
            let interestSet = Set(interests.map { CategoryTypePair(category: $0.category, listingType: $0.listingType) })
            let listingKey = CategoryTypePair(category: listing.category ?? "", listingType: listing.listingType.rawValue)
            
            return interestSet.contains(listingKey)
        } catch {
            print("❌ Error checking interest match: \(error)")
            return false
        }
    }
    
    /// Get interest score for a listing (1.0 if matches interest, 0.0 otherwise)
    /// Can be used for more complex scoring algorithms in the future
    func getInterestScore(listing: ListingWithUser, userId: String) async -> Double {
        let matches = await matchesInterests(listing: listing, userId: userId)
        return matches ? 1.0 : 0.0
    }
}

