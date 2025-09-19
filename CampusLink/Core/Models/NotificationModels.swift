import Foundation
import SwiftUI

// MARK: - Notification Models

enum NotificationType: String, Codable, CaseIterable {
    case orderPlaced = "order_placed"
    case orderConfirmed = "order_confirmed"
    case orderInProgress = "order_in_progress"
    case orderCompleted = "order_completed"
    case orderCancelled = "order_cancelled"
    case paymentSucceeded = "payment_succeeded"
    case paymentFailed = "payment_failed"
    case newMessage = "new_message"
    case ratingReceived = "rating_received"
    case ratingReminder = "rating_reminder"
    case payoutCompleted = "payout_completed"
    case listingInterest = "listing_interest"
    case marketplaceActivity = "marketplace_activity"
    
    var displayName: String {
        switch self {
        case .orderPlaced: return "New Orders"
        case .orderConfirmed: return "Order Confirmations"
        case .orderInProgress: return "Order Updates"
        case .orderCompleted: return "Order Completions"
        case .orderCancelled: return "Order Cancellations"
        case .paymentSucceeded: return "Payment Confirmations"
        case .paymentFailed: return "Payment Failures"
        case .newMessage: return "New Messages"
        case .ratingReceived: return "New Ratings"
        case .ratingReminder: return "Rating Reminders"
        case .payoutCompleted: return "Payout Confirmations"
        case .listingInterest: return "Listing Interest"
        case .marketplaceActivity: return "Marketplace Activity"
        }
    }
    
    var icon: String {
        switch self {
        case .orderPlaced: return "cart.badge.plus"
        case .orderConfirmed: return "checkmark.circle"
        case .orderInProgress: return "clock.arrow.circlepath"
        case .orderCompleted: return "checkmark.circle.fill"
        case .orderCancelled: return "xmark.circle"
        case .paymentSucceeded: return "creditcard.fill"
        case .paymentFailed: return "creditcard.trianglebadge.exclamationmark"
        case .newMessage: return "message.fill"
        case .ratingReceived: return "star.fill"
        case .ratingReminder: return "star.circle"
        case .payoutCompleted: return "arrow.down.circle.fill"
        case .listingInterest: return "heart.fill"
        case .marketplaceActivity: return "bell.fill"
        }
    }
    
    var category: NotificationCategory {
        switch self {
        case .orderPlaced, .orderConfirmed, .orderInProgress, .orderCompleted, .orderCancelled:
            return .orders
        case .paymentSucceeded, .paymentFailed, .payoutCompleted:
            return .payments
        case .newMessage:
            return .messaging
        case .ratingReceived, .ratingReminder:
            return .ratings
        case .listingInterest, .marketplaceActivity:
            return .marketplace
        }
    }
    
    var color: Color {
        switch self {
        case .orderPlaced: return .blue
        case .orderConfirmed: return .green
        case .orderInProgress: return .orange
        case .orderCompleted: return .green
        case .orderCancelled: return .red
        case .paymentSucceeded: return .green
        case .paymentFailed: return .red
        case .newMessage: return .blue
        case .ratingReceived: return .yellow
        case .ratingReminder: return .orange
        case .payoutCompleted: return .green
        case .listingInterest: return .pink
        case .marketplaceActivity: return .purple
        }
    }
}

enum NotificationCategory: String, Codable, CaseIterable {
    case orders = "orders"
    case payments = "payments"
    case messaging = "messaging"
    case ratings = "ratings"
    case marketplace = "marketplace"
    
    var displayName: String {
        switch self {
        case .orders: return "Orders"
        case .payments: return "Payments"
        case .messaging: return "Messages"
        case .ratings: return "Ratings"
        case .marketplace: return "Marketplace"
        }
    }
    
    var icon: String {
        switch self {
        case .orders: return "cart"
        case .payments: return "creditcard"
        case .messaging: return "message"
        case .ratings: return "star"
        case .marketplace: return "storefront"
        }
    }
    
    var color: Color {
        switch self {
        case .orders: return .blue
        case .payments: return .green
        case .messaging: return .blue
        case .ratings: return .yellow
        case .marketplace: return .purple
        }
    }
}

struct Notification: Codable, Identifiable {
    let id: UUID
    let userId: String
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: AnyCodable]
    let isRead: Bool
    let isDelivered: Bool
    let scheduledFor: Date?
    let deliveredAt: Date?
    let readAt: Date?
    let createdAt: Date
    
    // Related entity references
    let orderId: UUID?
    let messageId: UUID?
    let listingId: UUID?
    let relatedUserId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type, title, body, data
        case isRead = "is_read"
        case isDelivered = "is_delivered"
        case scheduledFor = "scheduled_for"
        case deliveredAt = "delivered_at"
        case readAt = "read_at"
        case createdAt = "created_at"
        case orderId = "order_id"
        case messageId = "message_id"
        case listingId = "listing_id"
        case relatedUserId = "related_user_id"
    }
    
    var timeAgo: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .short
        return formatter.localizedString(for: createdAt, relativeTo: Date())
    }
    
    var isRecent: Bool {
        Date().timeIntervalSince(createdAt) < 3600 // Less than 1 hour
    }
}

struct NotificationCreate: Codable {
    let userId: String
    let type: NotificationType
    let title: String
    let body: String
    let data: [String: AnyCodable]
    let scheduledFor: Date?
    let orderId: UUID?
    let messageId: UUID?
    let listingId: UUID?
    let relatedUserId: String?
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case type, title, body, data
        case scheduledFor = "scheduled_for"
        case orderId = "order_id"
        case messageId = "message_id"
        case listingId = "listing_id"
        case relatedUserId = "related_user_id"
    }
}

struct UserNotificationPreferences: Codable {
    let id: UUID
    let userId: String
    
    // Push notification preferences
    let pushEnabled: Bool
    let pushToken: String?
    let pushPlatform: String?
    
    // Notification type preferences
    let orderNotifications: Bool
    let messageNotifications: Bool
    let paymentNotifications: Bool
    let ratingNotifications: Bool
    let marketplaceNotifications: Bool
    
    // Timing preferences
    let quietHoursStart: String
    let quietHoursEnd: String
    let timezone: String
    
    // Frequency controls
    let maxDailyNotifications: Int
    let groupSimilarNotifications: Bool
    
    let createdAt: Date
    let updatedAt: Date
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case pushEnabled = "push_enabled"
        case pushToken = "push_token"
        case pushPlatform = "push_platform"
        case orderNotifications = "order_notifications"
        case messageNotifications = "message_notifications"
        case paymentNotifications = "payment_notifications"
        case ratingNotifications = "rating_notifications"
        case marketplaceNotifications = "marketplace_notifications"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case timezone
        case maxDailyNotifications = "max_daily_notifications"
        case groupSimilarNotifications = "group_similar_notifications"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
    }
    
    static let defaultPreferences = UserNotificationPreferences(
        id: UUID(),
        userId: "",
        pushEnabled: true,
        pushToken: nil,
        pushPlatform: "ios",
        orderNotifications: true,
        messageNotifications: true,
        paymentNotifications: true,
        ratingNotifications: true,
        marketplaceNotifications: false,
        quietHoursStart: "22:00",
        quietHoursEnd: "08:00",
        timezone: "UTC",
        maxDailyNotifications: 10,
        groupSimilarNotifications: true,
        createdAt: Date(),
        updatedAt: Date()
    )
}

struct NotificationPreferencesUpdate: Codable {
    let pushEnabled: Bool?
    let pushToken: String?
    let orderNotifications: Bool?
    let messageNotifications: Bool?
    let paymentNotifications: Bool?
    let ratingNotifications: Bool?
    let marketplaceNotifications: Bool?
    let quietHoursStart: String?
    let quietHoursEnd: String?
    let timezone: String?
    let maxDailyNotifications: Int?
    let groupSimilarNotifications: Bool?
    
    enum CodingKeys: String, CodingKey {
        case pushEnabled = "push_enabled"
        case pushToken = "push_token"
        case orderNotifications = "order_notifications"
        case messageNotifications = "message_notifications"
        case paymentNotifications = "payment_notifications"
        case ratingNotifications = "rating_notifications"
        case marketplaceNotifications = "marketplace_notifications"
        case quietHoursStart = "quiet_hours_start"
        case quietHoursEnd = "quiet_hours_end"
        case timezone
        case maxDailyNotifications = "max_daily_notifications"
        case groupSimilarNotifications = "group_similar_notifications"
    }
}

// MARK: - Helper for JSON encoding/decoding
struct AnyCodable: Codable {
    let value: Any
    
    init(_ value: Any) {
        self.value = value
    }
    
    init(from decoder: Decoder) throws {
        let container = try decoder.singleValueContainer()
        
        if let bool = try? container.decode(Bool.self) {
            value = bool
        } else if let int = try? container.decode(Int.self) {
            value = int
        } else if let double = try? container.decode(Double.self) {
            value = double
        } else if let string = try? container.decode(String.self) {
            value = string
        } else if let array = try? container.decode([AnyCodable].self) {
            value = array.map { $0.value }
        } else if let dictionary = try? container.decode([String: AnyCodable].self) {
            value = dictionary.mapValues { $0.value }
        } else {
            throw DecodingError.typeMismatch(AnyCodable.self, DecodingError.Context(codingPath: decoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
    
    func encode(to encoder: Encoder) throws {
        var container = encoder.singleValueContainer()
        
        switch value {
        case let bool as Bool:
            try container.encode(bool)
        case let int as Int:
            try container.encode(int)
        case let double as Double:
            try container.encode(double)
        case let string as String:
            try container.encode(string)
        case let array as [Any]:
            try container.encode(array.map { AnyCodable($0) })
        case let dictionary as [String: Any]:
            try container.encode(dictionary.mapValues { AnyCodable($0) })
        default:
            throw EncodingError.invalidValue(value, EncodingError.Context(codingPath: encoder.codingPath, debugDescription: "Unsupported type"))
        }
    }
}

// MARK: - Notification Summary Models
struct NotificationSummary: Codable {
    let totalUnread: Int
    let unreadByCategory: [NotificationCategory: Int]
    let recentNotifications: [Notification]
    
    enum CodingKeys: String, CodingKey {
        case totalUnread = "total_unread"
        case unreadByCategory = "unread_by_category"
        case recentNotifications = "recent_notifications"
    }
}

// MARK: - Local Notification Models
struct LocalNotificationRequest {
    let id: String
    let title: String
    let body: String
    let scheduledDate: Date
    let data: [String: Any]
    let category: String?
    let sound: String?
    
    init(
        id: String = UUID().uuidString,
        title: String,
        body: String,
        scheduledDate: Date,
        data: [String: Any] = [:],
        category: String? = nil,
        sound: String? = nil
    ) {
        self.id = id
        self.title = title
        self.body = body
        self.scheduledDate = scheduledDate
        self.data = data
        self.category = category
        self.sound = sound
    }
}
