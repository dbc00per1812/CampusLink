import Foundation

enum DisputeStatus: String, Codable {
    case none
    case open
    case under_review
    case resolved
    case refunded
}

/// Represents a payment/transaction record from the `payments` table.
struct PaymentTransaction: Codable, Identifiable {
    let id: UUID
    let listingId: UUID?
    let buyerId: String
    let sellerId: String
    let paymentIntentId: String?
    let amount: Double
    let status: String
    let createdAt: Date
    let escrowReleaseAt: Date?
    let deliveredAt: Date?
    let buyerConfirmedAt: Date?
    let disputeStatus: DisputeStatus?
    let disputeReason: String?
    let disputeNotes: String?

    // Joined data
    var listing: Listing?

    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case paymentIntentId = "payment_intent_id"
        case amount
        case status
        case createdAt = "created_at"
        case escrowReleaseAt = "escrow_release_at"
        case deliveredAt = "delivered_at"
        case buyerConfirmedAt = "buyer_confirmed_at"
        case disputeStatus = "dispute_status"
        case disputeReason = "dispute_reason"
        case disputeNotes = "dispute_notes"
        case listing
    }
}

extension PaymentTransaction {
    var isCompleted: Bool { status.lowercased() == "completed" || status.lowercased() == "succeeded" }
    var isDisputed: Bool { (disputeStatus ?? .none) != .none }
    // If amount stored in cents, pretty print dollars; else show as-is
    var formattedAmount: String {
        if amount > 1000 { // heuristic: treat as cents
            return String(format: "$%.2f", amount / 100.0)
        } else {
            return String(format: "$%.2f", amount)
        }
    }
}


