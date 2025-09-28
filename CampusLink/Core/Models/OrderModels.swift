import Foundation
import SwiftUI

// MARK: - Order Status Enum
enum OrderStatus: String, Codable, CaseIterable {
    case placed = "placed"
    case sellerConfirmed = "seller_confirmed"
    case inProgress = "in_progress"
    case completed = "completed"
    case disputed = "disputed"
    case cancelled = "cancelled"
    case refunded = "refunded"
    
    var displayName: String {
        switch self {
        case .placed: return "Order Placed"
        case .sellerConfirmed: return "Seller Confirmed"
        case .inProgress: return "In Progress"
        case .completed: return "Completed"
        case .disputed: return "Disputed"
        case .cancelled: return "Cancelled"
        case .refunded: return "Refunded"
        }
    }
    
    var badgeColor: Color {
        switch self {
        case .placed: return .blue
        case .sellerConfirmed: return .orange
        case .inProgress: return .yellow
        case .completed: return .green
        case .disputed: return .red
        case .cancelled: return .gray
        case .refunded: return .purple
        }
    }
    
    var isActive: Bool {
        switch self {
        case .placed, .sellerConfirmed, .inProgress, .completed, .disputed:
            return true
        case .cancelled, .refunded:
            return false
        }
    }
    
    var isFinal: Bool {
        switch self {
        case .completed, .cancelled, .refunded:
            return true
        default:
            return false
        }
    }
    
    var icon: String {
        switch self {
        case .placed: return "cart.badge.plus"
        case .sellerConfirmed: return "checkmark.circle"
        case .inProgress: return "clock.arrow.circlepath"
        case .completed: return "checkmark.circle.fill"
        case .disputed: return "exclamationmark.triangle"
        case .cancelled: return "xmark.circle"
        case .refunded: return "arrow.uturn.left.circle"
        }
    }
    
    var color: String {
        switch self {
        case .placed: return "blue"
        case .sellerConfirmed: return "orange"
        case .inProgress: return "yellow"
        case .completed: return "green"
        case .disputed: return "red"
        case .cancelled: return "gray"
        case .refunded: return "purple"
        }
    }
}

// MARK: - Payment Status Enum
enum PaymentStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case requiresCapture = "requires_capture"
    case captured = "captured"
    case succeeded = "succeeded"
    case released = "released"
    case failed = "failed"
    case refunded = "refunded"
    
    var displayName: String {
        switch self {
        case .pending: return "Payment Pending"
        case .requiresCapture: return "Payment Ready"
        case .captured: return "Payment Captured"
        case .succeeded: return "Payment Succeeded"
        case .released: return "Payment Released"
        case .failed: return "Payment Failed"
        case .refunded: return "Payment Refunded"
        }
    }
    
    var isActive: Bool {
        switch self {
        case .pending, .requiresCapture, .captured, .succeeded:
            return true
        case .released, .failed, .refunded:
            return false
        }
    }
}

// MARK: - Payment Method Enum
enum PaymentMethod: String, Codable, CaseIterable {
    case wallet = "wallet"
    case card = "card"
    
    var displayName: String {
        switch self {
        case .wallet: return "Campus Wallet"
        case .card: return "Credit/Debit Card"
        }
    }
    
    var requiresEscrow: Bool {
        switch self {
        case .wallet, .card: return true
        }
    }
    
    var icon: String {
        switch self {
        case .wallet: return "creditcard.fill"
        case .card: return "creditcard"
        }
    }
    
    var color: Color {
        switch self {
        case .wallet: return .blue
        case .card: return .green
        }
    }
}

// MARK: - Order Model
struct Order: Codable, Identifiable {
    let id: UUID
    let listingId: UUID
    let buyerId: UUID
    let sellerId: UUID
    let priceCents: Int
    let paymentMethod: PaymentMethod
    let paymentStatus: PaymentStatus
    let orderStatus: OrderStatus
    let sellerConfirmedAt: Date?
    let inProgressAt: Date?
    let completedAt: Date?
    let cancelledAt: Date?
    let refundedAt: Date?
    let updatedAt: Date?
    let autoReleaseAt: Date?
    let createdAt: Date
    
    // Stripe Connect fields
    let stripeEscrowAccountId: String?
    let marketplaceFeeCents: Int
    let stripePaymentIntentId: String?
    
    // Time slot for slot-based services
    let timeSlotId: UUID?
    
    // Joined data
    var listing: Listing?
    
    // Computed properties
    var price: Double { Double(priceCents) / 100.0 }
    var formattedPrice: String { String(format: "$%.2f", price) }
    var isActive: Bool { orderStatus.isActive }
    var isFinal: Bool { orderStatus.isFinal }
    var requiresEscrow: Bool { paymentMethod.requiresEscrow }
    
    // Escrow-related computed properties
    var hasEscrowAccount: Bool { stripeEscrowAccountId != nil }
    var escrowStatus: String {
        if stripeEscrowAccountId == nil { return "No Escrow" }
        if orderStatus == .completed { return "Released" }
        if let autoReleaseAt = autoReleaseAt, autoReleaseAt <= Date() { return "Auto-Released" }
        return "Held in Escrow"
    }
    
    // Time-related computed properties
    var timeUntilAutoRelease: TimeInterval? {
        guard let autoReleaseAt = autoReleaseAt else { return nil }
        return autoReleaseAt.timeIntervalSinceNow
    }
    
    var autoReleaseFormatted: String? {
        guard let timeInterval = timeUntilAutoRelease, timeInterval > 0 else { return nil }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
    
    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case priceCents = "price_cents"
        case paymentMethod = "payment_method"
        case paymentStatus = "payment_status"
        case orderStatus = "order_status"
        case sellerConfirmedAt = "seller_confirmed_at"
        case inProgressAt = "in_progress_at"
        case completedAt = "completed_at"
        case cancelledAt = "cancelled_at"
        case refundedAt = "refunded_at"
        case updatedAt = "updated_at"
        case autoReleaseAt = "auto_release_at"
        case createdAt = "created_at"
        case stripeEscrowAccountId = "stripe_escrow_account_id"
        case marketplaceFeeCents = "marketplace_fee_cents"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case timeSlotId = "time_slot_id"
        case listing
    }
}

// MARK: - Order with Related Data
struct OrderWithDetails: Codable, Identifiable {
    let order: Order
    let listing: Listing
    let buyer: UserProfile
    let seller: UserProfile
    
    var id: UUID { order.id }
    
    // MARK: - Sample Data for Previews
    static let sampleOrder = OrderWithDetails(
        order: Order(
            id: UUID(),
            listingId: UUID(),
            buyerId: UUID(),
            sellerId: UUID(),
            priceCents: 2500,
            paymentMethod: .wallet,
            paymentStatus: .requiresCapture,
            orderStatus: .sellerConfirmed,
            sellerConfirmedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60), // 1 day ago
            inProgressAt: nil,
            completedAt: nil,
            cancelledAt: nil,
            refundedAt: nil,
            updatedAt: Date().addingTimeInterval(-1 * 24 * 60 * 60), // 1 day ago
            autoReleaseAt: Date().addingTimeInterval(7 * 24 * 60 * 60), // 7 days from now
            createdAt: Date().addingTimeInterval(-2 * 24 * 60 * 60), // 2 days ago
            stripeEscrowAccountId: "escrow_sample_123",
            marketplaceFeeCents: 0,
            stripePaymentIntentId: "pi_sample_123",
            timeSlotId: nil,
            listing: nil
        ),
        listing: Listing.sampleListing,
        buyer: UserProfile.sampleProfile,
        seller: UserProfile.sampleProfile
    )
}

// MARK: - Order Create Model
struct OrderCreate: Codable {
    let listingId: UUID
    let buyerId: UUID
    let sellerId: UUID
    let priceCents: Int
    let paymentMethod: PaymentMethod
    let timeSlotId: UUID? // For slot-based services
    
    enum CodingKeys: String, CodingKey {
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case priceCents = "price_cents"
        case paymentMethod = "payment_method"
        case timeSlotId = "time_slot_id"
    }
}

// MARK: - Order Insert (for database operations)
struct OrderInsert: Codable {
    let listingId: UUID
    let buyerId: UUID
    let sellerId: UUID
    let priceCents: Int
    let paymentMethod: String
    let orderStatus: String
    let paymentStatus: String
    let createdAt: String
    let updatedAt: String
    let stripeEscrowAccountId: String?
    let marketplaceFeeCents: Int
    let stripePaymentIntentId: String?
    let timeSlotId: UUID?
    
    enum CodingKeys: String, CodingKey {
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case priceCents = "price_cents"
        case paymentMethod = "payment_method"
        case orderStatus = "order_status"
        case paymentStatus = "payment_status"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case stripeEscrowAccountId = "stripe_escrow_account_id"
        case marketplaceFeeCents = "marketplace_fee_cents"
        case stripePaymentIntentId = "stripe_payment_intent_id"
        case timeSlotId = "time_slot_id"
    }
}

// MARK: - Order Update Models
struct OrderStatusUpdate: Codable {
    let orderId: UUID
    let newStatus: OrderStatus
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case newStatus = "new_status"
    }
}

struct PaymentStatusUpdate: Codable {
    let orderId: UUID
    let newStatus: PaymentStatus
    
    enum CodingKeys: String, CodingKey {
        case orderId = "order_id"
        case newStatus = "new_status"
    }
}

// MARK: - Order Filters
struct OrderFilters {
    var status: OrderStatus?
    var paymentMethod: PaymentMethod?
    var isActive: Bool?
    var dateRange: ClosedRange<Date>?
    
    static var all: OrderFilters { OrderFilters() }
    static var active: OrderFilters { OrderFilters(isActive: true) }
    static var completed: OrderFilters { OrderFilters(status: .completed) }
    static var disputed: OrderFilters { OrderFilters(status: .disputed) }
}

// MARK: - Order Statistics
struct OrderStats {
    let totalOrders: Int
    let activeOrders: Int
    let completedOrders: Int
    let disputedOrders: Int
    let totalValue: Double
    let averageOrderValue: Double
    
    var completionRate: Double {
        guard totalOrders > 0 else { return 0.0 }
        return Double(completedOrders) / Double(totalOrders)
    }
    
    var disputeRate: Double {
        guard totalOrders > 0 else { return 0.0 }
        return Double(disputedOrders) / Double(totalOrders)
    }
}
