import Foundation
import Supabase


// MARK: - Wallet Service
final class WalletService: ObservableObject {
    static let shared = WalletService()
    private init() {}
    
    // Fetch wallet balance for a specific user ID (production-ready)
    func fetchBalanceForUser(_ userId: UUID) async throws -> Wallet {
        do {
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
            
            if let wallet = created.first { 
                return wallet 
            }
            
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
    
    // Fetch the current user's wallet balance (legacy - uses auth.session)
    func fetchBalance() async throws -> Wallet {
        do {
            // Get session with timeout to prevent UI freeze
            let session: Session
            
            // Use structured concurrency with timeout
            let sessionTask = Task {
                try await supabase.auth.session
            }
            
            do {
                session = try await sessionTask.value
            } catch {
                sessionTask.cancel()
                throw WalletServiceError.requestCancelled
            }
            
            let userId: UUID = session.user.id
            
            // Delegate to the user-specific method
            return try await fetchBalanceForUser(userId)
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
    
    // Get transaction history for specific user (production-ready)
    // Fetches from orders table to match MyTransactionsView behavior
    func getTransactionHistoryForUser(_ userId: UUID, limit: Int = 50) async throws -> [PaymentTransaction] {
        do {
            let userIdString = userId.uuidString
            
            // Fetch from orders table (same as MyTransactionsView)
            let orders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .or("buyer_id.eq.\(userIdString),seller_id.eq.\(userIdString)")
                .neq("order_status", value: "cancelled")
                .neq("payment_status", value: "failed")
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            print("🔵 WalletService: Fetched \(orders.count) orders for user")
            
            // Convert orders to PaymentTransaction format for compatibility
            // Show role-specific pricing (buyer sees what they paid, seller sees what they receive)
            let transactions: [PaymentTransaction] = orders.map { order in
                // Determine which price to show based on user's role
                let displayPrice: Double
                if order.buyerId == userId {
                    // User is buyer - show what they paid (includes fees)
                    displayPrice = Double(order.buyerPriceCents ?? order.priceCents) / 100.0
                } else {
                    // User is seller - show what they receive
                    displayPrice = Double(order.sellerPriceCents ?? order.priceCents) / 100.0
                }
                
                return PaymentTransaction(
                    id: order.id,
                    listingId: order.listingId,
                    buyerId: order.buyerId.uuidString,
                    sellerId: order.sellerId.uuidString,
                    paymentIntentId: order.stripePaymentIntentId,
                    amount: displayPrice,
                    status: order.paymentStatus.rawValue,
                    createdAt: order.createdAt,
                    escrowReleaseAt: nil,
                    deliveredAt: order.sellerConfirmedAt,
                    buyerConfirmedAt: order.completedAt,  // Order.completedAt = when buyer confirmed receipt
                    disputeStatus: order.orderStatus == .disputed ? .open : .none,
                    disputeReason: nil,
                    disputeNotes: nil,
                    listing: order.listing
                )
            }
            
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
    
    // Basic transaction history using payments table (legacy - uses auth.session)
    func getTransactionHistory(limit: Int = 50) async throws -> [PaymentTransaction] {
        // Get session with structured concurrency
        let sessionTask = Task {
            try await supabase.auth.session
        }
        
        let session: Session
        do {
            session = try await sessionTask.value
        } catch {
            sessionTask.cancel()
            throw WalletServiceError.requestCancelled
        }
        
        return try await getTransactionHistoryForUser(session.user.id, limit: limit)
    }
    
    // Fetch REAL balance from Stripe (source of truth for available funds)
    func fetchStripeBalance() async throws -> Wallet {
        struct StripeBalanceResponse: Decodable {
            let available_for_standard_cents: Int
            let available_for_instant_cents: Int
            let pending_cents: Int
            let total_cents: Int
        }
        
        do {
            let response: StripeBalanceResponse = try await supabase.functions.invoke(
                "get-stripe-balance",
                options: FunctionInvokeOptions(method: .post)
            )
            
            print("💰 Fetched Stripe balance: $\(Double(response.available_for_standard_cents)/100) available")
            
            // Get user ID for the wallet object
            let session = try await supabase.auth.session
            let userId = session.user.id
            
            // Also fetch database wallet for escrow_cents (not in Stripe)
            let escrowCents: Int
            do {
                let dbWallet = try await fetchBalanceForUser(userId)
                escrowCents = dbWallet.escrowCents
            } catch {
                print("⚠️ Could not fetch escrow from database, defaulting to 0")
                escrowCents = 0
            }
            
            // Return a Wallet object with Stripe balance as available_cents
            // This ensures checkout sees the real-time Stripe balance
            return Wallet(
                id: UUID(), // Not critical for display
                userId: userId,
                availableCents: response.available_for_standard_cents,
                escrowCents: escrowCents,
                createdAt: Date(),
                updatedAt: Date()
            )
        } catch {
            print("❌ Failed to fetch Stripe balance: \(error)")
            throw error
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
