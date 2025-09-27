import Foundation
import Supabase

// MARK: - Order Service
final class OrderService: ObservableObject {
    static let shared = OrderService()
    private init() {}
    
    // MARK: - Order Creation
    func createOrder(_ orderCreate: OrderCreate) async throws -> Order {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Verify the current user is the buyer
            guard currentUserId == orderCreate.buyerId else {
                throw OrderServiceError.unauthorizedAction
            }
            
            // Get or create escrow account for seller
            let escrowService = EscrowService.shared
            let escrowAccountId = try await escrowService.getOrCreateEscrowAccount(for: orderCreate.sellerId)
            
            // Create order directly in the database with Stripe Connect fields
            let orderData = OrderInsert(
                listingId: orderCreate.listingId.uuidString,
                buyerId: orderCreate.buyerId.uuidString,
                sellerId: orderCreate.sellerId.uuidString,
                priceCents: orderCreate.priceCents,
                paymentMethod: orderCreate.paymentMethod.rawValue,
                orderStatus: "placed",
                paymentStatus: "succeeded",
                stripeEscrowAccountId: escrowAccountId,
                marketplaceFeeCents: 0,
                stripePaymentIntentId: nil,
                timeSlotId: orderCreate.timeSlotId?.uuidString
            )
            
            let order: Order = try await supabase
                .from("orders")
                .insert(orderData)
                .select()
                .single()
                .execute()
                .value
            
            return order
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Order Management
    func acceptOrder(_ orderId: UUID) async throws -> Order {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Verify the current user is the seller
            let order = try await getOrderDetails(orderId)
            guard currentUserId == order.sellerId else {
                throw OrderServiceError.unauthorizedAction
            }
            
            // Update order status to seller confirmed
            let updatedOrder: Order = try await supabase
                .from("orders")
                .update([
                    "order_status": "seller_confirmed",
                    "seller_confirmed_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            return updatedOrder
        } catch {
            throw handleError(error)
        }
    }
    
    func markDelivered(_ orderId: UUID) async throws -> Order {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Verify the current user is the seller
            let order = try await getOrderDetails(orderId)
            guard currentUserId == order.sellerId else {
                throw OrderServiceError.unauthorizedAction
            }
            
            // Verify order is in correct status for marking as delivered
            guard [.placed, .inProgress].contains(order.orderStatus) else {
                throw OrderServiceError.invalidOrderStatus("Cannot mark as delivered. Order status must be 'placed' or 'in progress', but current status is '\(order.orderStatus.displayName)'")
            }
            
            // Update order status to seller confirmed (ready for buyer confirmation)
            let updatedOrder: Order = try await supabase
                .from("orders")
                .update([
                    "order_status": "seller_confirmed",
                    "seller_confirmed_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            return updatedOrder
        } catch {
            throw handleError(error)
        }
    }
    
    func confirmDelivery(_ orderId: UUID) async throws -> Order {
        do {
            print("🔵 confirmDelivery: Starting for order \(orderId)")
            
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            print("🔵 confirmDelivery: Current user ID: \(currentUserId)")
            
            // Verify the current user is the buyer
            let order = try await getOrderDetails(orderId)
            print("🔵 confirmDelivery: Order details loaded, buyer ID: \(order.buyerId), current user: \(currentUserId)")
            print("🔵 confirmDelivery: Order price: $\(Double(order.priceCents)/100.0), Seller: \(order.sellerId)")
            
            guard currentUserId == order.buyerId else {
                print("❌ confirmDelivery: Unauthorized - current user is not the buyer")
                throw OrderServiceError.unauthorizedAction
            }
            
            // Verify order is in correct status for delivery confirmation
            guard order.orderStatus == .sellerConfirmed else {
                print("❌ confirmDelivery: Invalid order status - expected .sellerConfirmed, got \(order.orderStatus.displayName)")
                throw OrderServiceError.invalidOrderStatus("Cannot confirm delivery. Order status must be 'seller_confirmed', but current status is '\(order.orderStatus.displayName)'")
            }
            
            print("🔵 confirmDelivery: Order status verified, updating to completed")
            
            // Check seller's wallet BEFORE escrow release
            print("🔵 confirmDelivery: Checking seller wallet BEFORE escrow release...")
            do {
                let preWallet: [Wallet] = try await supabase
                    .from("wallets")
                    .select()
                    .eq("user_id", value: order.sellerId.uuidString)
                    .execute()
                    .value
                
                if let wallet = preWallet.first {
                    print("🔵 confirmDelivery: PRE-RELEASE - Seller wallet balance: \(wallet.availableCents) cents ($\(Double(wallet.availableCents)/100.0))")
                } else {
                    print("🔵 confirmDelivery: PRE-RELEASE - No wallet found for seller \(order.sellerId)")
                }
            } catch {
                print("❌ confirmDelivery: Failed to check pre-release wallet: \(error)")
            }
            
            // Update order status to completed
            let updatedOrder: Order = try await supabase
                .from("orders")
                .update([
                    "order_status": "completed",
                    "buyer_confirmed_at": ISO8601DateFormatter().string(from: Date()),
                    "completed_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            print("🔵 confirmDelivery: Order status updated successfully, releasing escrow funds")
            
            // Release funds from escrow to seller's wallet
            try await releaseEscrowFunds(order: order)
            
            print("🔵 confirmDelivery: Escrow funds released successfully")
            
            // Check seller's wallet AFTER escrow release
            print("🔵 confirmDelivery: Checking seller wallet AFTER escrow release...")
            do {
                let postWallet: [Wallet] = try await supabase
                    .from("wallets")
                    .select()
                    .eq("user_id", value: order.sellerId.uuidString)
                    .execute()
                    .value
                
                if let wallet = postWallet.first {
                    print("🔵 confirmDelivery: POST-RELEASE - Seller wallet balance: \(wallet.availableCents) cents ($\(Double(wallet.availableCents)/100.0))")
                } else {
                    print("🔵 confirmDelivery: POST-RELEASE - No wallet found for seller \(order.sellerId)")
                }
            } catch {
                print("❌ confirmDelivery: Failed to check post-release wallet: \(error)")
            }
            
            return updatedOrder
        } catch {
            print("❌ confirmDelivery: Error occurred: \(error)")
            print("❌ confirmDelivery: Error type: \(type(of: error))")
            print("❌ confirmDelivery: Error description: \(error.localizedDescription)")
            throw handleError(error)
        }
    }
    
    /// Releases funds from escrow to seller's wallet
    private func releaseEscrowFunds(order: Order) async throws {
        print("🔵 releaseEscrowFunds: Starting for order \(order.id)")
        
        // Test wallet access first
        print("🔵 releaseEscrowFunds: Testing wallet access...")
        let accessTestResult = try await testWalletAccess(userId: order.sellerId)
        print("🔵 releaseEscrowFunds: Wallet access test result: \(accessTestResult)")
        
        // First, ensure the seller exists in public.users table
        print("🔵 releaseEscrowFunds: Checking if seller exists in public.users...")
        let sellerUser: User
        do {
            sellerUser = try await supabase
                .from("users")
                .select()
                .eq("id", value: order.sellerId.uuidString)
                .single()
                .execute()
                .value
            
            print("🔵 releaseEscrowFunds: Seller found in public.users: \(sellerUser.name ?? "Unknown")")
        } catch {
            print("🔵 releaseEscrowFunds: Seller not found in public.users, attempting to create...")
            
            // Try to create the user record in public.users
            do {
                let newUser: User = try await supabase
                    .from("users")
                    .insert([
                        "id": order.sellerId.uuidString,
                        "created_at": ISO8601DateFormatter().string(from: Date())
                    ])
                    .select()
                    .single()
                    .execute()
                    .value
                
                sellerUser = newUser
                print("🔵 releaseEscrowFunds: Successfully created seller user in public.users")
            } catch {
                print("❌ releaseEscrowFunds: Failed to create seller user: \(error)")
                throw OrderServiceError.walletUpdateFailed("Failed to create seller user record: \(error.localizedDescription)")
            }
        }
        
        // Get or create the seller's wallet
        let sellerWallet: Wallet
        do {
            sellerWallet = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: order.sellerId.uuidString)
                .single()
                .execute()
                .value
            
            print("🔵 releaseEscrowFunds: Found existing seller wallet with \(sellerWallet.availableCents) cents")
        } catch {
            print("🔵 releaseEscrowFunds: No existing wallet found, creating new wallet for seller \(order.sellerId)")
            
            // Create a new wallet for the seller
            struct WalletInsert: Encodable {
                let user_id: String
                let available_cents: Int
                let escrow_cents: Int
                let updated_at: String
            }
            
            let insertData = WalletInsert(
                user_id: order.sellerId.uuidString,
                available_cents: 0,
                escrow_cents: 0,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            let newWallet: Wallet = try await supabase
                .from("wallets")
                .insert(insertData)
                .select()
                .single()
                .execute()
                .value
            
            sellerWallet = newWallet
            print("🔵 releaseEscrowFunds: Created new wallet with \(sellerWallet.availableCents) cents")
        }
        
        // Verify wallet has valid data
        guard sellerWallet.availableCents >= 0 else {
            print("❌ releaseEscrowFunds: Invalid wallet balance: \(sellerWallet.availableCents)")
            throw OrderServiceError.walletUpdateFailed("Invalid wallet balance for seller")
        }
        
        // Calculate net amount (after marketplace fees)
        let netAmountCents = order.priceCents - order.marketplaceFeeCents
        print("🔵 releaseEscrowFunds: Order price: \(order.priceCents), marketplace fee: \(order.marketplaceFeeCents), net amount: \(netAmountCents)")
        print("🔵 releaseEscrowFunds: Current wallet balance: \(sellerWallet.availableCents)")
        print("🔵 releaseEscrowFunds: Expected new balance: \(sellerWallet.availableCents + netAmountCents)")
        
        // Verify the calculation is valid
        guard netAmountCents > 0 else {
            print("❌ releaseEscrowFunds: Invalid net amount calculation: \(netAmountCents)")
            throw OrderServiceError.walletUpdateFailed("Invalid payment amount calculation")
        }
        
        // Update seller's wallet balance
        do {
            struct WalletUpdate: Encodable {
                let available_cents: Int
                let updated_at: String
            }
            
            let updateData = WalletUpdate(
                available_cents: sellerWallet.availableCents + netAmountCents,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            print("🔵 releaseEscrowFunds: Attempting wallet update with data: \(updateData)")
            
            let updateResult = try await supabase
                .from("wallets")
                .update(updateData)
                .eq("user_id", value: order.sellerId.uuidString)
                .execute()
            
            print("🔵 releaseEscrowFunds: Update result: \(updateResult)")
            
            // Check if the update actually affected any rows
            if updateResult.count == 0 {
                print("❌ releaseEscrowFunds: No wallet rows were updated for seller \(order.sellerId)")
                throw OrderServiceError.walletUpdateFailed("No wallet found for seller \(order.sellerId)")
            }
            
            print("🔵 releaseEscrowFunds: Successfully updated seller wallet (affected \(updateResult.count) rows)")
        } catch {
            print("❌ releaseEscrowFunds: Failed to update seller wallet: \(error)")
            throw error
        }
        
        // Create a transaction record for the escrow release (optional - table may not exist)
        do {
            let transactionData = TransactionInsert(
                userId: order.sellerId.uuidString,
                type: "escrow_release",
                amountCents: netAmountCents,
                balanceAfterCents: sellerWallet.availableCents + netAmountCents,
                description: "Escrow funds released from order #\(order.id.uuidString.prefix(8))",
                relatedId: order.id.uuidString,
                createdAt: ISO8601DateFormatter().string(from: Date())
            )
            
            let _: WalletTransaction = try await supabase
                .from("wallet_transactions")
                .insert(transactionData)
                .select()
                .single()
                .execute()
                .value
            
            print("🔵 releaseEscrowFunds: Successfully created transaction record")
        } catch {
            print("⚠️ releaseEscrowFunds: Transaction logging failed (table may not exist): \(error)")
            print("🔵 releaseEscrowFunds: This is non-critical - continuing with wallet update")
            // Don't throw here - the wallet update succeeded, this is just logging
        }
        
        // Verify the wallet update actually took effect
        do {
            let verifyWallet: Wallet = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: order.sellerId.uuidString)
                .single()
                .execute()
                .value
            
            let expectedBalance = sellerWallet.availableCents + netAmountCents
            print("🔵 releaseEscrowFunds: Wallet verification - Expected: \(expectedBalance), Actual: \(verifyWallet.availableCents)")
            
            if verifyWallet.availableCents != expectedBalance {
                print("❌ releaseEscrowFunds: Wallet balance mismatch! Expected \(expectedBalance) but got \(verifyWallet.availableCents)")
                throw OrderServiceError.walletUpdateFailed("Wallet balance verification failed - expected \(expectedBalance) but got \(verifyWallet.availableCents)")
            }
            
            print("✅ releaseEscrowFunds: Wallet balance verified successfully")
            
            // Additional verification - let's also check if we can read the wallet from a different query
            print("🔵 releaseEscrowFunds: Performing additional wallet verification...")
            let finalCheck: [Wallet] = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: order.sellerId.uuidString)
                .execute()
                .value
            
            if let finalWallet = finalCheck.first {
                print("🔵 releaseEscrowFunds: Final wallet check - balance: \(finalWallet.availableCents)")
            } else {
                print("❌ releaseEscrowFunds: Final wallet check failed - no wallet found")
            }
        } catch {
            print("❌ releaseEscrowFunds: Failed to verify wallet update: \(error)")
            throw OrderServiceError.walletUpdateFailed("Failed to verify wallet update: \(error.localizedDescription)")
        }
    }
    
    func openDispute(_ orderId: UUID, reason: String, evidence: String?) async throws -> Order {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Verify the current user is involved in the order
            let order = try await getOrderDetails(orderId)
            guard currentUserId == order.buyerId || currentUserId == order.sellerId else {
                throw OrderServiceError.unauthorizedAction
            }
            
            // Open dispute via RPC
            let updatedOrder: Order = try await supabase
                .rpc(
                    "open_dispute",
                    params: [
                        "p_order_id": orderId.uuidString,
                        "p_reason": reason,
                        "p_evidence": evidence ?? ""
                    ]
                )
                .execute()
                .value
            
            return updatedOrder
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Order Retrieval
    func getOrderDetails(_ orderId: UUID) async throws -> Order {
        do {
            let order: Order = try await supabase
                .from("orders")
                .select()
                .eq("id", value: orderId)
                .limit(1)
                .single()
                .execute()
                .value
            
            return order
        } catch {
            throw handleError(error)
        }
    }
    
    func getUserOrders(userId: UUID? = nil, status: OrderStatus? = nil, limit: Int = 50) async throws -> [Order] {
        do {
            let session = try await supabase.auth.session
            let currentUserId = userId ?? session.user.id
            
            var query = supabase
                .from("orders")
                .select()
                .or("buyer_id.eq.\(currentUserId.uuidString),seller_id.eq.\(currentUserId.uuidString)")
            
            if let status = status {
                query = query.eq("order_status", value: status.rawValue)
            }
            
            let orders: [Order] = try await query
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            return orders
        } catch {
            throw handleError(error)
        }
    }
    
    func getBuyerOrders(buyerId: UUID? = nil, limit: Int = 50) async throws -> [Order] {
        do {
            let session = try await supabase.auth.session
            let currentUserId = buyerId ?? session.user.id
            
            let orders: [Order] = try await supabase
                .from("orders")
                .select()
                .eq("buyer_id", value: currentUserId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            return orders
        } catch {
            throw handleError(error)
        }
    }
    
    func getSellerOrders(sellerId: UUID? = nil, limit: Int = 50) async throws -> [Order] {
        do {
            let session = try await supabase.auth.session
            let currentUserId = sellerId ?? session.user.id
            
            let orders: [Order] = try await supabase
                .from("orders")
                .select()
                .eq("seller_id", value: currentUserId)
                .order("created_at", ascending: false)
                .limit(limit)
                .execute()
                .value
            
            return orders
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Order Statistics
    func getOrderStats(userId: UUID? = nil) async throws -> OrderStats {
        do {
            let session = try await supabase.auth.session
            let currentUserId = userId ?? session.user.id
            
            // Get all user orders to calculate stats
            let allOrders = try await getUserOrders(userId: currentUserId)
            
            // Calculate statistics
            let totalOrders = allOrders.count
            let completedOrders = allOrders.filter { $0.orderStatus == .completed }.count
            let activeOrders = allOrders.filter { 
                [.placed, .sellerConfirmed, .inProgress].contains($0.orderStatus) 
            }.count
            let disputedOrders = allOrders.filter { $0.orderStatus == .disputed }.count
            let _ = allOrders.filter { $0.orderStatus == .cancelled }.count
            
            let totalValue = allOrders.reduce(0) { $0 + $1.priceCents }
            
            let averageOrderValue = totalOrders > 0 ? Double(totalValue) / Double(totalOrders) : 0.0
            
            return OrderStats(
                totalOrders: totalOrders,
                activeOrders: activeOrders,
                completedOrders: completedOrders,
                disputedOrders: disputedOrders,
                totalValue: Double(totalValue) / 100.0, // Convert cents to dollars
                averageOrderValue: averageOrderValue / 100.0 // Convert cents to dollars
            )
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Order Updates
    func updateOrderStatus(_ orderId: UUID, status: OrderStatus) async throws -> Order {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Verify the current user is involved in the order
            let order = try await getOrderDetails(orderId)
            guard currentUserId == order.buyerId || currentUserId == order.sellerId else {
                throw OrderServiceError.unauthorizedAction
            }
            
            // Update status via RPC for proper validation
            let updatedOrder: Order = try await supabase
                .rpc(
                    "update_order_status",
                    params: [
                        "p_order_id": orderId.uuidString,
                        "p_status": status.rawValue
                    ]
                )
                .execute()
                .value
            
            return updatedOrder
        } catch {
            throw handleError(error)
        }
    }
    
    /// Updates an order with Stripe payment intent information
    /// - Parameters:
    ///   - orderId: The order ID to update
    ///   - paymentIntentId: The Stripe payment intent ID
    func updateOrderWithPaymentIntent(_ orderId: UUID, paymentIntentId: String) async throws -> Order {
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Verify the current user is involved in the order
            let order = try await getOrderDetails(orderId)
            guard currentUserId == order.buyerId || currentUserId == order.sellerId else {
                throw OrderServiceError.unauthorizedAction
            }
            
            // Update order with payment intent ID and set auto-release time
            let escrowService = EscrowService.shared
            try await escrowService.updateOrderWithEscrow(
                orderId: orderId,
                escrowAccountId: order.stripeEscrowAccountId ?? "",
                paymentIntentId: paymentIntentId
            )
            
            // Return updated order
            return try await getOrderDetails(orderId)
            
        } catch {
            throw handleError(error)
        }
    }
    
    // MARK: - Debug Methods (for testing wallet access)
    func testWalletAccess(userId: UUID) async throws -> String {
        do {
            print("🔵 testWalletAccess: Testing wallet access for user \(userId)")
            
            // Try to read wallet
            let wallet: Wallet = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: userId.uuidString)
                .single()
                .execute()
                .value
            
            print("🔵 testWalletAccess: Successfully read wallet - balance: \(wallet.availableCents)")
            
            // Try to update wallet (small test update)
            let testUpdateResult = try await supabase
                .from("wallets")
                .update([
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("user_id", value: userId.uuidString)
                .execute()
            
            print("🔵 testWalletAccess: Successfully updated wallet - affected rows: \(testUpdateResult.count)")
            
            return "Wallet access test passed - Read: ✅, Update: ✅"
        } catch {
            print("❌ testWalletAccess: Failed - \(error)")
            return "Wallet access test failed - \(error.localizedDescription)"
        }
    }
    
    // MARK: - Helper Methods
    private func handleError(_ error: Error) -> Error {
        if error.localizedDescription.contains("cancelled") {
            return OrderServiceError.requestCancelled
        } else if error.localizedDescription.contains("network") {
            return OrderServiceError.networkError
        } else if error.localizedDescription.contains("unauthorized") {
            return OrderServiceError.unauthorizedAction
        } else if error.localizedDescription.contains("not_found") {
            return OrderServiceError.orderNotFound
        } else {
            return error
        }
    }
    
    // MARK: - Validation
    func validateOrderCreation(_ orderCreate: OrderCreate) throws {
        // Basic validation
        guard orderCreate.priceCents > 0 else {
            throw OrderServiceError.invalidPrice
        }
        
        guard orderCreate.buyerId != orderCreate.sellerId else {
            throw OrderServiceError.cannotBuyFromSelf
        }
        
        // Additional business logic validation can be added here
    }
}

// MARK: - Errors
enum OrderServiceError: Error, LocalizedError {
    case unauthorizedAction
    case orderNotFound
    case invalidPrice
    case cannotBuyFromSelf
    case requestCancelled
    case networkError
    case invalidOrderState
    case invalidOrderStatus(String)
    case walletUpdateFailed(String)
    
    var errorDescription: String? {
        switch self {
        case .unauthorizedAction:
            return "You are not authorized to perform this action"
        case .orderNotFound:
            return "Order not found"
        case .invalidPrice:
            return "Invalid price specified"
        case .cannotBuyFromSelf:
            return "You cannot buy from yourself"
        case .requestCancelled:
            return "Request was cancelled"
        case .networkError:
            return "Network connection error"
        case .invalidOrderState:
            return "This operation is not allowed in the current order state"
        case .invalidOrderStatus(let message):
            return message
        case .walletUpdateFailed(let message):
            return "Failed to update wallet: \(message)"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .unauthorizedAction:
            return "Please verify you have permission to perform this action"
        case .orderNotFound:
            return "The order may have been deleted or you may have the wrong ID"
        case .invalidPrice:
            return "Please specify a valid price greater than zero"
        case .cannotBuyFromSelf:
            return "You cannot create an order to buy from yourself"
        case .requestCancelled:
            return "Please try again"
        case .networkError:
            return "Please check your internet connection and try again"
        case .invalidOrderState:
            return "This operation is not allowed in the current order state"
        case .invalidOrderStatus(let message):
            return "Please ensure the order is in the correct status for this operation. \(message)"
        case .walletUpdateFailed(let message):
            return "Please contact support as there was an issue updating the seller's wallet. \(message)"
        }
    }
}
