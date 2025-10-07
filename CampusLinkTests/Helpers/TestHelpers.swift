//
//  TestHelpers.swift
//  CampusLinkTests
//
//  Created on October 7, 2025.
//

import Foundation
import XCTest
@testable import CampusLink

// MARK: - Test Data Builders

struct TestDataBuilder {
    
    // MARK: - User Creation
    
    static func createTestUser(
        id: String = UUID().uuidString,
        name: String = "Test User",
        email: String = "test@university.edu",
        trustScore: Int = 85,
        campusEmailVerified: Bool = true
    ) -> User {
        return User(
            id: id,
            name: name,
            bio: "Test user bio",
            profilePic: nil,
            email: email,
            createdAt: Date(),
            campusEmailVerified: campusEmailVerified,
            trustScore: trustScore,
            stripeConnectId: "acct_test123",
            stripePayoutsEnabled: true,
            stripeDetailsSubmitted: true
        )
    }
    
    // MARK: - Listing Creation
    
    static func createTestListing(
        id: UUID = UUID(),
        userId: String = "test-user",
        title: String = "Test Product",
        price: Double = 50.0,
        category: String = "Electronics",
        intent: ListingIntent = .offer
    ) -> Listing {
        return Listing(
            id: id,
            userId: userId,
            title: title,
            description: "Test product description",
            price: price,
            category: category,
            photo: nil,
            photos: ["test1.jpg", "test2.jpg"],
            isSold: false,
            listingType: .product,
            serviceDuration: nil,
            serviceLocation: nil,
            serviceAvailability: nil,
            archived: false,
            createdAt: Date(),
            intent: intent,
            budgetMin: intent == .seek ? 20.0 : nil,
            budgetMax: intent == .seek ? 100.0 : nil,
            expiresAt: nil
        )
    }
    
    // MARK: - Order Creation
    
    static func createTestOrder(
        id: UUID = UUID(),
        listingId: UUID = UUID(),
        buyerId: UUID = UUID(),
        sellerId: UUID = UUID(),
        priceCents: Int = 5000,
        status: OrderStatus = .placed,
        paymentStatus: PaymentStatus = .pending
    ) -> Order {
        return Order(
            id: id,
            listingId: listingId,
            buyerId: buyerId,
            sellerId: sellerId,
            priceCents: priceCents,
            paymentMethod: .wallet,
            paymentStatus: paymentStatus,
            orderStatus: status,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: Date(),
            autoReleaseAt: Date().addingTimeInterval(7 * 24 * 60 * 60),
            createdAt: Date(),
            stripeEscrowAccountId: "escrow_test",
            marketplaceFeeCents: 500,
            stripePaymentIntentId: "pi_test",
            timeSlotId: nil,
            listing: nil
        )
    }
    
    // MARK: - Message Creation
    
    static func createTestMessage(
        id: UUID = UUID(),
        conversationId: UUID = UUID(),
        senderId: String = "sender-123",
        content: String = "Test message",
        isRead: Bool = false
    ) -> Message {
        return Message(
            id: id,
            conversationId: conversationId,
            senderId: senderId,
            content: content,
            messageType: "text",
            readAt: isRead ? Date() : nil,
            createdAt: Date(),
            updatedAt: Date(),
            sender: createTestUser(id: senderId)
        )
    }
    
    // MARK: - Conversation Creation
    
    static func createTestConversation(
        id: UUID = UUID(),
        listingId: UUID = UUID(),
        buyerId: String = "buyer-123",
        sellerId: String = "seller-456",
        unreadCount: Int = 0
    ) -> Conversation {
        return Conversation(
            id: id,
            listingId: listingId,
            buyerId: buyerId,
            sellerId: sellerId,
            lastMessageAt: Date(),
            createdAt: Date(),
            unreadCount: unreadCount,
            lastMessage: "Last message content",
            listing: createTestListing(),
            buyer: createTestUser(id: buyerId),
            seller: createTestUser(id: sellerId)
        )
    }
    
    // MARK: - Wallet Creation
    
    static func createTestWallet(
        userId: UUID = UUID(),
        availableCents: Int = 10000,
        escrowCents: Int = 2000
    ) -> Wallet {
        return Wallet(
            userId: userId,
            availableCents: availableCents,
            escrowCents: escrowCents,
            updatedAt: Date()
        )
    }
    
    // MARK: - Notification Creation
    
    static func createTestNotification(
        id: UUID = UUID(),
        userId: String = "user-123",
        type: NotificationType = .orderPlaced,
        isRead: Bool = false
    ) -> Notification {
        return Notification(
            id: id,
            userId: userId,
            type: type,
            title: "Test Notification",
            body: "This is a test notification",
            data: [:],
            isRead: isRead,
            isDelivered: true,
            scheduledFor: nil,
            deliveredAt: Date(),
            readAt: isRead ? Date() : nil,
            createdAt: Date(),
            orderId: nil,
            messageId: nil,
            listingId: nil,
            relatedUserId: nil
        )
    }
}

// MARK: - XCTest Extensions

extension XCTestCase {
    
    /// Wait for a condition to become true
    func waitForCondition(
        timeout: TimeInterval = 5.0,
        condition: @escaping () -> Bool,
        file: StaticString = #file,
        line: UInt = #line
    ) {
        let expectation = XCTestExpectation(description: "Waiting for condition")
        
        let startTime = Date()
        
        func checkCondition() {
            if condition() {
                expectation.fulfill()
            } else if Date().timeIntervalSince(startTime) < timeout {
                DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                    checkCondition()
                }
            }
        }
        
        checkCondition()
        
        let result = XCTWaiter.wait(for: [expectation], timeout: timeout)
        if result != .completed {
            XCTFail("Condition not met within timeout", file: file, line: line)
        }
    }
    
    /// Assert that an async throwing function throws a specific error
    func assertAsyncThrows<T, E: Error & Equatable>(
        _ expression: @autoclosure () async throws -> T,
        throws expectedError: E,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
            XCTFail("Expected error \(expectedError) but no error was thrown", file: file, line: line)
        } catch let error as E {
            XCTAssertEqual(error, expectedError, file: file, line: line)
        } catch {
            XCTFail("Expected error \(expectedError) but got \(error)", file: file, line: line)
        }
    }
    
    /// Assert that an async function does not throw
    func assertAsyncNoThrow<T>(
        _ expression: @autoclosure () async throws -> T,
        file: StaticString = #file,
        line: UInt = #line
    ) async {
        do {
            _ = try await expression()
        } catch {
            XCTFail("Unexpected error thrown: \(error)", file: file, line: line)
        }
    }
}

// MARK: - Mock Network Response

struct MockNetworkResponse {
    let data: Data?
    let response: URLResponse?
    let error: Error?
    
    static func success(with data: Data) -> MockNetworkResponse {
        return MockNetworkResponse(
            data: data,
            response: HTTPURLResponse(
                url: URL(string: "https://test.com")!,
                statusCode: 200,
                httpVersion: nil,
                headerFields: nil
            ),
            error: nil
        )
    }
    
    static func failure(with error: Error) -> MockNetworkResponse {
        return MockNetworkResponse(
            data: nil,
            response: nil,
            error: error
        )
    }
}

// MARK: - Date Test Helpers

extension Date {
    static func testDate(
        year: Int = 2025,
        month: Int = 10,
        day: Int = 7,
        hour: Int = 12,
        minute: Int = 0
    ) -> Date {
        var components = DateComponents()
        components.year = year
        components.month = month
        components.day = day
        components.hour = hour
        components.minute = minute
        components.timeZone = TimeZone(identifier: "UTC")
        
        return Calendar.current.date(from: components) ?? Date()
    }
}

// MARK: - JSON Helpers

struct JSONTestHelper {
    
    static func encode<T: Encodable>(_ value: T) throws -> Data {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        return try encoder.encode(value)
    }
    
    static func decode<T: Decodable>(_ type: T.Type, from data: Data) throws -> T {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(type, from: data)
    }
    
    static func loadJSONFromFile<T: Decodable>(
        _ filename: String,
        type: T.Type,
        bundle: Bundle = Bundle(for: TestDataBuilder.self)
    ) throws -> T {
        guard let url = bundle.url(forResource: filename, withExtension: "json") else {
            throw NSError(domain: "TestError", code: 404, userInfo: [
                NSLocalizedDescriptionKey: "JSON file '\(filename).json' not found"
            ])
        }
        
        let data = try Data(contentsOf: url)
        return try decode(type, from: data)
    }
}

// MARK: - Performance Test Helpers

extension XCTestCase {
    
    func measureAsync(
        timeout: TimeInterval = 10,
        block: @escaping () async throws -> Void
    ) {
        measure {
            let expectation = XCTestExpectation(description: "Async performance test")
            
            Task {
                do {
                    try await block()
                    expectation.fulfill()
                } catch {
                    XCTFail("Performance test failed with error: \(error)")
                    expectation.fulfill()
                }
            }
            
            wait(for: [expectation], timeout: timeout)
        }
    }
}

// MARK: - Mock Timer

class MockTimer {
    private var handlers: [TimeInterval: [() -> Void]] = [:]
    private var currentTime: TimeInterval = 0
    
    func schedule(after interval: TimeInterval, handler: @escaping () -> Void) {
        let fireTime = currentTime + interval
        if handlers[fireTime] == nil {
            handlers[fireTime] = []
        }
        handlers[fireTime]?.append(handler)
    }
    
    func advance(by interval: TimeInterval) {
        let targetTime = currentTime + interval
        
        for time in handlers.keys.sorted() where time <= targetTime {
            handlers[time]?.forEach { $0() }
            handlers[time] = nil
        }
        
        currentTime = targetTime
    }
    
    func reset() {
        handlers.removeAll()
        currentTime = 0
    }
}
