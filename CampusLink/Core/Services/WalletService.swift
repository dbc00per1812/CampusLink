import Foundation
import Supabase

// MARK: - Wallet Service
final class WalletService {
    static let shared = WalletService()
    private init() {}
    
    // Fetch the current user's wallet balance
    func fetchBalance() async throws -> Wallet {
        let session = try await supabase.auth.session
        let userId: UUID = session.user.id
        
        let wallet: Wallet = try await supabase
            .from("wallets")
            .select()
            .eq("user_id", value: userId)
            .single()
            .execute()
            .value
        
        return wallet
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
        let session = try await supabase.auth.session
        let userId = session.user.id.uuidString
        
        let transactions: [PaymentTransaction] = try await supabase
            .from("payments")
            .select()
            .or("buyer_id.eq.\(userId),seller_id.eq.\(userId)")
            .order("created_at", ascending: false)
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
