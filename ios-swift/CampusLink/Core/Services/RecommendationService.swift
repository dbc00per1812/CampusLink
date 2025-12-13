import Foundation
import Supabase

/// Service for intelligent listing recommendations and diversification
final class RecommendationService {
    static let shared = RecommendationService()
    
    private init() {}
    
    // MARK: - Diversification
    
    /// Diversify listings with randomization and category constraints
    /// Simple version: Shuffle everything, then ensure no duplicate categories in top picks
    /// TODO: Phase 4 - Add algorithmic scoring (engagement, freshness, user preferences, etc.)
    func diversifyListings(_ listings: [ListingWithUser], count: Int = 4) -> [ListingWithUser] {
        guard !listings.isEmpty else { return [] }
        
        // If we have fewer items than requested, return all shuffled
        if listings.count <= count {
            return listings.shuffled()
        }
        
        // Filter to only valid listings
        let validListings = listings.filter { isListingValid($0) }
        guard !validListings.isEmpty else { return [] }
        
        // TOTAL SHUFFLE - fresh results every time!
        let shuffledListings = validListings.shuffled()
        
        // Now select diverse items (no duplicate categories in top picks)
        var result: [ListingWithUser] = []
        var usedCategories: Set<String> = []
        
        // First pass: Pick listings from unique categories
        for listing in shuffledListings {
            guard result.count < count else { break }
            
            // Skip if we already have this category
            if usedCategories.contains(listing.category) {
                continue
            }
            
            result.append(listing)
            usedCategories.insert(listing.category)
        }
        
        // Second pass: Fill remaining slots if we don't have enough unique categories
        // (e.g., if there are only 2 categories total but we want 4 items)
        if result.count < count {
            for listing in shuffledListings {
                guard result.count < count else { break }
                
                // Skip if already selected
                if result.contains(where: { $0.id == listing.id }) {
                    continue
                }
                
                result.append(listing)
            }
        }
        
        #if DEBUG
        print("📊 Diversification Results (Shuffled):")
        print("   Total selected: \(result.count)")
        print("   Products: \(result.filter { $0.listingType == .product }.count)")
        print("   Services: \(result.filter { $0.listingType == .service }.count)")
        print("   Offers: \(result.filter { $0.intent == .offer }.count)")
        print("   Wanted: \(result.filter { $0.intent == .seek }.count)")
        print("   Unique categories: \(Set(result.map { $0.category }).sorted().joined(separator: ", "))")
        for (index, listing) in result.enumerated() {
            let type = listing.listingType == .product ? "Product" : "Service"
            let intent = listing.intent == .offer ? "Offer" : "Wanted"
            print("   [\(index + 1)] \(type) - \(intent) - \(listing.category) - \(listing.title)")
        }
        #endif
        
        return result
    }
    
    // MARK: - Future Algorithmic Diversification (Phase 4)
    
    /// Calculate a diversity score for a listing based on multiple factors
    /// TODO: Implement in Phase 4 with user preferences, engagement metrics, etc.
    /// Scoring factors to consider:
    /// - Freshness (newer = higher score, but not purely chronological)
    /// - Category rarity (less common categories get boost)
    /// - Price variety (mix of price ranges)
    /// - User engagement (views, likes, messages)
    /// - Listing type balance (products vs services)
    /// - Intent balance (offers vs wanted)
    /// - User's browsing history (personalization)
    private func calculateDiversityScore(_ listing: ListingWithUser, 
                                          usedCategories: Set<String>,
                                          usedTypes: Set<ListingType>,
                                          userPreferences: [String: Any]? = nil) -> Double {
        // Placeholder for future implementation
        // Will return 0-100 score, higher = more valuable for diversity
        var score: Double = 50.0  // Base score
        
        // Boost for new categories
        if !usedCategories.contains(listing.category) {
            score += 20.0
        }
        
        // Boost for balancing product/service mix
        if !usedTypes.contains(listing.listingType) {
            score += 15.0
        }
        
        // TODO: Add more factors:
        // - Freshness factor (recent but not purely chronological)
        // - Engagement factor (popular items)
        // - Price diversity factor
        // - User preference factor
        
        return score
    }
    
    /// Check if a listing is valid for recommendations
    private func isListingValid(_ listing: ListingWithUser) -> Bool {
        // Must not be sold
        guard !listing.isSold else { return false }
        
        // Must not be archived
        if let archived = listing.archived, archived {
            return false
        }
        
        // Must have available quantity (if tracked)
        if let quantity = listing.quantityAvailable, quantity <= 0 {
            return false
        }
        
        // Must not be expired (for seek listings)
        if let expiresAt = listing.expiresAt, expiresAt < Date() {
            return false
        }
        
        return true
    }
    
    // MARK: - Category Analysis
    
    /// Get category distribution for analytics
    func getCategoryDistribution(_ listings: [ListingWithUser]) -> [String: Int] {
        var distribution: [String: Int] = [:]
        
        for listing in listings {
            distribution[listing.category, default: 0] += 1
        }
        
        return distribution
    }
    
    /// Get diversity score (0-1) for a set of listings
    /// Higher score = more diverse categories
    func getDiversityScore(_ listings: [ListingWithUser]) -> Double {
        guard !listings.isEmpty else { return 0 }
        
        let uniqueCategories = Set(listings.map { $0.category }).count
        let totalListings = listings.count
        
        return Double(uniqueCategories) / Double(totalListings)
    }
    
    // MARK: - Similar Items (Phase 3)
    
    /// Get listings similar to a given listing using vector embeddings
    /// Returns listings ordered by similarity score (most similar first)
    /// NOTE: Requires database setup - returns empty until create_similar_items_safe.sql is run
    func getSimilarListings(to listingId: UUID, limit: Int = 10) async throws -> [ListingWithUser] {
        // TODO: Enable after running create_similar_items_safe.sql in Supabase
        // For now, return empty to avoid compilation errors
        #if DEBUG
        print("📊 Similar listings: Database functions not yet deployed")
        #endif
        return []
    }
    
    /// Get personalized recommendations based on user's viewing history
    /// This is a placeholder for future enhancement
    func getPersonalizedRecommendations(for userId: String, limit: Int = 20) async throws -> [ListingWithUser] {
        // TODO: Phase 4 - Implement personalized recommendations
        // For now, return empty array
        // Future: Track user views, average their embeddings, find similar items
        #if DEBUG
        print("📊 Personalized recommendations not yet implemented")
        #endif
        return []
    }
}

