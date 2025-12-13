//
//  NotificationModelsTests.swift
//  CampusLinkTests
//
//  Created on October 7, 2025.
//

import XCTest
import SwiftUI
@testable import CampusLink

final class NotificationModelsTests: XCTestCase {
    
    // MARK: - NotificationType Tests
    
    func testNotificationTypeRawValues() {
        XCTAssertEqual(NotificationType.orderPlaced.rawValue, "order_placed")
        XCTAssertEqual(NotificationType.orderConfirmed.rawValue, "order_confirmed")
        XCTAssertEqual(NotificationType.orderInProgress.rawValue, "order_in_progress")
        XCTAssertEqual(NotificationType.orderCompleted.rawValue, "order_completed")
        XCTAssertEqual(NotificationType.orderCancelled.rawValue, "order_cancelled")
        XCTAssertEqual(NotificationType.paymentSucceeded.rawValue, "payment_succeeded")
        XCTAssertEqual(NotificationType.paymentFailed.rawValue, "payment_failed")
        XCTAssertEqual(NotificationType.newMessage.rawValue, "new_message")
        XCTAssertEqual(NotificationType.ratingReceived.rawValue, "rating_received")
        XCTAssertEqual(NotificationType.ratingReminder.rawValue, "rating_reminder")
        XCTAssertEqual(NotificationType.payoutCompleted.rawValue, "payout_completed")
        XCTAssertEqual(NotificationType.listingInterest.rawValue, "listing_interest")
        XCTAssertEqual(NotificationType.marketplaceActivity.rawValue, "marketplace_activity")
    }
    
    func testNotificationTypeDisplayNames() {
        XCTAssertEqual(NotificationType.orderPlaced.displayName, "New Orders")
        XCTAssertEqual(NotificationType.orderConfirmed.displayName, "Order Confirmations")
        XCTAssertEqual(NotificationType.newMessage.displayName, "New Messages")
        XCTAssertEqual(NotificationType.ratingReceived.displayName, "New Ratings")
        XCTAssertEqual(NotificationType.payoutCompleted.displayName, "Payout Confirmations")
    }
    
    func testNotificationTypeIcons() {
        XCTAssertEqual(NotificationType.orderPlaced.icon, "cart.badge.plus")
        XCTAssertEqual(NotificationType.newMessage.icon, "message.fill")
        XCTAssertEqual(NotificationType.ratingReceived.icon, "star.fill")
        XCTAssertEqual(NotificationType.paymentSucceeded.icon, "creditcard.fill")
        XCTAssertEqual(NotificationType.paymentFailed.icon, "creditcard.trianglebadge.exclamationmark")
    }
    
    func testNotificationTypeCategories() {
        // Test order notifications
        XCTAssertEqual(NotificationType.orderPlaced.category, .orders)
        XCTAssertEqual(NotificationType.orderConfirmed.category, .orders)
        XCTAssertEqual(NotificationType.orderCompleted.category, .orders)
        
        // Test payment notifications
        XCTAssertEqual(NotificationType.paymentSucceeded.category, .payments)
        XCTAssertEqual(NotificationType.paymentFailed.category, .payments)
        XCTAssertEqual(NotificationType.payoutCompleted.category, .payments)
        
        // Test other categories
        XCTAssertEqual(NotificationType.newMessage.category, .messaging)
        XCTAssertEqual(NotificationType.ratingReceived.category, .ratings)
        XCTAssertEqual(NotificationType.listingInterest.category, .marketplace)
    }
    
    func testNotificationTypeColors() {
        XCTAssertEqual(NotificationType.orderPlaced.color, .blue)
        XCTAssertEqual(NotificationType.orderConfirmed.color, .green)
        XCTAssertEqual(NotificationType.orderCancelled.color, .red)
        XCTAssertEqual(NotificationType.paymentSucceeded.color, .green)
        XCTAssertEqual(NotificationType.paymentFailed.color, .red)
    }
    
    // MARK: - NotificationCategory Tests
    
    func testNotificationCategoryRawValues() {
        XCTAssertEqual(NotificationCategory.orders.rawValue, "orders")
        XCTAssertEqual(NotificationCategory.payments.rawValue, "payments")
        XCTAssertEqual(NotificationCategory.messaging.rawValue, "messaging")
        XCTAssertEqual(NotificationCategory.ratings.rawValue, "ratings")
        XCTAssertEqual(NotificationCategory.marketplace.rawValue, "marketplace")
    }
    
    func testNotificationCategoryDisplayNames() {
        XCTAssertEqual(NotificationCategory.orders.displayName, "Orders")
        XCTAssertEqual(NotificationCategory.payments.displayName, "Payments")
        XCTAssertEqual(NotificationCategory.messaging.displayName, "Messages")
        XCTAssertEqual(NotificationCategory.ratings.displayName, "Ratings")
        XCTAssertEqual(NotificationCategory.marketplace.displayName, "Marketplace")
    }
    
    func testNotificationCategoryIcons() {
        XCTAssertEqual(NotificationCategory.orders.icon, "cart")
        XCTAssertEqual(NotificationCategory.payments.icon, "creditcard")
        XCTAssertEqual(NotificationCategory.messaging.icon, "message")
        XCTAssertEqual(NotificationCategory.ratings.icon, "star")
        XCTAssertEqual(NotificationCategory.marketplace.icon, "storefront")
    }
    
    // MARK: - Notification Tests
    
    func testNotificationInitialization() {
        let notification = Notification(
            id: UUID(),
            userId: "user-123",
            type: .orderPlaced,
            title: "New Order",
            body: "You have a new order!",
            data: ["orderId": AnyCodable("order-456")],
            isRead: false,
            isDelivered: true,
            scheduledFor: nil,
            deliveredAt: Date(),
            readAt: nil,
            createdAt: Date(),
            orderId: UUID(),
            messageId: nil,
            listingId: nil,
            relatedUserId: "buyer-789"
        )
        
        XCTAssertEqual(notification.userId, "user-123")
        XCTAssertEqual(notification.type, .orderPlaced)
        XCTAssertEqual(notification.title, "New Order")
        XCTAssertFalse(notification.isRead)
        XCTAssertTrue(notification.isDelivered)
        XCTAssertNotNil(notification.deliveredAt)
        XCTAssertNil(notification.readAt)
    }
    
    func testNotificationIsRecent() {
        // Recent notification (just created)
        let recentNotification = Notification(
            id: UUID(),
            userId: "user-123",
            type: .newMessage,
            title: "New Message",
            body: "You have a new message",
            data: [:],
            isRead: false,
            isDelivered: true,
            scheduledFor: nil,
            deliveredAt: Date(),
            readAt: nil,
            createdAt: Date(),
            orderId: nil,
            messageId: UUID(),
            listingId: nil,
            relatedUserId: nil
        )
        
        XCTAssertTrue(recentNotification.isRecent)
        
        // Old notification (2 hours ago)
        let oldNotification = Notification(
            id: UUID(),
            userId: "user-123",
            type: .newMessage,
            title: "Old Message",
            body: "You have an old message",
            data: [:],
            isRead: true,
            isDelivered: true,
            scheduledFor: nil,
            deliveredAt: Date().addingTimeInterval(-7200),
            readAt: Date().addingTimeInterval(-7200),
            createdAt: Date().addingTimeInterval(-7200), // 2 hours ago
            orderId: nil,
            messageId: UUID(),
            listingId: nil,
            relatedUserId: nil
        )
        
        XCTAssertFalse(oldNotification.isRecent)
    }
    
    func testNotificationTimeAgo() {
        let notification = Notification(
            id: UUID(),
            userId: "user-123",
            type: .orderPlaced,
            title: "Test",
            body: "Test",
            data: [:],
            isRead: false,
            isDelivered: true,
            scheduledFor: nil,
            deliveredAt: Date(),
            readAt: nil,
            createdAt: Date().addingTimeInterval(-300), // 5 minutes ago
            orderId: nil,
            messageId: nil,
            listingId: nil,
            relatedUserId: nil
        )
        
        // Time ago string should contain something like "5 min. ago"
        XCTAssertFalse(notification.timeAgo.isEmpty)
    }
    
    // MARK: - UserNotificationPreferences Tests
    
    func testUserNotificationPreferencesDefaults() {
        let defaults = UserNotificationPreferences.defaultPreferences
        
        XCTAssertTrue(defaults.pushEnabled)
        XCTAssertEqual(defaults.pushPlatform, "ios")
        XCTAssertTrue(defaults.orderNotifications)
        XCTAssertTrue(defaults.messageNotifications)
        XCTAssertTrue(defaults.paymentNotifications)
        XCTAssertTrue(defaults.ratingNotifications)
        XCTAssertFalse(defaults.marketplaceNotifications)
        XCTAssertEqual(defaults.quietHoursStart, "22:00")
        XCTAssertEqual(defaults.quietHoursEnd, "08:00")
        XCTAssertEqual(defaults.timezone, "UTC")
        XCTAssertEqual(defaults.maxDailyNotifications, 10)
        XCTAssertTrue(defaults.groupSimilarNotifications)
    }
    
    func testUserNotificationPreferencesCodable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let original = UserNotificationPreferences(
            id: UUID(),
            userId: "user-123",
            pushEnabled: true,
            pushToken: "token123",
            pushPlatform: "ios",
            orderNotifications: true,
            messageNotifications: false,
            paymentNotifications: true,
            ratingNotifications: true,
            marketplaceNotifications: false,
            quietHoursStart: "23:00",
            quietHoursEnd: "07:00",
            timezone: "America/New_York",
            maxDailyNotifications: 20,
            groupSimilarNotifications: false,
            createdAt: Date(),
            updatedAt: Date()
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(UserNotificationPreferences.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.userId, decoded.userId)
        XCTAssertEqual(original.pushEnabled, decoded.pushEnabled)
        XCTAssertEqual(original.pushToken, decoded.pushToken)
        XCTAssertEqual(original.messageNotifications, decoded.messageNotifications)
        XCTAssertEqual(original.timezone, decoded.timezone)
        XCTAssertEqual(original.maxDailyNotifications, decoded.maxDailyNotifications)
    }
    
    // MARK: - AnyCodable Tests
    
    func testAnyCodableWithPrimitives() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test Bool
        let boolCodable = AnyCodable(true)
        let boolData = try encoder.encode(boolCodable)
        let decodedBool = try decoder.decode(AnyCodable.self, from: boolData)
        XCTAssertEqual(decodedBool.value as? Bool, true)
        
        // Test Int
        let intCodable = AnyCodable(42)
        let intData = try encoder.encode(intCodable)
        let decodedInt = try decoder.decode(AnyCodable.self, from: intData)
        XCTAssertEqual(decodedInt.value as? Int, 42)
        
        // Test Double
        let doubleCodable = AnyCodable(3.14)
        let doubleData = try encoder.encode(doubleCodable)
        let decodedDouble = try decoder.decode(AnyCodable.self, from: doubleData)
        XCTAssertEqual(decodedDouble.value as? Double, 3.14)
        
        // Test String
        let stringCodable = AnyCodable("Hello, World!")
        let stringData = try encoder.encode(stringCodable)
        let decodedString = try decoder.decode(AnyCodable.self, from: stringData)
        XCTAssertEqual(decodedString.value as? String, "Hello, World!")
    }
    
    func testAnyCodableWithCollections() throws {
        let encoder = JSONEncoder()
        let decoder = JSONDecoder()
        
        // Test Array
        let arrayCodable = AnyCodable([1, 2, 3])
        let arrayData = try encoder.encode(arrayCodable)
        let decodedArray = try decoder.decode(AnyCodable.self, from: arrayData)
        if let array = decodedArray.value as? [Any] {
            XCTAssertEqual(array.count, 3)
            XCTAssertEqual(array[0] as? Int, 1)
            XCTAssertEqual(array[1] as? Int, 2)
            XCTAssertEqual(array[2] as? Int, 3)
        } else {
            XCTFail("Failed to decode array")
        }
        
        // Test Dictionary
        let dictCodable = AnyCodable(["key": "value", "number": 123])
        let dictData = try encoder.encode(dictCodable)
        let decodedDict = try decoder.decode(AnyCodable.self, from: dictData)
        if let dict = decodedDict.value as? [String: Any] {
            XCTAssertEqual(dict["key"] as? String, "value")
            XCTAssertEqual(dict["number"] as? Int, 123)
        } else {
            XCTFail("Failed to decode dictionary")
        }
    }
    
    // MARK: - LocalNotificationRequest Tests
    
    func testLocalNotificationRequestInitialization() {
        let date = Date().addingTimeInterval(3600) // 1 hour from now
        let request = LocalNotificationRequest(
            title: "Test Notification",
            body: "This is a test",
            scheduledDate: date,
            data: ["key": "value"],
            category: "order",
            sound: "default"
        )
        
        XCTAssertFalse(request.id.isEmpty)
        XCTAssertEqual(request.title, "Test Notification")
        XCTAssertEqual(request.body, "This is a test")
        XCTAssertEqual(request.scheduledDate, date)
        XCTAssertEqual(request.data["key"] as? String, "value")
        XCTAssertEqual(request.category, "order")
        XCTAssertEqual(request.sound, "default")
    }
    
    func testLocalNotificationRequestDefaultValues() {
        let request = LocalNotificationRequest(
            title: "Test",
            body: "Body",
            scheduledDate: Date()
        )
        
        XCTAssertFalse(request.id.isEmpty)
        XCTAssertTrue(request.data.isEmpty)
        XCTAssertNil(request.category)
        XCTAssertNil(request.sound)
    }
}
