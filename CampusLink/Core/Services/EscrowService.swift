import Foundation
import Supabase

/// Service for managing Stripe Connect escrow operations
/// Handles escrow account creation, status tracking, and automatic release timing
final class EscrowService: ObservableObject {
    static let shared = EscrowService()
    private init() {}
    
    // MARK: - Escrow Account Management
    
    /// Creates or retrieves an escrow account for a seller
    /// - Parameter sellerId: The seller's user ID
    /// - Returns: Stripe Connect escrow account ID
    func getOrCreateEscrowAccount(for sellerId: UUID) async throws -> String {
        do {
            // First check if seller already has a Stripe Connect account
            let user: User = try await supabase
                .from("users")
                .select()
                .eq("id", value: sellerId.uuidString)
                .single()
                .execute()
                .value
            
            // If seller doesn't have Stripe Connect, throw error
            guard let stripeConnectId = user.stripeConnectId else {
                throw EscrowServiceError.sellerNotOnboarded
            }
            
            // Check if escrow account already exists in orders
            let existingOrder: Order? = try? await supabase
                .from("orders")
                .select()
                .eq("seller_id", value: sellerId.uuidString)
                .not("stripe_escrow_account_id", operator: .is, value: "null")
                .limit(1)
                .single()
                .execute()
                .value
            
            if let escrowAccountId = existingOrder?.stripeEscrowAccountId {
                return escrowAccountId
            }
            
            // Create new escrow account ID (this would typically come from Stripe)
            // For now, we'll use a placeholder that gets updated when payment is processed
            let escrowAccountId = "escrow_\(stripeConnectId)_\(UUID().uuidString.prefix(8))"
            
            return escrowAccountId
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Updates an order with escrow account information
    /// - Parameters:
    ///   - orderId: The order ID to update
    ///   - escrowAccountId: The Stripe Connect escrow account ID
    ///   - paymentIntentId: The Stripe payment intent ID
    func updateOrderWithEscrow(orderId: UUID, escrowAccountId: String, paymentIntentId: String) async throws {
        do {
            let _: Order = try await supabase
                .from("orders")
                .update([
                    "stripe_escrow_account_id": escrowAccountId,
                    "stripe_payment_intent_id": paymentIntentId,
                    "auto_release_at": ISO8601DateFormatter().string(from: Date().addingTimeInterval(3 * 24 * 60 * 60)), // 3 days
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Gets escrow status for an order
    /// - Parameter orderId: The order ID
    /// - Returns: Escrow status information
    func getEscrowStatus(for orderId: UUID) async throws -> EscrowStatus {
        do {
            let order: Order = try await supabase
                .from("orders")
                .select()
                .eq("id", value: orderId.uuidString)
                .single()
                .execute()
                .value
            
            return EscrowStatus(
                orderId: orderId,
                escrowAccountId: order.stripeEscrowAccountId,
                paymentIntentId: order.stripePaymentIntentId,
                autoReleaseAt: order.autoReleaseAt,
                orderStatus: order.orderStatus,
                paymentStatus: order.paymentStatus
            )
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Checks if escrow can be released (delivery confirmed or auto-release time reached)
    /// - Parameter orderId: The order ID
    /// - Returns: True if escrow can be released
    func canReleaseEscrow(for orderId: UUID) async throws -> Bool {
        let status = try await getEscrowStatus(for: orderId)
        
        // Can release if delivery confirmed or auto-release time reached
        return status.orderStatus == .completed || 
               (status.autoReleaseAt != nil && status.autoReleaseAt! <= Date())
    }
    
    /// Releases funds from escrow to seller's Campus Wallet
    /// - Parameter orderId: The order ID
    func releaseEscrowFunds(for orderId: UUID) async throws {
        do {
            let status = try await getEscrowStatus(for: orderId)
            
            guard let escrowAccountId = status.escrowAccountId else {
                throw EscrowServiceError.noEscrowAccount
            }
            
            // Update order status to reflect escrow release
            let _: Order = try await supabase
                .from("orders")
                .update([
                    "payment_status": "released",
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            // Update seller's wallet balance
            let order: Order = try await supabase
                .from("orders")
                .select()
                .eq("id", value: orderId.uuidString)
                .single()
                .execute()
                .value
            
            // Get seller's wallet
            let wallet: Wallet = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: order.sellerId.uuidString)
                .single()
                .execute()
                .value
            
            // Calculate amount after Stripe fees
            let feeService = FeeCalculationService.shared
            let stripeFeeCents = feeService.calculateStripeProcessingFee(amountCents: order.priceCents)
            let netAmountCents = order.priceCents - stripeFeeCents
            
            // Update wallet balance
            let _: Wallet = try await supabase
                .from("wallets")
                .update([
                    "available_cents": String(wallet.availableCents + netAmountCents),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("user_id", value: order.sellerId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Gets time remaining until automatic escrow release
    /// - Parameter orderId: The order ID
    /// - Returns: Time interval until auto-release, or nil if not applicable
    func getTimeUntilAutoRelease(for orderId: UUID) async throws -> TimeInterval? {
        let status = try await getEscrowStatus(for: orderId)
        
        guard let autoReleaseAt = status.autoReleaseAt else { return nil }
        
        let timeRemaining = autoReleaseAt.timeIntervalSinceNow
        return timeRemaining > 0 ? timeRemaining : nil
    }
    
    // MARK: - Helper Methods
    
    private func handleError(_ error: Error) -> Error {
        if error.localizedDescription.contains("cancelled") {
            return EscrowServiceError.requestCancelled
        } else if error.localizedDescription.contains("network") {
            return EscrowServiceError.networkError
        } else if error.localizedDescription.contains("unauthorized") {
            return EscrowServiceError.unauthorizedAction
        } else if error.localizedDescription.contains("not_found") {
            return EscrowServiceError.orderNotFound
        } else {
            return error
        }
    }
}

// MARK: - Escrow Status Model

struct EscrowStatus {
    let orderId: UUID
    let escrowAccountId: String?
    let paymentIntentId: String?
    let autoReleaseAt: Date?
    let orderStatus: OrderStatus
    let paymentStatus: PaymentStatus
    
    var isEscrowActive: Bool {
        return escrowAccountId != nil && 
               [.placed, .sellerConfirmed, .inProgress].contains(orderStatus) &&
               paymentStatus == .succeeded
    }
    
    var canBeReleased: Bool {
        return orderStatus == .completed || 
               (autoReleaseAt != nil && autoReleaseAt! <= Date())
    }
    
    var timeUntilAutoRelease: TimeInterval? {
        guard let autoReleaseAt = autoReleaseAt else { return nil }
        let timeRemaining = autoReleaseAt.timeIntervalSinceNow
        return timeRemaining > 0 ? timeRemaining : nil
    }
    
    var autoReleaseFormatted: String? {
        guard let timeInterval = timeUntilAutoRelease, timeInterval > 0 else { return nil }
        
        let hours = Int(timeInterval) / 3600
        let minutes = Int(timeInterval) % 3600 / 60
        
        if hours > 24 {
            let days = hours / 24
            return "\(days) day\(days == 1 ? "" : "s")"
        } else if hours > 0 {
            return "\(hours) hour\(hours == 1 ? "" : "s")"
        } else {
            return "\(minutes) minute\(minutes == 1 ? "" : "s")"
        }
    }
}

// MARK: - Errors

enum EscrowServiceError: Error, LocalizedError {
    case sellerNotOnboarded
    case noEscrowAccount
    case unauthorizedAction
    case orderNotFound
    case requestCancelled
    case networkError
    case invalidEscrowState
    
    var errorDescription: String? {
        switch self {
        case .sellerNotOnboarded:
            return "Seller must complete Stripe Connect onboarding before accepting payments"
        case .noEscrowAccount:
            return "No escrow account found for this order"
        case .unauthorizedAction:
            return "You are not authorized to perform this action"
        case .orderNotFound:
            return "Order not found"
        case .requestCancelled:
            return "Request was cancelled"
        case .networkError:
            return "Network connection error"
        case .invalidEscrowState:
            return "This operation is not allowed in the current escrow state"
        }
    }
    
    var recoverySuggestion: String? {
        switch self {
        case .sellerNotOnboarded:
            return "Please complete your Stripe Connect onboarding to start accepting payments"
        case .noEscrowAccount:
            return "The escrow account may not have been created properly"
        case .unauthorizedAction:
            return "Please verify you have permission to perform this action"
        case .orderNotFound:
            return "The order may have been deleted or you may have the wrong ID"
        case .requestCancelled:
            return "Please try again"
        case .networkError:
            return "Please check your internet connection and try again"
        case .invalidEscrowState:
            return "This operation is not allowed in the current escrow state"
        }
    }
}
