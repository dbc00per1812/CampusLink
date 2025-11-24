import Foundation

/// Represents a user's interest in a specific category and listing type
/// Used for personalizing the "For You" feed
struct UserInterest: Codable, Identifiable {
    let id: String
    let userId: String
    let category: String
    let listingType: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case category
        case listingType = "listing_type"
        case createdAt = "created_at"
    }
}

/// Interest category option for selection UI
struct InterestOption: Identifiable, Hashable {
    let id = UUID()
    let category: String
    let icon: String
    let type: ListingType
    
    var displayName: String {
        category
    }
}

/// All available interest options combining products and services
struct InterestOptions {
    // Product categories
    static let productCategories = [
        InterestOption(category: "Electronics", icon: "laptopcomputer", type: .product),
        InterestOption(category: "Books", icon: "book.fill", type: .product),
        InterestOption(category: "Furniture", icon: "bed.double.fill", type: .product),
        InterestOption(category: "Clothing", icon: "tshirt.fill", type: .product),
        InterestOption(category: "Sports", icon: "sportscourt.fill", type: .product),
        InterestOption(category: "Tickets", icon: "ticket.fill", type: .product)
    ]
    
    // Service categories
    static let serviceCategories = [
        InterestOption(category: "Tutoring", icon: "graduationcap.fill", type: .service),
        InterestOption(category: "Moving", icon: "shippingbox.fill", type: .service),
        InterestOption(category: "Cleaning", icon: "sparkles", type: .service)
    ]
    
    // All categories combined
    static let allCategories = productCategories + serviceCategories
}

