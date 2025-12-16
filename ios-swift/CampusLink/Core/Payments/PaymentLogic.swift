import Foundation

/// Pure helper functions for payments UI/business rules used in Phase 6.
enum PaymentLogic {
    /// Whether the buyer can confirm receipt and trigger capture.
    static func canBuyerConfirm(transaction: PaymentTransaction, isBuyer: Bool) -> Bool {
        guard isBuyer else { return false }
        if transaction.isDisputed { return false }
        return transaction.status.lowercased() == "requires_capture"
    }

    /// Human-friendly display for a Stripe/Supabase status value.
    static func statusLabel(for status: String) -> String {
        status.replacingOccurrences(of: "_", with: " ").capitalized
    }
}


