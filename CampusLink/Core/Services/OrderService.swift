import Foundation
import Supabase

// MARK: - Order Service
final class OrderService: ObservableObject {
    static let shared = OrderService()
    private init() {}
    
    // MARK: - PIN Generation
    private func generateVerificationPIN() -> String {
        return String(format: "%04d", Int.random(in: 0...9999))
    }
    
    // MARK: - Order Creation
    func createOrder(_ orderCreate: OrderCreate) async throws -> Order {
        print("🔍 OrderService.createOrder called")
        do {
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            print("🔍 Got session, user ID: \(currentUserId)")
            
            // Verify the current user is the buyer
            guard currentUserId == orderCreate.buyerId else {
                throw OrderServiceError.unauthorizedAction
            }
            
            // Get or create escrow account for seller
            print("🔍 About to call escrow service for seller: \(orderCreate.sellerId)")
            let escrowService = EscrowService.shared
            let escrowAccountId = try await escrowService.getOrCreateEscrowAccount(for: orderCreate.sellerId)
            print("🔍 Got escrow account: \(escrowAccountId)")
            
            // Fetch listing to check if it's a service (for PIN generation)
            print("🔍 Fetching listing to check type...")
            let listing: Listing = try await supabase
                .from("listings")
                .select()
                .eq("id", value: orderCreate.listingId.uuidString)
                .single()
                .execute()
                .value
            
            // Generate PIN only for service listings
            let verificationPin = listing.listingType == .service ? generateVerificationPIN() : nil
            print("🔍 Listing type: \(listing.listingType), PIN generated: \(verificationPin ?? "none")")
            
            print("🔍 DEBUG - Order creation params:")
            print("  listing_id: \(orderCreate.listingId.uuidString)")
            print("  buyer_id: \(orderCreate.buyerId.uuidString)")
            print("  seller_id: \(orderCreate.sellerId.uuidString)")
            print("  price_cents: \(orderCreate.priceCents)")
            print("  payment_method: \(orderCreate.paymentMethod.rawValue)")
            print("  escrow_account_id: \(escrowAccountId)")
            print("  time_slot_id: \(orderCreate.timeSlotId?.uuidString ?? "nil")")
            print("  current_user_id: \(currentUserId.uuidString)")
            print("  buyer_id matches current user: \(currentUserId == orderCreate.buyerId)")
            
            // Create order with all required fields including escrow and both prices
            // Debug: Let's see the exact JSON being sent
            let orderData = OrderInsert(
                listingId: orderCreate.listingId,
                buyerId: orderCreate.buyerId,
                sellerId: orderCreate.sellerId,
                priceCents: orderCreate.priceCents,
                sellerPriceCents: orderCreate.sellerPriceCents,
                buyerPriceCents: orderCreate.buyerPriceCents,
                paymentMethod: orderCreate.paymentMethod.rawValue,
                orderStatus: "placed",
                paymentStatus: "succeeded",
                createdAt: ISO8601DateFormatter().string(from: Date()),
                updatedAt: ISO8601DateFormatter().string(from: Date()),
                stripeEscrowAccountId: escrowAccountId,
                marketplaceFeeCents: 0,
                stripePaymentIntentId: nil,
                timeSlotId: orderCreate.timeSlotId,
                verificationPin: verificationPin,
                quantity: orderCreate.quantity
            )
            
            // Debug the JSON
            if let jsonData = try? JSONEncoder().encode(orderData),
               let jsonString = String(data: jsonData, encoding: .utf8) {
                print("🔍 JSON being sent: \(jsonString)")
            }
            
            print("🔍 About to insert order into database")
            let order: Order = try await supabase
                .from("orders")
                .insert(orderData)
                .select()
                .single()
                .execute()
                .value
            
            print("✅ Order created successfully: \(order.id)")
            
            // CRITICAL: Deduct wallet balance if payment method is wallet
            if orderCreate.paymentMethod == .wallet {
                print("💳 Processing wallet payment - deducting \(orderCreate.buyerPriceCents) cents from buyer wallet")
                
                // Get buyer's current wallet
                let buyerWallet: Wallet = try await supabase
                    .from("wallets")
                    .select()
                    .eq("user_id", value: orderCreate.buyerId.uuidString)
                    .single()
                    .execute()
                    .value
                
                print("💳 Current wallet balance: \(buyerWallet.availableCents) cents")
                
                // Verify sufficient funds (should already be checked, but double-check)
                guard let buyerPriceCents = orderCreate.buyerPriceCents else {
                    throw OrderServiceError.invalidPrice
                }
                
                guard buyerWallet.availableCents >= buyerPriceCents else {
                    // Rollback: Delete the order we just created
                    _ = try? await supabase
                        .from("orders")
                        .delete()
                        .eq("id", value: order.id.uuidString)
                        .execute()
                    throw OrderServiceError.insufficientFunds
                }
                
                // Deduct from buyer's wallet
                let newBalance = buyerWallet.availableCents - buyerPriceCents
                print("💳 New wallet balance will be: \(newBalance) cents")
                
                struct WalletUpdate: Encodable {
                    let available_cents: Int
                    let updated_at: String
                }
                
                let updateResult = try await supabase
                    .from("wallets")
                    .update(WalletUpdate(
                        available_cents: newBalance,
                        updated_at: ISO8601DateFormatter().string(from: Date())
                    ))
                    .eq("user_id", value: orderCreate.buyerId.uuidString)
                    .execute()
                
                if updateResult.count == 0 {
                    print("❌ Failed to deduct wallet balance")
                    // Rollback: Delete the order
                    _ = try? await supabase
                        .from("orders")
                        .delete()
                        .eq("id", value: order.id.uuidString)
                        .execute()
                    throw OrderServiceError.walletUpdateFailed("Failed to deduct wallet balance")
                }
                
                print("✅ Wallet payment processed: Deducted \(orderCreate.buyerPriceCents) cents, new balance: \(newBalance) cents")
            }
            
            // Notify seller of new order
            await NotificationService.shared.createOrderNotification(
                for: orderCreate.sellerId.uuidString,
                orderId: order.id,
                listingTitle: listing.title,
                status: .placed
            )
            
            return order
        } catch {
            print("❌ OrderService.createOrder ERROR: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Order creation error: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error localized: \(error.localizedDescription)")
            
            // Check if it's a Supabase/PostgREST error
            if let supabaseError = error as? NSError {
                print("❌ NSError domain: \(supabaseError.domain)")
                print("❌ NSError code: \(supabaseError.code)")
                print("❌ NSError userInfo: \(supabaseError.userInfo)")
            }
            
            // Try to get the actual PostgreSQL error
            let errorString = String(describing: error)
            print("❌ Full error description: \(errorString)")
            
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
    
    func markDelivered(_ orderId: UUID, deliveryPhotoUrl: String) async throws -> Order {
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
                    "delivery_photo_url": deliveryPhotoUrl,
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            // Fetch listing for notification
            let listing: Listing = try await supabase
                .from("listings")
                .select()
                .eq("id", value: order.listingId.uuidString)
                .single()
                .execute()
                .value
            
            // Notify buyer that seller marked as delivered
            await NotificationService.shared.createOrderNotification(
                for: order.buyerId.uuidString,
                orderId: orderId,
                listingTitle: listing.title,
                status: .sellerConfirmed
            )
            
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
            
            // STEP 1: Capture Stripe payment if this was a card payment
            if let paymentIntentId = order.stripePaymentIntentId, order.paymentMethod == .card {
                print("💳 confirmDelivery: Capturing Stripe payment: \(paymentIntentId)")
                do {
                    try await PaymentService.shared.capturePayment(paymentIntentId: paymentIntentId)
                    print("✅ confirmDelivery: Payment captured successfully")
                } catch {
                    print("❌ confirmDelivery: Failed to capture payment: \(error)")
                    throw OrderServiceError.paymentCaptureFailed("Failed to capture payment: \(error.localizedDescription)")
                }
            } else {
                print("ℹ️ confirmDelivery: No payment capture needed (payment method: \(order.paymentMethod.displayName))")
            }
            
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
            
            // Fetch listing for notification
            let listing: Listing = try await supabase
                .from("listings")
                .select()
                .eq("id", value: order.listingId.uuidString)
                .single()
                .execute()
                .value
            
            // Notify seller that buyer confirmed receipt and funds are released
            await NotificationService.shared.createOrderNotification(
                for: order.sellerId.uuidString,
                orderId: orderId,
                listingTitle: listing.title,
                status: .completed
            )
            
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
    /// - Note: Only releases if seller has completed Stripe Connect onboarding
    private func releaseEscrowFunds(order: Order) async throws {
        print("🔵 releaseEscrowFunds: Starting for order \(order.id)")
        
        // CRITICAL: Check if seller has completed Stripe Connect onboarding
        print("🔵 releaseEscrowFunds: Checking seller's Stripe Connect status...")
        let sellerProfile: User = try await supabase
            .from("users")
            .select()
            .eq("id", value: order.sellerId.uuidString)
            .single()
            .execute()
            .value
        
        // If seller hasn't completed onboarding, keep funds in escrow
        if sellerProfile.stripeConnectId == nil || sellerProfile.stripePayoutsEnabled != true {
            print("⚠️ Seller hasn't completed Stripe onboarding - funds remain in escrow")
            print("   - stripe_connect_id: \(sellerProfile.stripeConnectId ?? "nil")")
            print("   - payouts_enabled: \(sellerProfile.stripePayoutsEnabled ?? false)")
            
            // TODO: Send notification to seller
            // "You made a $XX sale! Complete payout setup to receive your earnings"
            
            throw OrderServiceError.sellerOnboardingRequired(
                "Seller must complete payout setup to receive funds. " +
                "Order \(order.id.uuidString.prefix(8)) is being held in escrow."
            )
        }
        
        print("✅ Seller has completed Stripe onboarding - proceeding with fund release")
        
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
    
    // MARK: - Order Cancellation
    
    /// Cancels an order and refunds the buyer (only allowed if seller hasn't confirmed yet)
    /// - Parameter orderId: The order ID to cancel
    /// - Returns: The updated cancelled order
    func cancelOrder(_ orderId: UUID) async throws -> Order {
        do {
            print("🔵 cancelOrder: Starting cancellation for order \(orderId)")
            
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            print("🔵 cancelOrder: Current user ID: \(currentUserId)")
            
            // Get order details
            let order = try await getOrderDetails(orderId)
            print("🔵 cancelOrder: Order status: \(order.orderStatus), buyer: \(order.buyerId)")
            
            // Verify the current user is the buyer
            guard currentUserId == order.buyerId else {
                print("❌ cancelOrder: Unauthorized - current user is not the buyer")
                throw OrderServiceError.unauthorizedAction
            }
            
            // Only allow cancellation if seller hasn't confirmed yet (order is still in 'placed' status)
            guard order.orderStatus == .placed else {
                print("❌ cancelOrder: Cannot cancel - order status is \(order.orderStatus.displayName)")
                throw OrderServiceError.invalidOrderStatus("Cannot cancel order. Order status must be 'placed', but current status is '\(order.orderStatus.displayName)'")
            }
            
            print("🔵 cancelOrder: Order is eligible for cancellation")
            
            // Update order status to cancelled
            let updatedOrder: Order = try await supabase
                .from("orders")
                .update([
                    "order_status": "cancelled",
                    "payment_status": "refunded",
                    "cancelled_at": ISO8601DateFormatter().string(from: Date()),
                    "refunded_at": ISO8601DateFormatter().string(from: Date()),
                    "updated_at": ISO8601DateFormatter().string(from: Date())
                ])
                .eq("id", value: orderId.uuidString)
                .select()
                .single()
                .execute()
                .value
            
            print("🔵 cancelOrder: Order status updated to cancelled")
            
            // Refund the buyer
            try await refundBuyer(order: order)
            
            print("✅ cancelOrder: Order cancelled and buyer refunded successfully")
            
            // Notify seller that order was cancelled
            await NotificationService.shared.createOrderNotification(
                for: order.sellerId.uuidString,
                orderId: orderId,
                listingTitle: "Order",
                status: .cancelled
            )
            
            return updatedOrder
        } catch {
            throw handleError(error)
        }
    }
    
    /// Refunds the buyer for a cancelled order
    /// - Parameter order: The order to refund
    private func refundBuyer(order: Order) async throws {
        print("🔵 refundBuyer: Starting refund for order \(order.id)")
        print("🔵 refundBuyer: Buyer: \(order.buyerId), Amount: \(order.priceCents) cents")
        
        // Get or create buyer's wallet
        var buyerWallet: Wallet
        do {
            buyerWallet = try await supabase
                .from("wallets")
                .select()
                .eq("user_id", value: order.buyerId.uuidString)
                .single()
                .execute()
                .value
            
            print("🔵 refundBuyer: Found existing buyer wallet with \(buyerWallet.availableCents) cents")
        } catch {
            print("🔵 refundBuyer: No existing wallet found, creating new wallet for buyer \(order.buyerId)")
            
            // Create a new wallet for the buyer
            struct WalletInsert: Encodable {
                let user_id: String
                let available_cents: Int
                let escrow_cents: Int
                let updated_at: String
            }
            
            let insertData = WalletInsert(
                user_id: order.buyerId.uuidString,
                available_cents: 0,
                escrow_cents: 0,
                updated_at: ISO8601DateFormatter().string(from: Date())
            )
            
            buyerWallet = try await supabase
                .from("wallets")
                .insert(insertData)
                .select()
                .single()
                .execute()
                .value
            
            print("🔵 refundBuyer: Created new wallet with \(buyerWallet.availableCents) cents")
        }
        
        // Calculate refund amount (full order price for buyer)
        let refundAmountCents = order.buyerPriceCents ?? order.priceCents
        print("🔵 refundBuyer: Refund amount: \(refundAmountCents) cents")
        print("🔵 refundBuyer: Current wallet balance: \(buyerWallet.availableCents)")
        print("🔵 refundBuyer: New balance will be: \(buyerWallet.availableCents + refundAmountCents)")
        
        // Update buyer's wallet balance
        struct WalletUpdate: Encodable {
            let available_cents: Int
            let updated_at: String
        }
        
        let updateData = WalletUpdate(
            available_cents: buyerWallet.availableCents + refundAmountCents,
            updated_at: ISO8601DateFormatter().string(from: Date())
        )
        
        print("🔵 refundBuyer: Updating wallet...")
        
        let updateResult = try await supabase
            .from("wallets")
            .update(updateData)
            .eq("user_id", value: order.buyerId.uuidString)
            .execute()
        
        print("🔵 refundBuyer: Update result count: \(updateResult.count)")
        
        if updateResult.count == 0 {
            print("❌ refundBuyer: No wallet rows were updated for buyer \(order.buyerId)")
            throw OrderServiceError.walletUpdateFailed("Failed to refund buyer - wallet not found")
        }
        
        print("✅ refundBuyer: Successfully refunded \(refundAmountCents) cents to buyer wallet")
        
        // Verify the wallet update
        let verifyWallet: Wallet = try await supabase
            .from("wallets")
            .select()
            .eq("user_id", value: order.buyerId.uuidString)
            .single()
            .execute()
            .value
        
        let expectedBalance = buyerWallet.availableCents + refundAmountCents
        print("🔵 refundBuyer: Wallet verification - Expected: \(expectedBalance), Actual: \(verifyWallet.availableCents)")
        
        if verifyWallet.availableCents != expectedBalance {
            print("❌ refundBuyer: Wallet balance mismatch!")
            throw OrderServiceError.walletUpdateFailed("Refund verification failed")
        }
        
        print("✅ refundBuyer: Wallet balance verified successfully")
    }
    
    // MARK: - PIN Verification
    func verifyServicePIN(_ orderId: UUID, pin: String) async throws -> Order {
        do {
            print("🔍 verifyServicePIN: Starting verification for order \(orderId) with PIN \(pin)")
            
            let session = try await supabase.auth.session
            let currentUserId = session.user.id
            
            // Verify the current user is the seller
            let order = try await getOrderDetails(orderId)
            print("🔍 verifyServicePIN: Current user \(currentUserId), seller \(order.sellerId)")
            guard currentUserId == order.sellerId else {
                print("❌ verifyServicePIN: Unauthorized - current user is not the seller")
                throw OrderServiceError.unauthorizedAction
            }
            
            print("🔍 verifyServicePIN: Calling RPC function...")
            // Call RPC function using dictionary format like other RPC calls in codebase
            try await supabase
                .rpc("verify_service_pin", params: [
                    "p_order_id": orderId.uuidString,
                    "p_pin": pin
                ])
                .execute()
            
            print("✅ verifyServicePIN: PIN verified successfully, fetching updated order")
            
            // Return updated order
            return try await getOrderDetails(orderId)
        } catch {
            print("❌ verifyServicePIN: Error - \(error)")
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
    case pinVerificationFailed(String)
    case insufficientFunds
    case sellerOnboardingRequired(String)
    case paymentCaptureFailed(String)
    
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
        case .pinVerificationFailed(let message):
            return message
        case .insufficientFunds:
            return "Insufficient funds in wallet"
        case .sellerOnboardingRequired(let message):
            return message
        case .paymentCaptureFailed(let message):
            return "Payment capture failed: \(message)"
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
        case .pinVerificationFailed(let message):
            return "Please verify the PIN with the buyer and try again"
        case .insufficientFunds:
            return "Please add funds to your wallet and try again"
        case .sellerOnboardingRequired:
            return "The seller will be notified to complete payout setup. Funds will be released once verification is complete."
        case .paymentCaptureFailed:
            return "Please try again. If the problem persists, contact support."
        }
    }
}
