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
    /// - Note: Now allows orders even if seller hasn't completed onboarding (funds held until verification)
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
            
            // Create escrow account ID
            // If seller has Stripe Connect, use their connect ID
            // Otherwise, use placeholder - funds will be held until they complete onboarding
            let escrowAccountId: String
            if let stripeConnectId = user.stripeConnectId {
                escrowAccountId = "escrow_\(stripeConnectId)_\(UUID().uuidString.prefix(8))"
            } else {
                // Seller hasn't completed onboarding yet - use pending escrow ID
                escrowAccountId = "escrow_pending_\(sellerId.uuidString.prefix(8))_\(UUID().uuidString.prefix(8))"
                print("⚠️ Seller \(sellerId) hasn't completed Stripe onboarding - using pending escrow")
            }
            
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
            
            // Try to fetch escrow_release_status from payments table
            var escrowReleaseStatus: String? = nil
            if let paymentIntentId = order.stripePaymentIntentId {
                do {
                    struct PaymentEscrowStatus: Decodable {
                        let escrowReleaseStatus: String?
                        
                        enum CodingKeys: String, CodingKey {
                            case escrowReleaseStatus = "escrow_release_status"
                        }
                    }
                    
                    let payment: PaymentEscrowStatus = try await supabase
                        .from("payments")
                        .select("escrow_release_status")
                        .eq("payment_intent_id", value: paymentIntentId)
                        .single()
                        .execute()
                        .value
                    
                    escrowReleaseStatus = payment.escrowReleaseStatus
                    print("✅ Fetched escrow_release_status from payments table: \(escrowReleaseStatus ?? "nil")")
                } catch {
                    print("⚠️ Could not fetch escrow_release_status from payments table: \(error)")
                    // Non-critical - will fall back to computed status
                }
            }
            
            return EscrowStatus(
                orderId: orderId,
                escrowAccountId: order.stripeEscrowAccountId,
                paymentIntentId: order.stripePaymentIntentId,
                orderStatus: order.orderStatus,
                paymentStatus: order.paymentStatus,
                escrowReleaseStatus: escrowReleaseStatus
            )
            
        } catch {
            throw handleError(error)
        }
    }
    
    /// Checks if escrow can be released (only when delivery is manually confirmed)
    /// - Parameter orderId: The order ID
    /// - Returns: True if escrow can be released
    func canReleaseEscrow(for orderId: UUID) async throws -> Bool {
        let status = try await getEscrowStatus(for: orderId)
        
        // Can only release when delivery is manually confirmed
        return status.orderStatus == .completed
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
    let orderStatus: OrderStatus
    let paymentStatus: PaymentStatus
    let escrowReleaseStatus: String? // From payments table: 'held', 'released', or 'disputed'
    
    var isEscrowActive: Bool {
        // Check actual escrow_release_status if available, otherwise compute from order status
        if let releaseStatus = escrowReleaseStatus {
            return releaseStatus == "held" && escrowAccountId != nil
        }
        return escrowAccountId != nil && 
               [.placed, .sellerConfirmed, .inProgress].contains(orderStatus) &&
               paymentStatus == .succeeded
    }
    
    var canBeReleased: Bool {
        // Only show release button for completed orders (funds should already be released)
        return orderStatus == .completed
    }
    
    var displayStatus: String {
        // Use actual escrow_release_status if available
        if let releaseStatus = escrowReleaseStatus {
            switch releaseStatus {
            case "held":
                return "Held in Escrow"
            case "released":
                return "Funds Released"
            case "disputed":
                return "Disputed"
            default:
                return "Unknown"
            }
        }
        
        // Fall back to computed status
        if orderStatus == .completed {
            return "Funds Released"
        } else if isEscrowActive {
            return "Held in Escrow"
        } else {
            return "Inactive"
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
