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
// This matches the exact output of the search_listings PostgreSQL function
struct SearchListing: Codable, Identifiable {
    let id: UUID
    let user_id: UUID
    let title: String
    let description: String?
    let price: Double?
    let category: String?
    let condition: String?
    let images: [String]? // JSON array from database
    let intent: String // Raw string from database
    let status: String
    let archived: Bool
    let service_location: String?
    let created_at: Date
    let relevance_score: Float
    
    // User information from joined query
    let user_name: String?
    let user_email: String?
    let user_avatar_url: String?
    let user_trust_score: Int?
    
    // Custom CodingKeys to handle different JSON field names
    enum CodingKeys: String, CodingKey {
        case id, user_id, title, description, price, category, condition, images
        case intent, status, archived, service_location, created_at, relevance_score
        case user_name, user_email, user_avatar_url, user_trust_score
    }
    
    // Convert to ListingWithUser for compatibility with existing views
    func toListingWithUser() -> ListingWithUser {
        // Create User object from search result data
        let user = User(
            id: user_id.uuidString,
            name: user_name,
            bio: nil,
            profilePic: user_avatar_url,
            email: user_email,
            createdAt: created_at,
            campusEmailVerified: true,
            trustScore: user_trust_score,
            stripeConnectId: nil,
            stripePayoutsEnabled: false,
            stripeDetailsSubmitted: false
        )
        
        // Convert intent string to enum
        let listingIntent = ListingIntent(rawValue: intent) ?? .offer
        
        // Get first image URL if available
        let photo = images?.first
        
        return ListingWithUser(
            id: id,
            title: title,
            description: description ?? "",
            price: price ?? 0,
            category: category ?? "",
            photo: photo,
            isSold: false, // Default for active listings
            listingType: .product, // Default, could be enhanced later
            serviceDuration: nil,
            serviceLocation: ServiceLocation(rawValue: service_location ?? ""),
            serviceAvailability: nil,
            serviceType: nil,
            slotsAvailable: nil,
            maxBookingsPerSlot: nil,
            archived: archived,
            createdAt: created_at,
            user: user,
            intent: listingIntent,
            budgetMin: nil, // Not in current search results
            budgetMax: nil, // Not in current search results
            expiresAt: nil // Not in current search results
        )
    }
}
