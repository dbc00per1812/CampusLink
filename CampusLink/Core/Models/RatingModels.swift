import Foundation

// MARK: - Rating Models

enum RatingType: String, Codable, CaseIterable {
    case buyerToSeller = "buyer_to_seller"
    case sellerToBuyer = "seller_to_buyer"
    
    var displayName: String {
        switch self {
        case .buyerToSeller: return "Rate Seller"
        case .sellerToBuyer: return "Rate Buyer"
        }
    }
}

enum ModerationStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case approved = "approved"
    case rejected = "rejected"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending Review"
        case .approved: return "Approved"
        case .rejected: return "Rejected"
        }
    }
}

struct Rating: Codable, Identifiable {
    let id: UUID
    let orderId: UUID
    let raterId: String
    let ratedId: String
    let rating: Int // 1-5 stars
    let comment: String?
    let ratingType: RatingType
    let isAnonymous: Bool
    let createdAt: Date
    let updatedAt: Date?
    let isReported: Bool
    let isHidden: Bool
    let moderationStatus: ModerationStatus
    
    // Joined data
    var rater: User?
    var ratedUser: User?
    var order: Order?
    
    enum CodingKeys: String, CodingKey {
        case id
        case orderId = "order_id"
        case raterId = "rater_id"
        case ratedId = "rated_id"
        case rating, comment
        case ratingType = "rating_type"
        case isAnonymous = "is_anonymous"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isReported = "is_reported"
        case isHidden = "is_hidden"
        case moderationStatus = "moderation_status"
        case rater
        case ratedUser = "rated_user"
        case order
    }
    
    // Computed properties
    var isPositive: Bool { rating >= 4 }
    var isNeutral: Bool { rating == 3 }
    var isNegative: Bool { rating <= 2 }
    
    var ratingText: String {
        switch rating {
        case 1: return "Poor"
        case 2: return "Fair"
        case 3: return "Good"
        case 4: return "Very Good"
        case 5: return "Excellent"
        default: return "Unknown"
        }
    }
}

struct RatingCreate: Codable {
    let orderId: UUID
    let raterId: String
    let ratedId: String
    let rating: Int
    let comment: String?
    let ratingType: RatingType
    let isAnonymous: Bool
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case raterId = "rater_id"
        case ratedId = "rated_id"
        case rating, comment
        case ratingType = "rating_type"
        case isAnonymous = "is_anonymous"
    }
}

struct UserRatingsSummary: Codable {
    let userId: String
    let averageRating: Double
    let totalRatings: Int
    let trustScore: Double
    let ratingsBreakdown: [Int: Int] // Star count -> Count
    let recentRatings: [Rating]
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case averageRating = "average_rating"
        case totalRatings = "total_ratings"
        case trustScore = "trust_score"
        case ratingsBreakdown = "ratings_breakdown"
        case recentRatings = "recent_ratings"
    }
    
    // Computed properties
    var hasRatings: Bool { totalRatings > 0 }
    var trustLevel: TrustLevel { TrustLevel.from(score: trustScore) }
    var displayRating: String {
        if hasRatings {
            return String(format: "%.1f", averageRating)
        } else {
            // New users start with a default 5.0 star rating
            return "5.0"
        }
    }
}

// MARK: - Trust Level System

enum TrustLevel: String, CaseIterable {
    case trusted = "trusted"       // 80-100
    case reliable = "reliable"     // 60-79
    case new = "new"              // 40-59
    case caution = "caution"      // 20-39
    case risk = "risk"            // 0-19
    
    var displayName: String {
        switch self {
        case .trusted: return "Trusted"
        case .reliable: return "Reliable"
        case .new: return "New"
        case .caution: return "Caution"
        case .risk: return "High Risk"
        }
    }
    
    var emoji: String {
        switch self {
        case .trusted: return "🥇"
        case .reliable: return "🥈"
        case .new: return "🥉"
        case .caution: return "⚠️"
        case .risk: return "🚫"
        }
    }
    
    var color: String {
        switch self {
        case .trusted: return "gold"
        case .reliable: return "silver"
        case .new: return "bronze"
        case .caution: return "orange"
        case .risk: return "red"
        }
    }
    
    var description: String {
        switch self {
        case .trusted: return "Highly trusted member with excellent feedback"
        case .reliable: return "Reliable member with good feedback"
        case .new: return "New member building their reputation"
        case .caution: return "Mixed feedback - proceed with caution"
        case .risk: return "Poor feedback - high risk"
        }
    }
    
    static func from(score: Double) -> TrustLevel {
        switch score {
        case 80...100: return .trusted
        case 60..<80: return .reliable
        case 40..<60: return .new
        case 20..<40: return .caution
        default: return .risk
        }
    }
}

// MARK: - Rating Statistics

struct RatingStats {
    let totalRatings: Int
    let averageRating: Double
    let breakdown: [Int: Int] // Star rating -> count
    let trustScore: Double
    let trustLevel: TrustLevel
    
    var hasRatings: Bool { totalRatings > 0 }
    var displayStars: String {
        guard hasRatings else { return "No ratings yet" }
        return String(repeating: "⭐", count: Int(averageRating.rounded()))
    }
}

// MARK: - Sample Data for Previews

extension Rating {
    static let sampleRating = Rating(
        id: UUID(),
        orderId: UUID(),
        raterId: "sample-rater-id",
        ratedId: "sample-rated-id", 
        rating: 5,
        comment: "Excellent seller! Item was exactly as described and shipped quickly.",
        ratingType: .buyerToSeller,
        isAnonymous: false,
        createdAt: Date(),
        updatedAt: nil,
        isReported: false,
        isHidden: false,
        moderationStatus: .approved,
        rater: User.sampleUser,
        ratedUser: nil,
        order: nil
    )
}

extension UserRatingsSummary {
    static let sampleSummary = UserRatingsSummary(
        userId: "sample-user-id",
        averageRating: 4.7,
        totalRatings: 23,
        trustScore: 85.5,
        ratingsBreakdown: [5: 18, 4: 4, 3: 1, 2: 0, 1: 0],
        recentRatings: [Rating.sampleRating]
    )
}
