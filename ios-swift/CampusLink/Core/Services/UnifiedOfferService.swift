import Foundation
import Supabase

// MARK: - AnyEncodable Helper
struct AnyEncodable: Encodable {
    private let value: Encodable
    
    init(_ value: Encodable) {
        self.value = value
    }
    
    func encode(to encoder: Encoder) throws {
        try value.encode(to: encoder)
    }
}

/// Unified service for managing offers in both directions:
/// - Seek mode: Sellers make offers on buyer "wanted" posts
/// - Negotiation mode: Buyers make offers on seller listings
final class UnifiedOfferService: ObservableObject {
    static let shared = UnifiedOfferService()
    private init() {}
    
    // Use global supabase client from CampusLinkTestApp.swift (uses Secrets)
    
    // MARK: - Create Offer
    
    /// Create a new offer (works for both seek and regular listings)
    /// - Parameters:
    ///   - listingId: The listing being offered on
    ///   - listingType: Whether it's a seek or regular listing
    ///   - toUserId: The user receiving the offer
    ///   - amountCents: Offer amount in cents
    ///   - message: Optional message with the offer
    ///   - offerListingId: Optional - seller's listing when offering on seek post
    /// - Returns: The created offer
    func createOffer(
        listingId: UUID,
        listingType: OfferListingType,
        toUserId: String,
        amountCents: Int,
        message: String? = nil,
        offerListingId: UUID? = nil,
        fromUserId: String
    ) async throws -> Offer {
        // Validation
        guard amountCents > 0 else {
            throw OfferServiceError.invalidAmount
        }
        
        guard fromUserId.lowercased() != toUserId.lowercased() else {
            throw OfferServiceError.cannotOfferToSelf
        }
        
        // Create offer insert structure
        var offerInsert: [String: AnyEncodable] = [
            "listing_id": AnyEncodable(listingId.uuidString),
            "listing_type": AnyEncodable(listingType.rawValue),
            "offer_from_user_id": AnyEncodable(fromUserId),
            "offer_to_user_id": AnyEncodable(toUserId),
            "price_cents": AnyEncodable(amountCents),
            "status": AnyEncodable("pending"),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
            "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        ]
        
        if let message = message {
            offerInsert["message"] = AnyEncodable(message)
        }
        
        if let offerListingId = offerListingId {
            offerInsert["offer_listing_id"] = AnyEncodable(offerListingId.uuidString)
        }
        
        print("📤 Creating offer: \(offerInsert)")
        
        let offer: Offer = try await supabase
            .from("offers")
            .insert(offerInsert)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Offer created successfully: \(offer.id)")
        
        // Note: Database trigger will handle sending chat message and push notification
        
        return offer
    }
    
    // MARK: - Counter Offer
    
    /// Create a counter-offer to an existing offer
    /// - Parameters:
    ///   - parentOfferId: The offer being countered
    ///   - amountCents: Counter-offer amount in cents
    ///   - message: Optional message with counter-offer
    ///   - currentUserId: The user making the counter-offer
    /// - Returns: The new counter-offer
    func counterOffer(
        parentOfferId: UUID,
        amountCents: Int,
        message: String? = nil,
        currentUserId: String
    ) async throws -> Offer {
        // Validation
        guard amountCents > 0 else {
            throw OfferServiceError.invalidAmount
        }
        
        // Get parent offer
        let parentOffer: Offer = try await supabase
            .from("offers")
            .select()
            .eq("id", value: parentOfferId.uuidString)
            .single()
            .execute()
            .value
        
        print("🔄 Creating counter-offer for parent: \(parentOfferId)")
        
        // Verify current user is a participant
        let role = parentOffer.getUserRole(currentUserId: currentUserId)
        guard role != .none else {
            throw OfferServiceError.unauthorized
        }
        
        // Swap roles for counter-offer
        let newFromUserId: String
        let newToUserId: String
        
        if role == .sender {
            // Original sender is countering, so offer goes to original receiver
            newFromUserId = parentOffer.offerFromUserId
            newToUserId = parentOffer.offerToUserId
        } else {
            // Original receiver is countering, so swap
            newFromUserId = parentOffer.offerToUserId
            newToUserId = parentOffer.offerFromUserId
        }
        
        // Update parent offer status to 'countered'
        try await supabase
            .from("offers")
            .update(["status": "countered"])
            .eq("id", value: parentOfferId.uuidString)
            .execute()
        
        // Create counter-offer
        var counterOfferInsert: [String: AnyEncodable] = [
            "listing_id": AnyEncodable(parentOffer.listingId.uuidString),
            "listing_type": AnyEncodable(parentOffer.listingType.rawValue),
            "offer_from_user_id": AnyEncodable(newFromUserId),
            "offer_to_user_id": AnyEncodable(newToUserId),
            "parent_offer_id": AnyEncodable(parentOfferId.uuidString),
            "price_cents": AnyEncodable(amountCents),
            "status": AnyEncodable("pending"),
            "created_at": AnyEncodable(ISO8601DateFormatter().string(from: Date())),
            "updated_at": AnyEncodable(ISO8601DateFormatter().string(from: Date()))
        ]
        
        if let message = message {
            counterOfferInsert["message"] = AnyEncodable(message)
        }
        
        if let offerListingId = parentOffer.offerListingId {
            counterOfferInsert["offer_listing_id"] = AnyEncodable(offerListingId.uuidString)
        }
        
        let counterOffer: Offer = try await supabase
            .from("offers")
            .insert(counterOfferInsert)
            .select()
            .single()
            .execute()
            .value
        
        print("✅ Counter-offer created: \(counterOffer.id)")
        
        return counterOffer
    }
    
    // MARK: - Accept Offer
    
    /// Accept an offer and create an order at the negotiated price
    /// - Parameters:
    ///   - offerId: The offer to accept
    ///   - currentUserId: The user accepting the offer
    /// - Returns: The created order
    func acceptOffer(offerId: UUID, currentUserId: String) async throws -> Order {
        print("✅ Accepting offer: \(offerId)")
        print("🔍 Current user ID: \(currentUserId)")
        
        // Get the offer
        let offer: Offer = try await supabase
            .from("offers")
            .select()
            .eq("id", value: offerId.uuidString)
            .single()
            .execute()
            .value
        
        print("🔍 Offer from: \(offer.offerFromUserId)")
        print("🔍 Offer to: \(offer.offerToUserId)")
        print("🔍 User role: \(offer.getUserRole(currentUserId: currentUserId))")
        
        // Verify current user is the receiver
        guard offer.getUserRole(currentUserId: currentUserId) == .receiver else {
            print("❌ Authorization failed: User is not receiver")
            throw OfferServiceError.unauthorized
        }
        
        // Verify offer is pending
        guard offer.status == "pending" else {
            throw OfferServiceError.offerNotPending
        }
        
        // Get the listing to check if it's available
        let listing: Listing = try await supabase
            .from("listings")
            .select()
            .eq("id", value: offer.listingId.uuidString)
            .single()
            .execute()
            .value
        
        // Check if listing is still available
        guard !(listing.isSold) && !(listing.archived ?? false) else {
            throw OfferServiceError.listingNotAvailable
        }
        
        // Determine buyer and seller based on listing type
        let (buyerId, sellerId): (String, String)
        
        if offer.listingType == .seek {
            // Seek mode: offer_to_user (seeker) is the buyer, offer_from_user (seller) is the seller
            buyerId = offer.offerToUserId
            sellerId = offer.offerFromUserId
        } else {
            // Regular mode: offer_from_user (buyer) is the buyer, offer_to_user (seller) is the seller
            buyerId = offer.offerFromUserId
            sellerId = offer.offerToUserId
        }
        
        print("💰 Buyer: \(buyerId), Seller: \(sellerId)")
        
        // Get negotiated price
        guard let sellerPriceCents = offer.priceCents else {
            throw OfferServiceError.invalidAmount
        }
        
        // Calculate buyer price (seller price + Stripe processing fee, no platform fee)
        let buyerPriceCents = FeeCalculationService.shared.calculateBuyerPrice(
            sellerPriceCents: sellerPriceCents
        )
        
        print("💰 Seller price: \(sellerPriceCents) cents, Buyer price: \(buyerPriceCents) cents")
        
        // Create UNPAID order - buyer must complete payment after offer acceptance
        // We create the order directly instead of using OrderService because OrderService
        // assumes payment has already been processed (sets paymentStatus to "succeeded")
        
        // Get or create escrow account for seller
        let escrowService = EscrowService.shared
        let escrowAccountId = try await escrowService.getOrCreateEscrowAccount(for: UUID(uuidString: sellerId)!)
        
        // Generate PIN only for service listings
        let verificationPin = listing.listingType == .service ? String(format: "%04d", Int.random(in: 0...9999)) : nil
        
        // Create order with PENDING payment status
        let orderData = OrderInsert(
            listingId: offer.listingId,
            buyerId: UUID(uuidString: buyerId)!,
            sellerId: UUID(uuidString: sellerId)!,
            priceCents: sellerPriceCents,
            sellerPriceCents: sellerPriceCents,
            buyerPriceCents: buyerPriceCents,
            paymentMethod: "card",
            orderStatus: "placed",
            paymentStatus: "pending",  // ✅ UNPAID - buyer needs to complete payment
            createdAt: ISO8601DateFormatter().string(from: Date()),
            updatedAt: ISO8601DateFormatter().string(from: Date()),
            stripeEscrowAccountId: escrowAccountId,
            marketplaceFeeCents: 0,
            stripePaymentIntentId: nil,  // No payment intent yet - will be created when buyer pays
            timeSlotId: nil,
            verificationPin: verificationPin,
            quantity: 1
        )
        
        print("💳 Creating UNPAID order (buyer must pay after acceptance)")
        let order: Order = try await supabase
            .from("orders")
            .insert(orderData)
            .select()
            .single()
            .execute()
            .value
        
        // Update offer status to 'accepted' and link to order
        try await supabase
            .from("offers")
            .update([
                "status": "accepted",
                "order_id": order.id.uuidString
            ])
            .eq("id", value: offerId.uuidString)
            .execute()
        
        // Send notification to buyer that offer was accepted and they need to pay
        let notification = NotificationCreate(
            userId: buyerId,
            type: .marketplaceActivity,
            title: "Offer Accepted!",
            body: "Your offer of \(String(format: "$%.2f", Double(sellerPriceCents) / 100.0)) for \(listing.title) was accepted! Complete payment to proceed.",
            data: [
                "offer_id": AnyCodable(offerId.uuidString),
                "order_id": AnyCodable(order.id.uuidString),
                "listing_id": AnyCodable(listing.id.uuidString)
            ],
            scheduledFor: nil,
            orderId: order.id,
            messageId: nil,
            listingId: listing.id,
            relatedUserId: sellerId
        )
        
        await NotificationService.shared.createNotification(notification)
        
        print("✅ Offer accepted and UNPAID order created: \(order.id)")
        print("💳 Buyer (\(buyerId)) must complete payment for order to proceed")
        
        return order
    }
    
    // MARK: - Reject Offer
    
    /// Reject an offer
    /// - Parameters:
    ///   - offerId: The offer to reject
    ///   - currentUserId: The user rejecting the offer
    func rejectOffer(offerId: UUID, currentUserId: String) async throws {
        print("❌ Rejecting offer: \(offerId)")
        
        // Get the offer
        let offer: Offer = try await supabase
            .from("offers")
            .select()
            .eq("id", value: offerId.uuidString)
            .single()
            .execute()
            .value
        
        // Verify current user is the receiver
        guard offer.getUserRole(currentUserId: currentUserId) == .receiver else {
            throw OfferServiceError.unauthorized
        }
        
        // Update offer status
        try await supabase
            .from("offers")
            .update(["status": "declined"])
            .eq("id", value: offerId.uuidString)
            .execute()
        
        print("✅ Offer rejected")
    }
    
    // MARK: - Get Offers
    
    /// Get all offers for a specific listing
    /// - Parameter listingId: The listing ID
    /// - Returns: Array of offers
    func getOffersForListing(listingId: UUID) async throws -> [Offer] {
        print("📥 Fetching offers for listing: \(listingId)")
        
        let offers: [Offer] = try await supabase
            .from("offers")
            .select()
            .eq("listing_id", value: listingId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        print("✅ Found \(offers.count) offers")
        return offers
    }
    
    /// Get all offers for the current user (sent and received)
    /// - Parameter currentUserId: The current user's ID
    /// - Returns: Tuple of sent and received offers
    func getMyOffers(currentUserId: String) async throws -> (sent: [Offer], received: [Offer]) {
        print("📥 Fetching offers for user: \(currentUserId)")
        
        // Get all ACTIVE offers where user is a participant
        // Exclude declined/withdrawn offers as they're completed and need no action
        let allOffers: [Offer] = try await supabase
            .from("offers")
            .select()
            .or("offer_from_user_id.eq.\(currentUserId),offer_to_user_id.eq.\(currentUserId)")
            .in("status", values: ["pending", "accepted", "countered"])
            .order("created_at", ascending: false)
            .execute()
            .value
        
        // Separate into sent and received
        let sent = allOffers.filter { $0.offerFromUserId.lowercased() == currentUserId.lowercased() }
        let received = allOffers.filter { $0.offerToUserId.lowercased() == currentUserId.lowercased() }
        
        print("✅ Found \(sent.count) sent, \(received.count) received")
        return (sent, received)
    }
    
    /// Get the full negotiation chain for an offer
    /// - Parameter offerId: The offer ID (can be any offer in the chain)
    /// - Returns: Array of offers in chronological order
    func getOfferChain(offerId: UUID) async throws -> [Offer] {
        print("📥 Fetching offer chain for: \(offerId)")
        
        // Get the initial offer
        let offer: Offer = try await supabase
            .from("offers")
            .select()
            .eq("id", value: offerId.uuidString)
            .single()
            .execute()
            .value
        
        // Find the root offer (one with no parent)
        var rootOfferId = offerId
        var currentOffer = offer
        
        while let parentId = currentOffer.parentOfferId {
            rootOfferId = parentId
            currentOffer = try await supabase
                .from("offers")
                .select()
                .eq("id", value: parentId.uuidString)
                .single()
                .execute()
                .value
        }
        
        // Get all offers in the chain
        var chain: [Offer] = [currentOffer]
        var currentId = rootOfferId
        
        // Follow the chain forward
        while true {
            let children: [Offer] = try await supabase
                .from("offers")
                .select()
                .eq("parent_offer_id", value: currentId.uuidString)
                .execute()
                .value
            
            if let child = children.first {
                chain.append(child)
                currentId = child.id
            } else {
                break
            }
        }
        
        print("✅ Found chain of \(chain.count) offers")
        return chain
    }
    
    // MARK: - Validation
    
    /// Check if user can interact with an offer (e.g., accept it)
    /// - Parameters:
    ///   - offerId: The offer ID
    ///   - currentUserId: The current user's ID
    /// - Returns: True if interaction is allowed
    func canInteractWithOffer(offerId: UUID, currentUserId: String) async throws -> Bool {
        let offer: Offer = try await supabase
            .from("offers")
            .select()
            .eq("id", value: offerId.uuidString)
            .single()
            .execute()
            .value
        
        // Check if user is a participant
        guard offer.getUserRole(currentUserId: currentUserId) != .none else {
            return false
        }
        
        // Check if offer is still pending
        guard offer.status == "pending" else {
            return false
        }
        
        // Check if listing has an active order
        let orders: [Order] = try await supabase
            .from("orders")
            .select()
            .eq("listing_id", value: offer.listingId.uuidString)
            .in("order_status", values: ["pending_seller_confirmation", "in_progress"])
            .execute()
            .value
        
        // If there's an active order, check if it's for this offer
        if let activeOrder = orders.first {
            // Can only interact if the active order is linked to this offer
            return activeOrder.id == offer.orderId
        }
        
        return true
    }
}

// MARK: - Offer Service Errors

enum OfferServiceError: LocalizedError {
    case invalidAmount
    case cannotOfferToSelf
    case unauthorized
    case offerNotPending
    case listingNotAvailable
    case activeOrderExists
    
    var errorDescription: String? {
        switch self {
        case .invalidAmount:
            return "Offer amount must be greater than $0"
        case .cannotOfferToSelf:
            return "You cannot make an offer on your own listing"
        case .unauthorized:
            return "You are not authorized to perform this action"
        case .offerNotPending:
            return "This offer is no longer pending"
        case .listingNotAvailable:
            return "This listing is no longer available"
        case .activeOrderExists:
            return "Cannot accept offer while another order is in progress"
        }
    }
}

