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
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                stripeEscrowAccountId: escrowAccountId, // Set escrow account ID
                marketplaceFeeCents: 0, // No marketplace fees initially, only Stripe processing fees
                stripePaymentIntentId: nil // Will be set when payment intent is created
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
            guard order.orderStatus == .placed else {
                throw OrderServiceError.invalidOrderStatus
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
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Verify the current user is the buyer
            let order = try await getOrderDetails(orderId)
            guard currentUserId == order.buyerId else {
                throw OrderServiceError.unauthorizedAction
            }
            
            // Verify order is in correct status for delivery confirmation
            guard order.orderStatus == .sellerConfirmed else {
                throw OrderServiceError.invalidOrderStatus
            }
            
            // Update order status to completed
            let updatedOrder: Order = try await supabase
                .from("orders")
                .update([
                    "order_status": "completed",
                    "completed_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            // Release funds from escrow to seller's wallet
            try await releaseEscrowFunds(order: order)
            
            return updatedOrder
        } catch {
            throw handleError(error)
        }
    }
    
    /// Releases funds from escrow to seller's wallet
    private func releaseEscrowFunds(order: Order) async throws {
        // Get the seller's wallet
        let sellerWallet: Wallet = try await supabase
            .from("wallets")
            .select()
            .eq("user_id", value: order.sellerId.uuidString)
            .single()
            .execute()
            .value
        
        // Calculate net amount (after marketplace fees)
        let netAmountCents = order.priceCents - order.marketplaceFeeCents
        
        // Update seller's wallet balance
        let _: Wallet = try await supabase
            .from("wallets")
            .update([
                "available_cents": String(sellerWallet.availableCents + netAmountCents),
                "updated_at": ISO8601DateFormatter().string(from: Date())
            ])
            .eq("user_id", value: order.sellerId.uuidString)
            .select()
            .single()
            .execute()
            .value
        
        // Create a transaction record for the escrow release
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
            
            let orders: [Order] = try await supabase
                .from("orders")
                .select()
                .or("buyer_id.eq.\(currentUserId.uuidString),seller_id.eq.\(currentUserId.uuidString)")
                .eq("order_status", value: status?.rawValue ?? "")
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
            let cancelledOrders = allOrders.filter { $0.orderStatus == .cancelled }.count
            
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
    case invalidOrderStatus
    
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
        case .invalidOrderStatus:
            return "This operation is not allowed in the current order status"
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
        case .invalidOrderStatus:
            return "Please ensure the order is in the correct status for this operation"
        }
    }
}
