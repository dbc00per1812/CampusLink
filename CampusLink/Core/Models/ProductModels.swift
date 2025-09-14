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

enum ListingIntent: String, Codable, CaseIterable {
    case offer = "offer"
    case seek = "seek"
    
    var displayName: String {
        switch self {
        case .offer:
            return "Sell"
        case .seek:
            return "Buy"
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

enum ServiceType: String, Codable, CaseIterable {
    case calendar = "calendar"
    case slots = "slots"
    
    var displayName: String {
        switch self {
        case .calendar:
            return "Calendar-based"
        case .slots:
            return "Time Slots"
        }
    }
    
    var description: String {
        switch self {
        case .calendar:
            return "Flexible scheduling based on your availability"
        case .slots:
            return "Pre-defined time slots with limited capacity"
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
    let serviceType: ServiceType?
    let slotsAvailable: Int?
    let maxBookingsPerSlot: Int?
    let archived: Bool?
    let createdAt: Date
    // Seek mode fields (Phase 2)
    let intent: ListingIntent
    let budgetMin: Double?
    let budgetMax: Double?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo
        case userId = "user_id"
        case isSold = "is_sold"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case serviceType = "service_type"
        case slotsAvailable = "slots_available"
        case maxBookingsPerSlot = "max_bookings_per_slot"
        case archived = "archived"
        case createdAt = "created_at"
        // Seek mode fields
        case intent
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case expiresAt = "expires_at"
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
        serviceType: nil,
        slotsAvailable: nil,
        maxBookingsPerSlot: nil,
        archived: false,
        createdAt: Date(),
        intent: .offer,
        budgetMin: nil,
        budgetMax: nil,
        expiresAt: nil
    )
}

struct ListingCreate: Codable {
    let userId: String
    let title: String
    let description: String
    let price: Double? // Optional for seek posts
    let category: String
    let photo: String?
    let listingType: ListingType
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?
    let serviceType: ServiceType?
    let slotsAvailable: Int?
    let maxBookingsPerSlot: Int?
    let archived: Bool?
    // Seek mode fields (Phase 2)
    let intent: ListingIntent
    let budgetMin: Double?
    let budgetMax: Double?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case title, description, price, category, photo
        case userId = "user_id"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case serviceType = "service_type"
        case slotsAvailable = "slots_available"
        case maxBookingsPerSlot = "max_bookings_per_slot"
        case archived = "archived"
        // Seek mode fields
        case intent
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case expiresAt = "expires_at"
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
    let serviceType: ServiceType?
    let slotsAvailable: Int?
    let maxBookingsPerSlot: Int?
    let archived: Bool?
    let createdAt: Date
    let user: User
    // Seek mode fields (Phase 2)
    let intent: ListingIntent
    let budgetMin: Double?
    let budgetMax: Double?
    let expiresAt: Date?
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo, user
        case isSold = "is_sold"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case serviceType = "service_type"
        case slotsAvailable = "slots_available"
        case maxBookingsPerSlot = "max_bookings_per_slot"
        case archived = "archived"
        case createdAt = "created_at"
        // Seek mode fields
        case intent
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case expiresAt = "expires_at"
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
        serviceType: nil,
        slotsAvailable: nil,
        maxBookingsPerSlot: nil,
        archived: false,
        createdAt: Date(),
        user: User.sampleUser,
        intent: .offer,
        budgetMin: nil,
        budgetMax: nil,
        expiresAt: nil
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

// MARK: - Offer Model (Phase 0)
struct Offer: Codable, Identifiable {
    let id: UUID
    let seekListingId: UUID
    let offerListingId: UUID
    let seekerId: String
    let sellerId: String
    let message: String?
    let status: String
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case seekListingId = "seek_listing_id"
        case offerListingId = "offer_listing_id"
        case seekerId = "seeker_id"
        case sellerId = "seller_id"
        case message
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
} 