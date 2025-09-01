import Foundation

enum ListingType: String, Codable, CaseIterable {
    case product = "product"
    case service = "service"
    
    var displayName: String {
        switch self {
        case .product:
            return "Product"
        case .service:
            return "Service"
        }
    }
}

enum ServiceLocation: String, Codable, CaseIterable {
    case onCampus = "on_campus"
    case offCampus = "off_campus"
    case remote = "remote"
    
    var displayName: String {
        switch self {
        case .onCampus:
            return "On Campus"
        case .offCampus:
            return "Off Campus"
        case .remote:
            return "Remote"
        }
    }
}

struct Listing: Codable, Identifiable {
    let id: UUID
    let userId: String
    let title: String
    let description: String
    let price: Double
    let category: String
    let photo: String?
    let isSold: Bool
    let listingType: ListingType
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo
        case userId = "user_id"
        case isSold = "is_sold"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case createdAt = "created_at"
    }
    
    // MARK: - Sample Data for Previews
    static let sampleListing = Listing(
        id: UUID(),
        userId: "sample-user-id",
        title: "Sample Product",
        description: "This is a sample product description for testing and preview purposes.",
        price: 25.00,
        category: "Electronics",
        photo: nil,
        isSold: false,
        listingType: .product,
        serviceDuration: nil,
        serviceLocation: nil,
        serviceAvailability: nil,
        createdAt: Date()
    )
}

struct ListingCreate: Codable {
    let userId: String
    let title: String
    let description: String
    let price: Double
    let category: String
    let photo: String?
    let listingType: ListingType
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?
    
    enum CodingKeys: String, CodingKey {
        case title, description, price, category, photo
        case userId = "user_id"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
    }
}

struct ListingWithUser: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let price: Double
    let category: String
    let photo: String?
    let isSold: Bool
    let listingType: ListingType
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?
    let createdAt: Date
    let user: User
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo, user
        case isSold = "is_sold"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case createdAt = "created_at"
    }
    
    // MARK: - Sample Data for Previews
    static let sampleListing = ListingWithUser(
        id: UUID(),
        title: "Sample Product",
        description: "This is a sample product description for testing and preview purposes.",
        price: 25.00,
        category: "Electronics",
        photo: nil,
        isSold: false,
        listingType: .product,
        serviceDuration: nil,
        serviceLocation: nil,
        serviceAvailability: nil,
        createdAt: Date(),
        user: User.sampleUser
    )
}

// MARK: - User Model (matches database schema)
typealias UserProfile = User

struct User: Codable {
    let id: String
    let name: String?
    let bio: String?
    let profilePic: String?
    let email: String?
    let createdAt: Date
    let campusEmailVerified: Bool?
    let trustScore: Int?
    let stripeConnectId: String?
    let stripePayoutsEnabled: Bool?
    let stripeDetailsSubmitted: Bool?
    
    enum CodingKeys: String, CodingKey {
        case id, name, bio, email
        case profilePic = "profile_pic"
        case createdAt = "created_at"
        case campusEmailVerified = "campus_email_verified"
        case trustScore = "trust_score"
        case stripeConnectId = "stripe_connect_id"
        case stripePayoutsEnabled = "stripe_payouts_enabled"
        case stripeDetailsSubmitted = "stripe_details_submitted"
    }
    
    // MARK: - Sample Data for Previews
    static let sampleUser = User(
        id: "sample-user-id",
        name: "Sample User",
        bio: "This is a sample user for testing and preview purposes.",
        profilePic: nil,
        email: "sample@example.com",
        createdAt: Date(),
        campusEmailVerified: true,
        trustScore: 85,
        stripeConnectId: "acct_sample123",
        stripePayoutsEnabled: true,
        stripeDetailsSubmitted: true
    )
    
    // Alias for UserProfile compatibility
    static let sampleProfile = sampleUser
} 