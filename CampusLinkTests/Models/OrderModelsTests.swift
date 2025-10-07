//
//  OrderModelsTests.swift
//  CampusLinkTests
//
//  Created on October 7, 2025.
//

import XCTest
import SwiftUI
@testable import CampusLink

final class OrderModelsTests: XCTestCase {
    
    // MARK: - OrderStatus Tests
    
    func testOrderStatusRawValues() {
        XCTAssertEqual(OrderStatus.placed.rawValue, "placed")
        XCTAssertEqual(OrderStatus.sellerConfirmed.rawValue, "seller_confirmed")
        XCTAssertEqual(OrderStatus.inProgress.rawValue, "in_progress")
        XCTAssertEqual(OrderStatus.completed.rawValue, "completed")
        XCTAssertEqual(OrderStatus.disputed.rawValue, "disputed")
        XCTAssertEqual(OrderStatus.cancelled.rawValue, "cancelled")
        XCTAssertEqual(OrderStatus.refunded.rawValue, "refunded")
    }
    
    func testOrderStatusDisplayNames() {
        XCTAssertEqual(OrderStatus.placed.displayName, "Order Placed")
        XCTAssertEqual(OrderStatus.sellerConfirmed.displayName, "Seller Confirmed")
        XCTAssertEqual(OrderStatus.inProgress.displayName, "In Progress")
        XCTAssertEqual(OrderStatus.completed.displayName, "Completed")
        XCTAssertEqual(OrderStatus.disputed.displayName, "Disputed")
        XCTAssertEqual(OrderStatus.cancelled.displayName, "Cancelled")
        XCTAssertEqual(OrderStatus.refunded.displayName, "Refunded")
    }
    
    func testOrderStatusIsActive() {
        XCTAssertTrue(OrderStatus.placed.isActive)
        XCTAssertTrue(OrderStatus.sellerConfirmed.isActive)
        XCTAssertTrue(OrderStatus.inProgress.isActive)
        XCTAssertTrue(OrderStatus.completed.isActive)
        XCTAssertTrue(OrderStatus.disputed.isActive)
        XCTAssertFalse(OrderStatus.cancelled.isActive)
        XCTAssertFalse(OrderStatus.refunded.isActive)
    }
    
    func testOrderStatusIsFinal() {
        XCTAssertFalse(OrderStatus.placed.isFinal)
        XCTAssertFalse(OrderStatus.sellerConfirmed.isFinal)
        XCTAssertFalse(OrderStatus.inProgress.isFinal)
        XCTAssertTrue(OrderStatus.completed.isFinal)
        XCTAssertFalse(OrderStatus.disputed.isFinal)
        XCTAssertTrue(OrderStatus.cancelled.isFinal)
        XCTAssertTrue(OrderStatus.refunded.isFinal)
    }
    
    func testOrderStatusIcons() {
        XCTAssertEqual(OrderStatus.placed.icon, "cart.badge.plus")
        XCTAssertEqual(OrderStatus.sellerConfirmed.icon, "checkmark.circle")
        XCTAssertEqual(OrderStatus.inProgress.icon, "clock.arrow.circlepath")
        XCTAssertEqual(OrderStatus.completed.icon, "checkmark.circle.fill")
        XCTAssertEqual(OrderStatus.disputed.icon, "exclamationmark.triangle")
        XCTAssertEqual(OrderStatus.cancelled.icon, "xmark.circle")
        XCTAssertEqual(OrderStatus.refunded.icon, "arrow.uturn.left.circle")
    }
    
    // MARK: - PaymentStatus Tests
    
    func testPaymentStatusRawValues() {
        XCTAssertEqual(PaymentStatus.pending.rawValue, "pending")
        XCTAssertEqual(PaymentStatus.requiresCapture.rawValue, "requires_capture")
        XCTAssertEqual(PaymentStatus.captured.rawValue, "captured")
        XCTAssertEqual(PaymentStatus.succeeded.rawValue, "succeeded")
        XCTAssertEqual(PaymentStatus.released.rawValue, "released")
        XCTAssertEqual(PaymentStatus.failed.rawValue, "failed")
        XCTAssertEqual(PaymentStatus.refunded.rawValue, "refunded")
    }
    
    func testPaymentStatusDisplayNames() {
        XCTAssertEqual(PaymentStatus.pending.displayName, "Payment Pending")
        XCTAssertEqual(PaymentStatus.requiresCapture.displayName, "Payment Ready")
        XCTAssertEqual(PaymentStatus.captured.displayName, "Payment Captured")
        XCTAssertEqual(PaymentStatus.succeeded.displayName, "Payment Succeeded")
        XCTAssertEqual(PaymentStatus.released.displayName, "Payment Released")
        XCTAssertEqual(PaymentStatus.failed.displayName, "Payment Failed")
        XCTAssertEqual(PaymentStatus.refunded.displayName, "Payment Refunded")
    }
    
    func testPaymentStatusIsActive() {
        XCTAssertTrue(PaymentStatus.pending.isActive)
        XCTAssertTrue(PaymentStatus.requiresCapture.isActive)
        XCTAssertTrue(PaymentStatus.captured.isActive)
        XCTAssertTrue(PaymentStatus.succeeded.isActive)
        XCTAssertFalse(PaymentStatus.released.isActive)
        XCTAssertFalse(PaymentStatus.failed.isActive)
        XCTAssertFalse(PaymentStatus.refunded.isActive)
    }
    
    // MARK: - PaymentMethod Tests
    
    func testPaymentMethodRawValues() {
        XCTAssertEqual(PaymentMethod.wallet.rawValue, "wallet")
        XCTAssertEqual(PaymentMethod.card.rawValue, "card")
    }
    
    func testPaymentMethodDisplayNames() {
        XCTAssertEqual(PaymentMethod.wallet.displayName, "Campus Wallet")
        XCTAssertEqual(PaymentMethod.card.displayName, "Credit/Debit Card")
    }
    
    func testPaymentMethodRequiresEscrow() {
        XCTAssertTrue(PaymentMethod.wallet.requiresEscrow)
        XCTAssertTrue(PaymentMethod.card.requiresEscrow)
    }
    
    func testPaymentMethodIcons() {
        XCTAssertEqual(PaymentMethod.wallet.icon, "creditcard.fill")
        XCTAssertEqual(PaymentMethod.card.icon, "creditcard")
    }
    
    // MARK: - Order Tests
    
    func testOrderInitialization() {
        let orderId = UUID()
        let listingId = UUID()
        let buyerId = UUID()
        let sellerId = UUID()
        let now = Date()
        
        let order = Order(
            id: orderId,
            listingId: listingId,
            buyerId: buyerId,
            sellerId: sellerId,
            priceCents: 5000, // $50.00
            paymentMethod: .wallet,
            paymentStatus: .pending,
            orderStatus: .placed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: now,
            autoReleaseAt: now.addingTimeInterval(7 * 24 * 60 * 60), // 7 days
            createdAt: now,
            stripeEscrowAccountId: "escrow_123",
            marketplaceFeeCents: 500,
            stripePaymentIntentId: "pi_123",
            timeSlotId: nil,
            listing: nil
        )
        
        XCTAssertEqual(order.id, orderId)
        XCTAssertEqual(order.priceCents, 5000)
        XCTAssertEqual(order.price, 50.0)
        XCTAssertEqual(order.formattedPrice, "$50.00")
        XCTAssertTrue(order.isActive)
        XCTAssertFalse(order.isFinal)
        XCTAssertTrue(order.requiresEscrow)
        XCTAssertTrue(order.hasEscrowAccount)
        XCTAssertEqual(order.escrowStatus, "Held in Escrow")
    }
    
    func testOrderEscrowStatus() {
        let now = Date()
        
        // Test no escrow
        let orderNoEscrow = Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 1000,
            paymentMethod: .wallet,
            paymentStatus: .pending,
            orderStatus: .placed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: now,
            autoReleaseAt: nil,
            createdAt: now,
            stripeEscrowAccountId: nil,
            marketplaceFeeCents: 0,
            stripePaymentIntentId: nil,
            timeSlotId: nil,
            listing: nil
        )
        XCTAssertEqual(orderNoEscrow.escrowStatus, "No Escrow")
        
        // Test released escrow
        let orderReleased = Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 1000,
            paymentMethod: .wallet,
            paymentStatus: .released,
            orderStatus: .completed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: now,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: now,
            autoReleaseAt: now.addingTimeInterval(7 * 24 * 60 * 60),
            createdAt: now,
            stripeEscrowAccountId: "escrow_123",
            marketplaceFeeCents: 0,
            stripePaymentIntentId: nil,
            timeSlotId: nil,
            listing: nil
        )
        XCTAssertEqual(orderReleased.escrowStatus, "Released")
        
        // Test auto-released escrow
        let orderAutoReleased = Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 1000,
            paymentMethod: .wallet,
            paymentStatus: .succeeded,
            orderStatus: .placed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: now,
            autoReleaseAt: now.addingTimeInterval(-60), // 1 minute ago
            createdAt: now,
            stripeEscrowAccountId: "escrow_123",
            marketplaceFeeCents: 0,
            stripePaymentIntentId: nil,
            timeSlotId: nil,
            listing: nil
        )
        XCTAssertEqual(orderAutoReleased.escrowStatus, "Auto-Released")
    }
    
    func testOrderAutoReleaseFormatting() {
        let now = Date()
        
        // Test minutes
        let orderMinutes = Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 1000,
            paymentMethod: .wallet,
            paymentStatus: .pending,
            orderStatus: .placed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: now,
            autoReleaseAt: now.addingTimeInterval(30 * 60), // 30 minutes
            createdAt: now,
            stripeEscrowAccountId: nil,
            marketplaceFeeCents: 0,
            stripePaymentIntentId: nil,
            timeSlotId: nil,
            listing: nil
        )
        XCTAssertEqual(orderMinutes.autoReleaseFormatted, "30 minutes")
        
        // Test hours
        let orderHours = Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 1000,
            paymentMethod: .wallet,
            paymentStatus: .pending,
            orderStatus: .placed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: now,
            autoReleaseAt: now.addingTimeInterval(5 * 60 * 60), // 5 hours
            createdAt: now,
            stripeEscrowAccountId: nil,
            marketplaceFeeCents: 0,
            stripePaymentIntentId: nil,
            timeSlotId: nil,
            listing: nil
        )
        XCTAssertEqual(orderHours.autoReleaseFormatted, "5 hours")
        
        // Test days
        let orderDays = Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 1000,
            paymentMethod: .wallet,
            paymentStatus: .pending,
            orderStatus: .placed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: now,
            autoReleaseAt: now.addingTimeInterval(3 * 24 * 60 * 60), // 3 days
            createdAt: now,
            stripeEscrowAccountId: nil,
            marketplaceFeeCents: 0,
            stripePaymentIntentId: nil,
            timeSlotId: nil,
            listing: nil
        )
        XCTAssertEqual(orderDays.autoReleaseFormatted, "3 days")
    }
    
    func testOrderCodable() throws {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        
        let original = Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 2500,
            paymentMethod: .card,
            paymentStatus: .succeeded,
            orderStatus: .completed,
            sellerConfirmedAt: Date(),
            inProgressAt: Date(),
            completedAt: Date(),
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: Date(),
            autoReleaseAt: nil,
            createdAt: Date(),
            stripeEscrowAccountId: "escrow_test",
            marketplaceFeeCents: 250,
            stripePaymentIntentId: "pi_test",
            timeSlotId: nil,
            listing: nil
        )
        
        let data = try encoder.encode(original)
        let decoded = try decoder.decode(Order.self, from: data)
        
        XCTAssertEqual(original.id, decoded.id)
        XCTAssertEqual(original.priceCents, decoded.priceCents)
        XCTAssertEqual(original.paymentMethod, decoded.paymentMethod)
        XCTAssertEqual(original.orderStatus, decoded.orderStatus)
        XCTAssertEqual(original.paymentStatus, decoded.paymentStatus)
    }
    
    // MARK: - OrderWithDetails Tests
    
    func testOrderWithDetailsInitialization() {
        let order = Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 3000,
            paymentMethod: .wallet,
            paymentStatus: .pending,
            orderStatus: .placed,
            sellerConfirmedAt: nil,
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: Date(),
            autoReleaseAt: Date().addingTimeInterval(7 * 24 * 60 * 60),
            createdAt: Date(),
            stripeEscrowAccountId: nil,
            marketplaceFeeCents: 0,
            stripePaymentIntentId: nil,
            timeSlotId: nil,
            listing: nil
        )
        
        let orderWithDetails = OrderWithDetails(
            order: order,
            listing: Listing.sampleListing,
            buyer: UserProfile.sampleProfile,
            seller: UserProfile.sampleProfile
        )
        
        XCTAssertEqual(orderWithDetails.id, order.id)
        XCTAssertEqual(orderWithDetails.order.priceCents, 3000)
    }
    
    // MARK: - OrderStats Tests
    
    func testOrderStatsCalculations() {
        let stats = OrderStats(
            totalOrders: 100,
            activeOrders: 20,
            completedOrders: 75,
            disputedOrders: 5,
            totalValue: 10000.0,
            averageOrderValue: 100.0
        )
        
        XCTAssertEqual(stats.completionRate, 0.75)
        XCTAssertEqual(stats.disputeRate, 0.05)
    }
    
    func testOrderStatsZeroOrders() {
        let stats = OrderStats(
            totalOrders: 0,
            activeOrders: 0,
            completedOrders: 0,
            disputedOrders: 0,
            totalValue: 0.0,
            averageOrderValue: 0.0
        )
        
        XCTAssertEqual(stats.completionRate, 0.0)
        XCTAssertEqual(stats.disputeRate, 0.0)
    }
    
    // MARK: - OrderFilters Tests
    
    func testOrderFiltersInitialization() {
        let allFilters = OrderFilters.all
        XCTAssertNil(allFilters.status)
        XCTAssertNil(allFilters.paymentMethod)
        XCTAssertNil(allFilters.isActive)
        XCTAssertNil(allFilters.dateRange)
        
        let activeFilters = OrderFilters.active
        XCTAssertTrue(activeFilters.isActive ?? false)
        
        let completedFilters = OrderFilters.completed
        XCTAssertEqual(completedFilters.status, .completed)
        
        let disputedFilters = OrderFilters.disputed
        XCTAssertEqual(disputedFilters.status, .disputed)
    }
}
