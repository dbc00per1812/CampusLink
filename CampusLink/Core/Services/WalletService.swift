import Foundation
import Supabase

// MARK: - Wallet Service
final class WalletService {
    static let shared = WalletService()
    private init() {}
    
    // Fetch the current user's wallet balance
    func fetchBalance() async throws -> Wallet {
        // We assume the wallets row is keyed by the current user's UUID
        let session = try await supabase.auth.session
        guard let userId = session.user.id.uuid else {
            throw WalletServiceError.missingUserId
        }
        
        let wallet: Wallet = try await supabase
            .from("wallets")
            .select()
            .eq("user_id", userId)
            .single()
            .execute()
            .value
        
        return wallet
    }
    
    // Request a payout to the seller's connected account via Edge Function
    func requestPayout(amountCents: Int) async throws -> Payout {
        let payload: [String: AnyEncodable] = [
            "amount_cents": AnyEncodable(amountCents)
        ]
        
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
        let session = try await supabase.auth.session
        let userId = session.user.id.uuid?.uuidString ?? ""
        
        let transactions: [PaymentTransaction] = try await supabase
            .from("payments")
            .select()
            .or("buyer_id.eq.\(userId),seller_id.eq.\(userId)")
            .order(column: "created_at", ascending: false)
            .limit(limit)
            .execute()
            .value
        
        return transactions
    }
}

// MARK: - Errors
enum WalletServiceError: Error {
    case missingUserId
}
