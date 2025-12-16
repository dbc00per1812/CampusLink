import Foundation
import Supabase

// MARK: - Offer Service Parameters
private struct AcceptOfferParams: Encodable {
    let p_offer_id: String
    let p_user_id: String
}

private struct DeclineOfferParams: Encodable {
    let p_offer_id: String
    let p_user_id: String
    let p_reason: String?
}

private struct GetUserOffersParams: Encodable {
    let p_user_id: String
    let p_role: String
}

// MARK: - Offer Service
final class OfferService: ObservableObject {
    static let shared = OfferService()
    private init() {}
    
    // MARK: - Accept Offer (Simplified - just updates status)
    func acceptOfferStatus(_ offerId: UUID) async throws -> Bool {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw OfferError.userNotAuthenticated
        }
        
        // Get offer details before accepting (for notification)
        let offer: Offer = try await supabase
            .from("offers")
            .select("*")
            .eq("id", value: offerId.uuidString)
            .single()
            .execute()
            .value
        
        let params = AcceptOfferParams(
            p_offer_id: offerId.uuidString,
            p_user_id: userId.uuidString
        )
        
        let response = try await supabase
            .rpc("accept_offer", params: params)
            .execute()
        
        // Parse the response
        let data = response.data
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let success = json["success"] as? Bool {
            
            if success {
                // Notify offer maker that their offer was accepted
                let priceFormatted = String(format: "%.2f", Double(offer.priceCents ?? 0) / 100.0)
                await NotificationService.shared.createNotification(
                    NotificationCreate(
                        userId: offer.offerFromUserId,
                        type: .marketplaceActivity,
                        title: "Offer Accepted!",
                        body: "Your offer of $\(priceFormatted) was accepted. Complete payment to proceed.",
                        data: ["offer_id": AnyCodable(offerId.uuidString)],
                        scheduledFor: nil,
                        orderId: nil,
                        messageId: nil,
                        listingId: offer.listingId,
                        relatedUserId: offer.offerToUserId
                    )
                )
                return true
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
        
        // Get offer details before declining (for notification)
        let offer: Offer = try await supabase
            .from("offers")
            .select("*")
            .eq("id", value: offerId.uuidString)
            .single()
            .execute()
            .value
        
        let params = DeclineOfferParams(
            p_offer_id: offerId.uuidString,
            p_user_id: userId.uuidString,
            p_reason: reason
        )
        
        let response = try await supabase
            .rpc("decline_offer", params: params)
            .execute()
        
        // Check if successful
        let data = response.data
        if let json = try? JSONSerialization.jsonObject(with: data, options: []) as? [String: Any],
           let success = json["success"] as? Bool,
           !success {
            let error = json["error"] as? String ?? "Failed to decline offer"
            throw OfferError.serverError(error)
        }
        
        // Notify offer maker that their offer was declined
        let priceFormatted = String(format: "%.2f", Double(offer.priceCents ?? 0) / 100.0)
        let bodyText = reason != nil ? "Your offer of $\(priceFormatted) was declined. Reason: \(reason!)" : "Your offer of $\(priceFormatted) was declined."
        await NotificationService.shared.createNotification(
            NotificationCreate(
                userId: offer.offerFromUserId,
                type: .marketplaceActivity,
                title: "Offer Declined",
                body: bodyText,
                data: ["offer_id": AnyCodable(offerId.uuidString)],
                scheduledFor: nil,
                orderId: nil,
                messageId: nil,
                listingId: offer.listingId,
                relatedUserId: offer.offerToUserId
            )
        )
    }
    
    // MARK: - Get User Offers
    func getUserOffers(role: OfferRole = .both) async throws -> [UserOffer] {
        guard let userId = try? await supabase.auth.session.user.id else {
            throw OfferError.userNotAuthenticated
        }
        
        let params = GetUserOffersParams(
            p_user_id: userId.uuidString,
            p_role: role.rawValue
        )
        
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
                // Fetch conversation details to get the listing ID
                let conversation: Conversation = try await supabase
                    .from("conversations")
                    .select("*")
                    .eq("id", value: message.conversationId.uuidString)
                    .single()
                    .execute()
                    .value
                
                guard let seekListingId = conversation.listingId?.uuidString else { return nil }
                
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
    case invalidOfferData
    
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
        case .invalidOfferData:
            return "Invalid offer data - missing price or listing information"
        }
    }
}

// AcceptOfferResponse no longer needed - using existing order flow

enum OfferRole: String {
    case seeker = "seeker"
    case seller = "seller"
    case both = "both"
}

// OfferData struct no longer needed - simplified to bool return

struct UserOffer: Codable, Identifiable {
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
    
    // Identifiable conformance
    var id: UUID { offerId }
    
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
