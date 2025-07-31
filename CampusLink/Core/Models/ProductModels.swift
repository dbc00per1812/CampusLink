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
    let user: UserProfile
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo, user
        case isSold = "is_sold"
        case listingType = "listing_type"
        case serviceDuration = "service_duration"
        case serviceLocation = "service_location"
        case serviceAvailability = "service_availability"
        case createdAt = "created_at"
    }
} 