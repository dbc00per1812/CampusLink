import Foundation
import Supabase

// MARK: - Timeout Helper
func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
    return try await withThrowingTaskGroup(of: T.self) { group in
        group.addTask {
            try await operation()
        }
        
        group.addTask {
            try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
            throw WalletServiceError.requestCancelled
        }
        
        let result = try await group.next()!
        group.cancelAll()
        return result
    }
}

// MARK: - Wallet Service
final class WalletService: ObservableObject {
    static let shared = WalletService()
    private init() {}
    
    // Fetch the current user's wallet balance
    func fetchBalance() async throws -> Wallet {
        do {
            // Add timeout to prevent infinite hang
            let session = try await withTimeout(seconds: 10) {
                try await supabase.auth.session
            }
            let userId: UUID = session.user.id
            
            // Fetch as array to gracefully handle 0 rows
            let rows: [Wallet] = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            
            if let wallet = rows.first {
                return wallet
            }
            
            // If no wallet row exists yet, create one and return
            try await createWalletIfMissing(for: userId)
            
            let created: [Wallet] = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: userId)
                .limit(1)
                .execute()
                .value
            if let wallet = created.first { return wallet }
            throw WalletServiceError.missingUserId
        } catch {
            // Re-throw with better context for debugging
            if error.localizedDescription.contains("cancelled") {
                throw WalletServiceError.requestCancelled
            } else if error.localizedDescription.contains("network") {
                throw WalletServiceError.networkError
            } else {
                throw error
            }
        }
    }
    
    private func createWalletIfMissing(for userId: UUID) async throws {
        // Attempt insert; if row exists, ignore error
        struct WalletInsert: Encodable { let user_id: UUID }
        _ = try? await supabase
            .from("wallets")
            .insert(WalletInsert(user_id: userId), returning: .minimal)
            .execute()
    }
    
    // Request a payout via Postgres RPC (preferred)
    func requestPayout(amountCents: Int) async throws -> Payout {
        let response: Payout = try await supabase
            .rpc(
                "request_payout",
                params: [
                    "amount_cents": amountCents
                ]
            )
            .execute()
            .value
        return response
    }
    
    // Fallback: directly process an existing payout by ID via Edge Function
    func processPayout(payoutId: UUID) async throws -> Payout {
        struct ProcessPayload: Encodable { let payout_id: String }
        let payload = ProcessPayload(payout_id: payoutId.uuidString)
        let response: Payout = try await supabase.functions.invoke(
            "process_payout",
            options: FunctionInvokeOptions(
                method: .post,
                body: payload
            )
        )
        return response
    }
    
    // Basic transaction history using payments table for now
    func getTransactionHistory(limit: Int = 50) async throws -> [PaymentTransaction] {
        do {
            // Add timeout to prevent infinite hang
            let session = try await withTimeout(seconds: 10) {
                try await supabase.auth.session
            }
            let userId = session.user.id.uuidString
            
            let transactions: [PaymentTransaction] = try await supabase
                .from("payments")
                .select()
                .or("buyer_id.eq.\(userId),seller_id.eq.\(userId)")
                .neq("status", value: "failed")
                .neq("status", value: "cancelled")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            return transactions
        } catch {
            if error.localizedDescription.contains("cancelled") {
                throw WalletServiceError.requestCancelled
            } else if error.localizedDescription.contains("network") {
                throw WalletServiceError.networkError
            } else {
                throw error
            }
        }
    }
}

// MARK: - Errors
enum WalletServiceError: Error, LocalizedError {
    case missingUserId
    case requestCancelled
    case networkError
    
    var errorDescription: String? {
        switch self {
        case .missingUserId:
            return "User ID not found"
        case .requestCancelled:
            return "Request was cancelled"
        case .networkError:
            return "Network connection error"
        }
    }
}
