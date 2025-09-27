import Foundation
import Supabase

// MARK: - Offer Service
final class OfferService: ObservableObject {
    static let shared = OfferService()
    private init() {}
    
    // MARK: - Accept Offer
    func acceptOffer(_ offerId: UUID) async throws -> AcceptOfferResponse {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw OfferError.userNotAuthenticated
        }
        
        let params: [String: Any] = [
            "p_offer_id": offerId.uuidString,
            "p_user_id": userId.uuidString
        ]
        
        let response = try await supabase
            .rpc("accept_offer", params: params)
            .execute()
        
        // Parse the response
        if let data = response.data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool {
            
            if success {
                guard let orderId = json["order_id"] as? String,
                      let orderUuid = UUID(uuidString: orderId),
                      let conversationId = json["conversation_id"] as? String,
                      let conversationUuid = UUID(uuidString: conversationId),
                      let priceCents = json["price_cents"] as? Int else {
                    throw OfferError.invalidResponse
                }
                
                return AcceptOfferResponse(
                    success: true,
                    orderId: orderUuid,
                    conversationId: conversationUuid,
                    priceCents: priceCents
                )
            } else {
                let error = json["error"] as? String ?? "Unknown error"
                throw OfferError.serverError(error)
            }
        }
        
        throw OfferError.invalidResponse
    }
    
    // MARK: - Decline Offer
    func declineOffer(_ offerId: UUID, reason: String? = nil) async throws {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw OfferError.userNotAuthenticated
        }
        
        var params: [String: Any] = [
            "p_offer_id": offerId.uuidString,
            "p_user_id": userId.uuidString
        ]
        
        if let reason = reason {
            params["p_reason"] = reason
        }
        
        let response = try await supabase
            .rpc("decline_offer", params: params)
            .execute()
        
        // Check if successful
        if let data = response.data,
           let json = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
           let success = json["success"] as? Bool,
           !success {
            let error = json["error"] as? String ?? "Failed to decline offer"
            throw OfferError.serverError(error)
        }
    }
    
    // MARK: - Get User Offers
    func getUserOffers(role: OfferRole = .both) async throws -> [UserOffer] {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw OfferError.userNotAuthenticated
        }
        
        let params: [String: Any] = [
            "p_user_id": userId.uuidString,
            "p_role": role.rawValue
        ]
        
        let response = try await supabase
            .rpc("get_user_offers", params: params)
            .execute()
        
        let offers = try JSONDecoder().decode([UserOffer].self, from: response.data)
        return offers
    }
    
    // MARK: - Get Offers for Listing
    func getOffersForListing(_ listingId: UUID) async throws -> [Offer] {
        let offers: [Offer] = try await supabase
            .from("offers")
            .select("*")
            .eq("seek_listing_id", value: listingId.uuidString)
            .order("created_at", ascending: false)
            .execute()
            .value
        
        return offers
    }
    
    // MARK: - Check if Offer Exists for Message
    func getOfferFromMessage(_ message: Message) async -> Offer? {
        // Check if this is an offer notification message
        guard message.messageType == "offer_notification" else { return nil }
        
        // Extract offer details from message content
        // The message format includes the offer amount
        if let match = message.content.firstMatch(of: /💰 New Offer: \$([0-9.]+)/) {
            // Try to find the offer
            do {
                // First get the conversation if not included in message
                var listingId: String?
                if let conversationListingId = message.conversation?.listingId {
                    listingId = conversationListingId.uuidString
                } else {
                    // Fetch conversation details
                    let conversations: [Conversation] = try await supabase
                        .from("conversations")
                        .select("*")
                        .eq("id", value: message.conversationId.uuidString)
                        .single()
                        .execute()
                        .value
                    
                    if let conversation = conversations.first {
                        listingId = conversation.listingId?.uuidString
                    }
                }
                
                guard let seekListingId = listingId else { return nil }
                
                let offers: [Offer] = try await supabase
                    .from("offers")
                    .select("*")
                    .eq("seek_listing_id", value: seekListingId)
                    .eq("seller_id", value: message.senderId)
                    .eq("status", value: "pending")
                    .order("created_at", ascending: false)
                    .limit(1)
                    .execute()
                    .value
                
                return offers.first
            } catch {
                print("Failed to fetch offer from message: \(error)")
                return nil
            }
        }
        
        return nil
    }
}

// MARK: - Supporting Types
enum OfferError: LocalizedError {
    case userNotAuthenticated
    case invalidResponse
    case serverError(String)
    case offerNotFound
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "You must be logged in to manage offers"
        case .invalidResponse:
            return "Invalid response from server"
        case .serverError(let message):
            return message
        case .offerNotFound:
            return "Offer not found"
        }
    }
}

struct AcceptOfferResponse {
    let success: Bool
    let orderId: UUID
    let conversationId: UUID
    let priceCents: Int
    
    var price: Double {
        Double(priceCents) / 100.0
    }
}

enum OfferRole: String {
    case seeker = "seeker"
    case seller = "seller"
    case both = "both"
}

struct UserOffer: Codable {
    let offerId: UUID
    let seekListingId: UUID
    let seekListingTitle: String
    let offerListingId: UUID?
    let offerListingTitle: String?
    let seekerId: String
    let seekerName: String
    let sellerId: String
    let sellerName: String
    let priceCents: Int?
    let formattedPrice: String?
    let message: String?
    let status: String
    let createdAt: Date
    let updatedAt: Date
    let isSeeker: Bool
    let canAccept: Bool
    
    enum CodingKeys: String, CodingKey {
        case offerId = "offer_id"
        case seekListingId = "seek_listing_id"
        case seekListingTitle = "seek_listing_title"
        case offerListingId = "offer_listing_id"
        case offerListingTitle = "offer_listing_title"
        case seekerId = "seeker_id"
        case seekerName = "seeker_name"
        case sellerId = "seller_id"
        case sellerName = "seller_name"
        case priceCents = "price_cents"
        case formattedPrice = "formatted_price"
        case message
        case status
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case isSeeker = "is_seeker"
        case canAccept = "can_accept"
    }
}
