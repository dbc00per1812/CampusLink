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

enum DeliveryMethod: String, Codable, CaseIterable {
    case pickup = "pickup"
    case delivery = "delivery"
    
    var displayName: String {
        switch self {
        case .pickup:
            return "Pickup"
        case .delivery:
            return "Delivery"
        }
    }
    
    var description: String {
        switch self {
        case .pickup:
            return "Buyer will pick up"
        case .delivery:
            return "Seller will drop off"
        }
    }
}

struct Listing: Codable, Identifiable {
    let id: UUID
    let userId: String
    let title: String
    let description: String
    let price: Double?
    let category: String
    let photo: String? // Keep for backward compatibility
    let photos: [String] // New array for multiple photos
    let isSold: Bool
    let listingType: ListingType
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?
    let archived: Bool?
    let createdAt: Date
    // Seek mode fields (Phase 2)
    let intent: ListingIntent
    let budgetMin: Double?
    let budgetMax: Double?
    let expiresAt: Date?
    let deliveryMethod: DeliveryMethod?
    // Quantity tracking
    let quantityAvailable: Int?
    let quantitySold: Int?
    
    // Computed properties for quantity
    var hasMultipleUnits: Bool { (quantityAvailable ?? 1) > 1 }
    var isOutOfStock: Bool { (quantityAvailable ?? 1) <= 0 }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo, photos
        case userId = "user_id"
        case isSold = "is_sold"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case archived = "archived"
        case createdAt = "created_at"
        // Seek mode fields
        case intent
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case expiresAt = "expires_at"
        case deliveryMethod = "delivery_method"
        // Quantity tracking
        case quantityAvailable = "quantity_available"
        case quantitySold = "quantity_sold"
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
        photos: [],
        isSold: false,
        listingType: .product,
        serviceDuration: nil,
        serviceLocation: nil,
        serviceAvailability: nil,
        archived: false,
        createdAt: Date(),
        intent: .offer,
        budgetMin: nil,
        budgetMax: nil,
        expiresAt: nil,
        deliveryMethod: .pickup,
        quantityAvailable: 1,
        quantitySold: 0
    )
}

struct ListingCreate: Codable {
    let userId: String
    let title: String
    let description: String
    let price: Double? // Optional for seek posts
    let category: String
    let photo: String? // Keep for backward compatibility
    let photos: [String] // New array for multiple photos
    let listingType: ListingType
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?
    let archived: Bool?
    // Seek mode fields (Phase 2)
    let intent: ListingIntent
    let budgetMin: Double?
    let budgetMax: Double?
    let expiresAt: Date?
    let deliveryMethod: DeliveryMethod?
    // Quantity tracking
    let quantityAvailable: Int?
    
    enum CodingKeys: String, CodingKey {
        case title, description, price, category, photo, photos
        case userId = "user_id"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case archived = "archived"
        // Seek mode fields
        case intent
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case expiresAt = "expires_at"
        case deliveryMethod = "delivery_method"
        // Quantity tracking
        case quantityAvailable = "quantity_available"
    }
}

struct ListingWithUser: Codable, Identifiable {
    let id: UUID
    let title: String
    let description: String
    let price: Double?
    let category: String
    let photo: String? // Keep for backward compatibility
    let photos: [String] // New array for multiple photos
    let isSold: Bool
    let listingType: ListingType
    let serviceDuration: String?
    let serviceLocation: ServiceLocation?
    let serviceAvailability: String?
    let archived: Bool?
    let createdAt: Date
    let user: User
    // Seek mode fields (Phase 2)
    let intent: ListingIntent
    let budgetMin: Double?
    let budgetMax: Double?
    let expiresAt: Date?
    let deliveryMethod: DeliveryMethod?
    // Quantity tracking
    let quantityAvailable: Int?
    let quantitySold: Int?
    
    // Computed properties for quantity
    var hasMultipleUnits: Bool { (quantityAvailable ?? 1) > 1 }
    var isOutOfStock: Bool { (quantityAvailable ?? 1) <= 0 }
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo, photos, user
        case isSold = "is_sold"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case archived = "archived"
        case createdAt = "created_at"
        // Seek mode fields
        case intent
        case budgetMin = "budget_min"
        case budgetMax = "budget_max"
        case expiresAt = "expires_at"
        case deliveryMethod = "delivery_method"
        // Quantity tracking
        case quantityAvailable = "quantity_available"
        case quantitySold = "quantity_sold"
    }
    
    // MARK: - Sample Data for Previews
    static let sampleListing = ListingWithUser(
        id: UUID(),
        title: "Sample Product",
        description: "This is a sample product description for testing and preview purposes.",
        price: 25.00,
        category: "Electronics",
        photo: nil,
        photos: [],
        isSold: false,
        listingType: .product,
        serviceDuration: nil,
        serviceLocation: nil,
        serviceAvailability: nil,
        archived: false,
        createdAt: Date(),
        user: User.sampleUser,
        intent: .offer,
        budgetMin: nil,
        budgetMax: nil,
        expiresAt: nil,
        deliveryMethod: .pickup,
        quantityAvailable: 1,
        quantitySold: 0
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
    let campus: String?
    let createdAt: Date
    let campusEmailVerified: Bool?
    let trustScore: Int?
    let stripeConnectId: String?
    let stripePayoutsEnabled: Bool?
    let stripeDetailsSubmitted: Bool?
    // Student verification fields
    let verificationStatus: String?
    let studentIdImageUrl: String?
    let verificationSubmittedAt: Date?
    let verificationReviewedAt: Date?
    let verificationNotes: String?
    
    var isVerifiedStudent: Bool {
        return verificationStatus == "verified"
    }
    
    enum CodingKeys: String, CodingKey {
        case id, name, bio, email, campus
        case profilePic = "profile_pic"
        case createdAt = "created_at"
        case campusEmailVerified = "campus_email_verified"
        case trustScore = "trust_score"
        case stripeConnectId = "stripe_connect_id"
        case stripePayoutsEnabled = "stripe_payouts_enabled"
        case stripeDetailsSubmitted = "stripe_details_submitted"
        case verificationStatus = "verification_status"
        case studentIdImageUrl = "student_id_image_url"
        case verificationSubmittedAt = "verification_submitted_at"
        case verificationReviewedAt = "verification_reviewed_at"
        case verificationNotes = "verification_notes"
    }
    
    // MARK: - Sample Data for Previews
    static let sampleUser = User(
        id: "sample-user-id",
        name: "Sample User",
        bio: "This is a sample user for testing and preview purposes.",
        profilePic: nil,
        email: "sample@example.com",
        campus: "Indiana University Bloomington",
        createdAt: Date(),
        campusEmailVerified: true,
        trustScore: 85,
        stripeConnectId: "acct_sample123",
        stripePayoutsEnabled: true,
        stripeDetailsSubmitted: true,
        verificationStatus: "verified",
        studentIdImageUrl: nil,
        verificationSubmittedAt: nil,
        verificationReviewedAt: nil,
        verificationNotes: nil
    )
    
    // Alias for UserProfile compatibility
    static let sampleProfile = sampleUser
}

// MARK: - Offer Model (Phase 0)
struct Offer: Codable, Identifiable {
    let id: UUID
    let seekListingId: UUID
    let offerListingId: UUID?
    let seekerId: String
    let sellerId: String
    let message: String?
    let status: String
    let priceCents: Int?  // Custom offer amount in cents
    let orderId: UUID?  // Associated order after payment
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
        case priceCents = "price_cents"
        case orderId = "order_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    // Computed properties
    var price: Double? {
        guard let cents = priceCents else { return nil }
        return Double(cents) / 100.0
    }
    
    var formattedPrice: String? {
        guard let p = price else { return nil }
        return String(format: "$%.2f", p)
    }
} 