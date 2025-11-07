import Foundation

// MARK: - Conversation Model

struct Conversation: Codable, Identifiable {
    let id: UUID
    let listingId: UUID?
    let buyerId: String
    let sellerId: String
    var lastMessageAt: Date?
    let createdAt: Date
    var updatedAt: Date?
    
    // Joined data
    var listing: Listing?
    var buyer: UserProfile?
    var seller: UserProfile?
    var lastMessage: Message?
    
    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case buyerId = "buyer_id"
        case sellerId = "seller_id"
        case lastMessageAt = "last_message_at"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case listing
        case buyer
        case seller
        case lastMessage = "last_message"
    }
    
    /// Returns the other participant in the conversation
    func otherParticipant(currentUserId: String) -> UserProfile? {
        let me = currentUserId.lowercased()
        if buyerId.lowercased() == me { return seller }
        if sellerId.lowercased() == me { return buyer }
        return nil
    }
    
    /// Check if user is participant
    func isParticipant(userId: String) -> Bool {
        let me = userId.lowercased()
        return buyerId.lowercased() == me || sellerId.lowercased() == me
    }
}

// MARK: - Message Model

struct Message: Codable, Identifiable {
    let id: UUID
    let conversationId: UUID
    let senderId: String
    let content: String
    let messageType: String?
    let createdAt: Date
    var readAt: Date?
    
    // Joined data
    var sender: UserProfile?
    
    enum CodingKeys: String, CodingKey {
        case id
        case conversationId = "conversation_id"
        case senderId = "sender_id"
        case content
        case messageType = "message_type"
        case createdAt = "created_at"
        case readAt = "read_at"
        case sender
    }
    
    /// Check if message was sent by current user (case-insensitive id compare)
    func isSentByCurrentUser(userId: String) -> Bool {
        return senderId.lowercased() == userId.lowercased()
    }
}

// MARK: - Helper Extensions

extension Conversation {
    /// Display name for the conversation (other participant's name or fallback)
    func displayName(currentUserId: String) -> String {
        if let other = otherParticipant(currentUserId: currentUserId) {
            return (other.name ?? other.email ?? "Unknown User").formattedName
        }
        return "Conversation"
    }
    
    /// Preview text for conversation list
    var previewText: String {
        if let lastMessage = lastMessage {
            return lastMessage.content
        }
        if let listing = listing {
            return "About: \(listing.title)"
        }
        return "No messages yet"
    }
    
    /// Convert Listing to ListingWithUser using the seller information
    func listingWithUser(currentUserId: String) -> ListingWithUser? {
        guard let listing = listing, let sellerUser = seller else { return nil }
        
        return ListingWithUser(
            id: listing.id ?? UUID(),
            title: listing.title,
            description: listing.description,
            price: listing.price,
            category: listing.category,
            photo: listing.photo,
            photos: listing.photos,
            isSold: false,
            listingType: listing.listingType,
            serviceDuration: listing.serviceDuration,
            serviceLocation: listing.serviceLocation,
            serviceAvailability: listing.serviceAvailability,
            archived: listing.archived,
            createdAt: Date(),
            user: sellerUser,
            intent: listing.intent,
            budgetMin: listing.budgetMin,
            budgetMax: listing.budgetMax,
            expiresAt: listing.expiresAt,
            deliveryMethod: listing.deliveryMethod,
            quantityAvailable: listing.quantityAvailable,
            quantitySold: nil
        )
    }
}
