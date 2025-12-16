import Foundation
import SwiftUI

// MARK: - Pending Transaction Type
enum PendingTransactionType: String {
    case offer
    case order
    case payout
    
    var displayName: String {
        switch self {
        case .offer: return "Offer"
        case .order: return "Order"
        case .payout: return "Payout"
        }
    }
    
    var icon: String {
        switch self {
        case .offer: return "hand.raised.fill"
        case .order: return "cart.fill"
        case .payout: return "banknote.fill"
        }
    }
    
    var tagColor: Color {
        switch self {
        case .offer: return .purple
        case .order: return .blue
        case .payout: return .green
        }
    }
}

// MARK: - Pending Transaction Model
struct PendingTransaction: Identifiable {
    let id: UUID
    let type: PendingTransactionType
    let title: String
    let amount: String
    let status: String
    let statusColor: Color
    let createdAt: Date
    let fromUser: String?
    let toUser: String?
    
    // Associated data (only one will be non-nil)
    let offer: Offer?
    let order: Order?
    let payout: Payout?
    
    // Computed properties
    var typeTag: String { type.displayName }
    var typeIcon: String { type.icon }
    var typeColor: Color { type.tagColor }
    
    // MARK: - Factory Methods
    
    /// Create a pending transaction from an offer
    static func fromOffer(_ offer: Offer) -> PendingTransaction {
        // Determine the user relationship
        let fromUser = offer.listingType == .seek ? "Seller" : "Buyer"
        
        return PendingTransaction(
            id: offer.id,
            type: .offer,
            title: offer.listingType == .seek ? "Seek Offer" : "Buyer Offer",
            amount: offer.formattedPrice ?? "$0.00",
            status: offer.status.capitalized,
            statusColor: getOfferStatusColor(offer.status),
            createdAt: offer.createdAt,
            fromUser: fromUser,
            toUser: nil,
            offer: offer,
            order: nil,
            payout: nil
        )
    }
    
    /// Create a pending transaction from an order
    static func fromOrder(_ order: Order, currentUserId: UUID?) -> PendingTransaction {
        // Determine user relationship
        var fromUser: String? = nil
        var toUser: String? = nil
        
        if let currentUserId = currentUserId {
            if order.buyerId == currentUserId {
                fromUser = "You (Buyer)"
                toUser = "Seller"
            } else if order.sellerId == currentUserId {
                fromUser = "Buyer"
                toUser = "You (Seller)"
            }
        }
        
        return PendingTransaction(
            id: order.id,
            type: .order,
            title: order.listing?.title ?? "Order",
            amount: order.formattedPrice,
            status: order.orderStatus.displayName,
            statusColor: order.orderStatus.badgeColor,
            createdAt: order.createdAt,
            fromUser: fromUser,
            toUser: toUser,
            offer: nil,
            order: order,
            payout: nil
        )
    }
    
    /// Create a pending transaction from a payout
    static func fromPayout(_ payout: Payout) -> PendingTransaction {
        return PendingTransaction(
            id: payout.id,
            type: .payout,
            title: "Payout Request",
            amount: payout.formattedAmount,
            status: payout.status.displayName,
            statusColor: getPayoutStatusColor(payout.status),
            createdAt: payout.createdAt,
            fromUser: nil,
            toUser: nil,
            offer: nil,
            order: nil,
            payout: payout
        )
    }
    
    // MARK: - Helper Methods
    
    private static func getOfferStatusColor(_ status: String) -> Color {
        switch status.lowercased() {
        case "pending": return .orange
        case "accepted": return .green
        case "declined", "withdrawn", "expired": return .red
        default: return .gray
        }
    }
    
    private static func getPayoutStatusColor(_ status: PayoutStatus) -> Color {
        switch status {
        case .pending, .processing, .inTransit: return .orange
        case .completed, .paid: return .green
        case .failed, .cancelled: return .red
        }
    }
}

// MARK: - Pending Transaction Sort Options
enum PendingTransactionSort {
    case dateNewest
    case dateOldest
    case amountHighest
    case amountLowest
    case type
    
    var displayName: String {
        switch self {
        case .dateNewest: return "Newest First"
        case .dateOldest: return "Oldest First"
        case .amountHighest: return "Highest Amount"
        case .amountLowest: return "Lowest Amount"
        case .type: return "By Type"
        }
    }
}

