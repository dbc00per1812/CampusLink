import Foundation

// MARK: - BlockedUser Model
struct BlockedUser: Codable, Identifiable {
    let id: UUID
    let blockerId: String
    let blockedId: String
    let createdAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
        case createdAt = "created_at"
    }
}

// MARK: - BlockedUserInsert Model (for creating blocks)
struct BlockedUserInsert: Codable {
    let blockerId: String
    let blockedId: String
    
    enum CodingKeys: String, CodingKey {
        case blockerId = "blocker_id"
        case blockedId = "blocked_id"
    }
}



