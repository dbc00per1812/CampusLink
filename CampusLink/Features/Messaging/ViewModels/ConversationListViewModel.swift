import Foundation
import SwiftUI
import Supabase

@MainActor
class ConversationListViewModel: ObservableObject {
    @Published var conversations: [Conversation] = []
    @Published var isLoading = false
    @Published var errorMessage: String?
    
    private var currentUserId: String?
    
    init() {
        // User ID will be set when view appears
    }
    
    /// Set the current user ID and load conversations
    func initialize(userId: String) async {
        self.currentUserId = userId
        await loadConversations()
    }
    
    /// Load all conversations for the current user
    func loadConversations() async {
        guard let userId = currentUserId else {
            errorMessage = "Not authenticated"
            return
        }
        
        isLoading = true
        errorMessage = nil
        
        do {
            // Fetch conversations where user is either buyer or seller
            let response: [Conversation] = try await supabase
                .from("conversations")
                .select("""
                    *,
                    listing:listings(*),
                    buyer:users!conversations_buyer_fkey(*),
                    seller:users!conversations_seller_fkey(*)
                """)
                .or("buyer_id.eq.\(userId),seller_id.eq.\(userId)")
                .order("last_message_at", ascending: false)
                .execute()
                .value
            
            // Fetch last message for each conversation
            var updatedConversations: [Conversation] = []
            for var conversation in response {
                do {
                    // Get the last message for this conversation
                    let messages: [Message] = try await supabase
                        .from("messages")
                        .select("*")
                        .eq("conversation_id", value: conversation.id.uuidString)
                        .order("created_at", ascending: false)
                        .limit(1)
                        .execute()
                        .value
                    
                    conversation.lastMessage = messages.first
                } catch {
                    // If we can't fetch messages for this conversation, just continue without lastMessage
                    #if DEBUG
                    print("Failed to load messages for conversation \(conversation.id): \(error)")
                    #endif
                }
                updatedConversations.append(conversation)
            }
            
            conversations = updatedConversations
            isLoading = false
            
        } catch {
            #if DEBUG
            print("Failed to load conversations: \(error)")
            #endif
            // Don't show error for refresh - just silently fail and keep existing data
            isLoading = false
        }
    }
    
    /// Refresh conversations silently (for pull-to-refresh)
    func refreshConversations() async {
        guard let userId = currentUserId else { return }
        
        do {
            // Fetch conversations where user is either buyer or seller
            let response: [Conversation] = try await supabase
                .from("conversations")
                .select("""
                    *,
                    listing:listings(*),
                    buyer:users!conversations_buyer_fkey(*),
                    seller:users!conversations_seller_fkey(*)
                """)
                .or("buyer_id.eq.\(userId),seller_id.eq.\(userId)")
                .order("last_message_at", ascending: false)
                .execute()
                .value
            
            // Fetch last message for each conversation
            var updatedConversations: [Conversation] = []
            for var conversation in response {
                do {
                    // Get the last message for this conversation
                    let messages: [Message] = try await supabase
                        .from("messages")
                        .select("*")
                        .eq("conversation_id", value: conversation.id.uuidString)
                        .order("created_at", ascending: false)
                        .limit(1)
                        .execute()
                        .value
                    
                    conversation.lastMessage = messages.first
                } catch {
                    // If we can't fetch messages for this conversation, just continue without lastMessage
                    #if DEBUG
                    print("Failed to load messages for conversation \(conversation.id): \(error)")
                    #endif
                }
                updatedConversations.append(conversation)
            }
            
            conversations = updatedConversations
            
        } catch {
            #if DEBUG
            print("Failed to refresh conversations: \(error)")
            #endif
            // Silently fail for refresh - don't show error
        }
    }
    
    /// Create or find existing conversation for a listing
    func getOrCreateConversation(for listing: ListingWithUser) async -> Conversation? {
        guard let userId = currentUserId else {
            errorMessage = "Not authenticated"
            return nil
        }
        
        // Determine if current user is buyer or seller (case-insensitive compare)
        let isBuyer = listing.user.id.lowercased() != userId.lowercased()
        let buyerId = isBuyer ? userId : listing.user.id
        let sellerId = isBuyer ? listing.user.id : userId
        
        do {
            // Try to call the RPC function if it exists
            let conversation: Conversation = try await supabase.rpc(
                "get_or_create_conversation",
                params: [
                    "p_buyer_id": buyerId,
                    "p_seller_id": sellerId,
                    "p_listing_id": listing.id.uuidString
                ]
            )
            .execute()
            .value
            
            // Reload conversations to include the new one
            await loadConversations()
            
            return conversation
            
        } catch {
            // If RPC doesn't exist, fall back to manual create/find
            #if DEBUG
            print("RPC failed, trying manual approach: \(error)")
            #endif
            
            // First, try to find existing conversation
            do {
                let existing: [Conversation] = try await supabase
                    .from("conversations")
                    .select("*")
                    .eq("buyer_id", value: buyerId)
                    .eq("seller_id", value: sellerId)
                    .eq("listing_id", value: listing.id.uuidString)
                    .limit(1)
                    .execute()
                    .value
                
                if let conversation = existing.first {
                    return conversation
                }
                
                // Create new conversation
                let newConversation = [
                    "buyer_id": buyerId,
                    "seller_id": sellerId,
                    "listing_id": listing.id.uuidString
                ]
                
                let created: Conversation = try await supabase
                    .from("conversations")
                    .insert(newConversation)
                    .select()
                    .single()
                    .execute()
                    .value
                
                // Reload conversations
                await loadConversations()
                
                return created
                
            } catch {
                #if DEBUG
                print("Failed to create/find conversation: \(error)")
                #endif
                errorMessage = "Failed to start conversation"
                return nil
            }
        }
    }
    
    /// Delete a conversation
    func deleteConversation(_ conversation: Conversation) async {
        guard let userId = currentUserId else { return }
        
        // Only allow deletion if user is a participant
        guard conversation.isParticipant(userId: userId) else { return }
        
        do {
            try await supabase
                .from("conversations")
                .delete()
                .eq("id", value: conversation.id.uuidString)
                .execute()
            
            // Remove from local list
            conversations.removeAll { $0.id == conversation.id }
            
        } catch {
            #if DEBUG
            print("Failed to delete conversation: \(error)")
            #endif
            errorMessage = "Failed to delete conversation"
        }
    }
}
