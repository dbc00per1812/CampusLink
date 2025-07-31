import Foundation

struct Listing: Codable, Identifiable {
    let id: UUID
    let userId: String
    let title: String
    let description: String
    let price: Double
    let category: String
    let photo: String?
    let isSold: Bool
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo
        case userId = "user_id"
        case isSold = "is_sold"
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
    
    enum CodingKeys: String, CodingKey {
        case title, description, price, category, photo
        case userId = "user_id"
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
    let createdAt: Date
    let user: UserProfile
    
    enum CodingKeys: String, CodingKey {
        case id, title, description, price, category, photo, user
        case isSold = "is_sold"
        case createdAt = "created_at"
    }
} 