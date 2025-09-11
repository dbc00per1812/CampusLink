import Foundation

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
    let id: UUID
    let text: String
    let category: String?
    let count: Int
    let type: SuggestionType
    
    init(text: String, category: String?, count: Int, type: SuggestionType) {
        self.id = UUID()
        self.text = text
        self.category = category
        self.count = count
        self.type = type
    }
    
    enum SuggestionType: String, Codable {
        case recent, suggestion, trending, category
    }
}

struct SearchResult: Codable {
    let listings: [SearchListing]
    let totalCount: Int
    let searchRank: [UUID: Float] // listing_id -> relevance score
    let suggestions: [SearchSuggestion]
    let hasMore: Bool
}

struct RecentSearch: Codable, Identifiable {
    let id: UUID
    let query: SearchQuery
    let timestamp: Date
    let resultCount: Int
    
    init(query: SearchQuery, timestamp: Date = Date(), resultCount: Int) {
        self.id = UUID()
        self.query = query
        self.timestamp = timestamp
        self.resultCount = resultCount
    }
}

// MARK: - Database Response Models

struct SearchListingRow: Codable {
    let listing_data: SearchListing?
    let search_rank: Float
}

struct SearchSuggestionRow: Codable {
    let suggestion: String
    let category: String?
    let count: Int64
}

// MARK: - Search Listing Model for Search Results
// This is a flattened version with user data from database joins
struct SearchListing: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let title: String
    let description: String?
    let price: Double?
    let category: String?
    let photo: String?
    let is_sold: Bool
    let created_at: Date
    let listing_type: ListingType
    let service_duration: String?
    let service_location: ServiceLocation?
    let service_availability: String?
    let status: String
    let archived: Bool
    let intent: ListingIntent
    let budget_min: Double?
    let budget_max: Double?
    let expires_at: Date?
    
    // User information from joined query
    let user_name: String?
    let user_email: String?
    let user_trust_score: Int?
    let user_profile_pic: String?
    
    // Convert to ListingWithUser for compatibility with existing views
    func toListingWithUser() -> ListingWithUser {
        // Order and labels must match User's memberwise initializer:
        // id, name, bio, profilePic, email, createdAt, campusEmailVerified, trustScore,
        // stripeConnectId, stripePayoutsEnabled, stripeDetailsSubmitted
        let user = User(
            id: user_id.uuidString,
            name: user_name,
            bio: nil,
            profilePic: user_profile_pic,
            email: user_email,
            createdAt: created_at,
            campusEmailVerified: true,
            trustScore: user_trust_score,
            stripeConnectId: nil,
            stripePayoutsEnabled: false,
            stripeDetailsSubmitted: false
        )
        
        return ListingWithUser(
            id: id,
            title: title,
            description: description ?? "",
            price: price ?? 0,
            category: category ?? "",
            photo: photo,
            isSold: is_sold,
            listingType: listing_type,
            serviceDuration: service_duration,
            serviceLocation: service_location,
            serviceAvailability: service_availability,
            serviceType: nil, // Not available in search results
            slotsAvailable: nil, // Not available in search results
            maxBookingsPerSlot: nil, // Not available in search results
            archived: archived,
            createdAt: created_at,
            user: user,
            intent: intent,
            budgetMin: budget_min,
            budgetMax: budget_max,
            expiresAt: expires_at
        )
    }
}
