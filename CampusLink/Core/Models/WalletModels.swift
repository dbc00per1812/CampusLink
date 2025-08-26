import Foundation

// MARK: - Wallet Model
struct Wallet: Codable, Identifiable {
    // Database columns
    let userId: UUID
    let availableCents: Int
    let escrowCents: Int
    let updatedAt: Date
    
    // Identifiable: use userId as id
    var id: UUID { userId }
    
    // Computed properties for display
    var availableBalance: Double { Double(availableCents) / 100.0 }
    var escrowBalance: Double { Double(escrowCents) / 100.0 }
    var totalBalance: Double { availableBalance + escrowBalance }
    
    var formattedAvailableBalance: String { String(format: "$%.2f", availableBalance) }
    var formattedEscrowBalance: String { String(format: "$%.2f", escrowBalance) }
    var formattedTotalBalance: String { String(format: "$%.2f", totalBalance) }
    
    var hasAvailableBalance: Bool { availableCents > 0 }
    var hasEscrowBalance: Bool { escrowCents > 0 }
    
    enum CodingKeys: String, CodingKey {
        case userId = "user_id"
        case availableCents = "available_cents"
        case escrowCents = "escrow_cents"
        case updatedAt = "updated_at"
    }
}

// MARK: - Payout Model
struct Payout: Codable, Identifiable {
    let id: UUID
    let sellerId: UUID
    let amountCents: Int
    let destination: String
    let status: PayoutStatus
    let stripeTransferId: String?
    let errorMessage: String?
    let retryCount: Int?
    let createdAt: Date
    let updatedAt: Date?
    let paidAt: Date?
    
    // Computed properties
    var amount: Double { Double(amountCents) / 100.0 }
    var formattedAmount: String { String(format: "$%.2f", amount) }
    var isPending: Bool { status == .pending }
    var isCompleted: Bool { status == .completed || status == .paid }
    var isFailed: Bool { status == .failed || status == .cancelled }
    var canRetry: Bool { isFailed && (retryCount ?? 0) < 3 }
    
    enum CodingKeys: String, CodingKey {
        case id
        case sellerId = "seller_id"
        case amountCents = "amount_cents"
        case destination
        case status
        case stripeTransferId = "stripe_transfer_id"
        case errorMessage = "error_message"
        case retryCount = "retry_count"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case paidAt = "paid_at"
    }
}

// MARK: - Payout Status Enum
enum PayoutStatus: String, Codable, CaseIterable {
    case pending = "pending"
    case processing = "processing"
    case inTransit = "in_transit"
    case completed = "completed"
    case paid = "paid"
    case failed = "failed"
    case cancelled = "cancelled"
    
    var displayName: String {
        switch self {
        case .pending: return "Pending"
        case .processing: return "Processing"
        case .inTransit: return "In Transit"
        case .completed: return "Completed"
        case .paid: return "Paid"
        case .failed: return "Failed"
        case .cancelled: return "Cancelled"
        }
    }
    
    var icon: String {
        switch self {
        case .pending: return "clock"
        case .processing: return "arrow.triangle.2.circlepath"
        case .inTransit: return "arrow.right.circle"
        case .completed, .paid: return "checkmark.circle.fill"
        case .failed: return "xmark.circle.fill"
        case .cancelled: return "slash.circle"
        }
    }
    
    var color: String {
        switch self {
        case .pending, .processing, .inTransit: return "orange"
        case .completed, .paid: return "green"
        case .failed, .cancelled: return "red"
        }
    }
}

// MARK: - Wallet Transaction (for transaction history)
struct WalletTransaction: Codable, Identifiable {
    let id: UUID
    let userId: UUID
    let type: TransactionType
    let amountCents: Int
    let balanceAfterCents: Int
    let description: String
    let relatedId: UUID?
    let createdAt: Date
    
    var amount: Double { Double(amountCents) / 100.0 }
    var balanceAfter: Double { Double(balanceAfterCents) / 100.0 }
    var formattedAmount: String {
        let prefix = type.isCredit ? "+" : "-"
        return "\(prefix)\(String(format: "$%.2f", abs(amount)))"
    }
    var formattedBalance: String { String(format: "$%.2f", balanceAfter) }
    
    enum CodingKeys: String, CodingKey {
        case id
        case userId = "user_id"
        case type
        case amountCents = "amount_cents"
        case balanceAfterCents = "balance_after_cents"
        case description
        case relatedId = "related_id"
        case createdAt = "created_at"
    }
}

// MARK: - Transaction Type Enum
enum TransactionType: String, Codable, CaseIterable {
    case orderPayment = "order_payment"
    case escrowRelease = "escrow_release"
    case payout = "payout"
    case refund = "refund"
    case fee = "fee"
    case adjustment = "adjustment"
    
    var displayName: String {
        switch self {
        case .orderPayment: return "Order Payment"
        case .escrowRelease: return "Escrow Released"
        case .payout: return "Withdrawal"
        case .refund: return "Refund"
        case .fee: return "Platform Fee"
        case .adjustment: return "Adjustment"
        }
    }
    
    var isCredit: Bool {
        switch self {
        case .escrowRelease, .refund, .adjustment: return true
        case .orderPayment, .payout, .fee: return false
        }
    }
    
    var icon: String {
        switch self {
        case .orderPayment: return "cart.fill"
        case .escrowRelease: return "lock.open"
        case .payout: return "banknote"
        case .refund: return "arrow.uturn.left.circle"
        case .fee: return "percent"
        case .adjustment: return "slider.horizontal.3"
        }
    }
}

// MARK: - Payout Request Model
struct PayoutRequest: Codable {
    let amountCents: Int
    let destination: PayoutDestination
    
    var amount: Double { Double(amountCents) / 100.0 }
    
    enum CodingKeys: String, CodingKey {
        case amountCents = "amount_cents"
        case destination
    }
}

// MARK: - Payout Destination Enum
enum PayoutDestination: String, Codable {
    case stripeConnect = "stripe_connect"
    case bankAccount = "bank_account"
    case venmo = "venmo"
    
    var displayName: String {
        switch self {
        case .stripeConnect: return "Bank Account (via Stripe)"
        case .bankAccount: return "Bank Account"
        case .venmo: return "Venmo"
        }
    }
    
    var requiresOnboarding: Bool { self == .stripeConnect }
}

