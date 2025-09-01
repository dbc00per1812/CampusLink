import Foundation
import Supabase

/// Service for managing Stripe Connect payout operations
/// Handles standard and instant payouts, status tracking, and payout method management
final class PayoutService: ObservableObject {
    static let shared = PayoutService()
    private init() {}
    
    // MARK: - Payout Types
    
    enum PayoutType: String, CaseIterable {
        case standard = "standard"
        case instant = "instant"
        
        var displayName: String {
            switch self {
            case .standard:
                return "Standard (2-3 days)"
            case .instant:
                return "Instant (minutes)"
            }
        }
        
        var description: String {
            switch self {
            case .standard:
                return "Free standard payout to your bank account"
            case .instant:
                return "Quick payout to debit card with 1.5% fee"
            }
        }
        
        var processingTime: String {
            switch self {
            case .standard:
                return "2-3 business days"
            case .instant:
                return "Within minutes"
            }
        }
        
        var feePercentage: Double {
            switch self {
            case .standard:
                return 0.0
            case .instant:
                return 0.015 // 1.5%
            }
        }
    }
    
    // MARK: - Payout Methods
    
    enum PayoutMethod: String, CaseIterable {
        case bankAccount = "bank_account"
        case debitCard = "debit_card"
        
        var displayName: String {
            switch self {
            case .bankAccount:
                return "Bank Account"
            case .debitCard:
                return "Debit Card"
            }
        }
        
        var description: String {
            switch self {
            case .bankAccount:
                return "Direct deposit to your bank account"
            case .debitCard:
                return "Instant transfer to your debit card"
            }
        }
        
        var icon: String {
            switch self {
            case .bankAccount:
                return "building.columns"
            case .debitCard:
                return "creditcard"
            }
        }
    }
    
    // MARK: - Payout Operations
    
    /// Requests a payout from the seller's Campus Wallet to their external account
    /// - Parameters:
    ///   - amountCents: Amount to payout in cents
    ///   - payoutType: Standard or instant payout
    ///   - payoutMethod: Bank account or debit card
    ///   - accountId: Stripe Connect account ID for the seller
    /// - Returns: Payout record
    func requestPayout(
        amountCents: Int,
        payoutType: PayoutType,
        payoutMethod: PayoutMethod,
        accountId: String
    ) async throws -> Payout {
        do {
            // Verify seller has sufficient balance
            let wallet: Wallet = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: accountId)
                .single()
                .execute()
                .value
            
            guard wallet.availableCents >= amountCents else {
                throw PayoutServiceError.insufficientBalance
            }
            
            // Calculate fees
            let feeCents = Int(Double(amountCents) * payoutType.feePercentage)
            let netAmountCents = amountCents - feeCents
            
            // Create payout record
            let payoutData = PayoutInsert(
                userId: accountId,
                sellerId: accountId, // For now, user_id and seller_id are the same
                amountCents: amountCents,
                destination: payoutMethod.rawValue, // For now, use the payout method as destination
                feeCents: feeCents,
                netAmountCents: netAmountCents,
                payoutType: payoutType.rawValue,
                payoutMethod: payoutMethod.rawValue,
                status: "pending",
                stripeConnectAccountId: accountId,
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date())
            )
            
            let payout: Payout = try await supabase
                .from("payouts")
                .insert(payoutData)
                .select()
                .single()
                .execute()
                .value
            
            // Update wallet balance (reserve the amount)
            let _: Wallet = try await supabase
                .from("wallets")
                .update([
                    "available_cents": String(wallet.availableCents - amountCents),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("user_id", value: accountId)
                .select()
                .single()
                .execute()
                .value
            
            return payout
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Gets payout history for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Array of payout records
    func getPayoutHistory(for userId: String) async throws -> [Payout] {
        do {
            let payouts: [Payout] = try await supabase
                .from("payouts")
                .select()
                .eq("user_id", value: userId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            return payouts
        } catch {
            throw handleError(error)
        }
    }
    
    /// Gets payout statistics for a user
    /// - Parameter userId: The user's ID
    /// - Returns: Payout statistics
    func getPayoutStats(for userId: String) async throws -> PayoutStats {
        do {
            let payouts = try await getPayoutHistory(for: userId)
            
            let totalPayouts = payouts.count
            let totalAmount = payouts.reduce(0) { $0 + $1.amountCents }
            let totalFees = payouts.reduce(0) { $0 + $1.feeCents }
            let pendingPayouts = payouts.filter { $0.status == .pending }.count
            let completedPayouts = payouts.filter { $0.status == .completed }.count
            let failedPayouts = payouts.filter { $0.status == .failed }.count
            
            return PayoutStats(
                totalPayouts: totalPayouts,
                totalAmount: totalAmount,
                totalFees: totalFees,
                pendingPayouts: pendingPayouts,
                completedPayouts: completedPayouts,
                failedPayouts: failedPayouts
            )
        } catch {
            throw handleError(error)
        }
    }
    
    /// Cancels a pending payout
    /// - Parameter payoutId: The payout ID to cancel
    /// - Returns: Updated payout record
    func cancelPayout(_ payoutId: UUID) async throws -> Payout {
        do {
            let payout: Payout = try await supabase
                .from("payouts")
                .select()
                .eq("id", value: payoutId.uuidString)
                .single()
                .execute()
                .value
            
            guard payout.status == .pending else {
                throw PayoutServiceError.invalidPayoutStatus
            }
            
            // Update payout status
            let updatedPayout: Payout = try await supabase
                .from("payouts")
                .update([
                    "status": "cancelled",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: payoutId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            // Restore wallet balance
            let wallet: Wallet = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: payout.userId)
                .single()
                .execute()
                .value
            
            let _: Wallet = try await supabase
                .from("wallets")
                .update([
                    "available_cents": String(wallet.availableCents + payout.amountCents),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("user_id", value: payout.userId)
                .select()
                .single()
                .execute()
                .value
            
            return updatedPayout
            
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Helper Methods
    
    private func handleError(_ error: Error) -> Error {
        if error.localizedDescription.contains("insufficient") {
            return PayoutServiceError.insufficientBalance
        } else if error.localizedDescription.contains("unauthorized") {
            return PayoutServiceError.unauthorizedAction
        } else if error.localizedDescription.contains("not_found") {
            return PayoutServiceError.payoutNotFound
        } else {
            return error
        }
    }
}

// MARK: - Payout Stats Model

struct PayoutStats {
    let totalPayouts: Int
    let totalAmount: Int
    let totalFees: Int
    let pendingPayouts: Int
    let completedPayouts: Int
    let failedPayouts: Int
    
    var totalAmountFormatted: String {
        let amount = Double(totalAmount) / 100.0
        return String(format: "$%.2f", amount)
    }
    
    var totalFeesFormatted: String {
        let fees = Double(totalFees) / 100.0
        return String(format: "$%.2f", fees)
    }
    
    var successRate: Double {
        guard totalPayouts > 0 else { return 0.0 }
        return Double(completedPayouts) / Double(totalPayouts) * 100.0
    }
}

// MARK: - Errors

enum PayoutServiceError: LocalizedError {
    case insufficientBalance
    case unauthorizedAction
    case payoutNotFound
    case invalidPayoutStatus
    case networkError
    case requestCancelled
    case authenticationRequired
    
    var errorDescription: String? {
        switch self {
        case .insufficientBalance:
            return "Insufficient balance for payout"
        case .unauthorizedAction:
            return "Unauthorized action"
        case .payoutNotFound:
            return "Payout not found"
        case .invalidPayoutStatus:
            return "Invalid payout status for this action"
        case .networkError:
            return "Network error occurred"
        case .requestCancelled:
            return "Request was cancelled"
        case .authenticationRequired:
            return "Authentication required to request payout"
        }
    }
}
