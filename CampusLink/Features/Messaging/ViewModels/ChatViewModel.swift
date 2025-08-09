import Foundation
import SwiftUI
import Supabase
import Realtime

class ChatViewModel: ObservableObject {
    @Published var messages: [Message] = []
    @Published var isLoading = false
    @Published var isSending = false
    @Published var errorMessage: String?
    @Published var messageText = ""
    
    let conversation: Conversation
    private var currentUserId: String?
    private var realtimeChannel: RealtimeChannelV2?
    
    init(conversation: Conversation) {
        self.conversation = conversation
    }
    
    /// Initialize with user ID and load data
    @MainActor
    func initialize(userId: String) async {
        self.currentUserId = userId
        await loadMessages()
        await setupRealtimeSubscription()
    }
    
    deinit {
        // Clean up realtime subscription
        Task { [weak realtimeChannel] in
            if let channel = realtimeChannel {
                await channel.unsubscribe()
            }
        }
    }
    
    /// Load messages for the conversation
    @MainActor
    func loadMessages() async {
        isLoading = true
        errorMessage = nil
        
        do {
            let response: [Message] = try await supabase
                .from("messages")
                .select("""
                    *,
                    sender:users!messages_sender_fkey(*)
                """)
                .eq("conversation_id", value: conversation.id.uuidString)
                .order("created_at", ascending: true)
                .execute()
                .value
            
            messages = response
            isLoading = false
            
        } catch {
            print("Failed to load messages: \(error)")
            errorMessage = "Failed to load messages"
            isLoading = false
        }
    }
    
    /// Send a new message
    @MainActor
    func sendMessage() async {
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return }
        guard let userId = currentUserId else {
            errorMessage = "Not authenticated"
            return
        }
        
        // Check if user is participant
        guard conversation.isParticipant(userId: userId) else {
            errorMessage = "You are not a participant in this conversation"
            return
        }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = "" // Clear immediately for better UX
        
        isSending = true
        errorMessage = nil
        
        do {
            let newMessage = [
                "conversation_id": conversation.id.uuidString,
                "sender_id": userId,
                "content": content,
                "message_type": "text"
            ]
            
            let created: Message = try await supabase
                .from("messages")
                .insert(newMessage)
                .select("""
                    *,
                    sender:users!messages_sender_fkey(*)
                """)
                .single()
                .execute()
                .value
            
            // Add to local messages (realtime will also add it, but this is faster)
            if !messages.contains(where: { $0.id == created.id }) {
                messages.append(created)
            }
            
            isSending = false
            
        } catch {
            print("Failed to send message: \(error)")
            errorMessage = "Failed to send message"
            messageText = content // Restore text so user can retry
            isSending = false
        }
    }
    
    /// Setup realtime subscription for new messages
    @MainActor
    private func setupRealtimeSubscription() async {
        guard let userId = currentUserId else { return }
        
        // Create channel for this conversation
        let channel = supabase.realtimeV2.channel("messages:\(conversation.id.uuidString)")
        
        // Subscribe to INSERT events on messages table for this conversation
        let subscription = channel.onPostgresChange(
            InsertAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversation.id.uuidString)"
        ) { [weak self] change in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                
                // Parse the new message from payload
                do {
                    let messageData = try JSONEncoder().encode(change.record)
                    var newMessage = try JSONDecoder().decode(Message.self, from: messageData)
                    
                    // Fetch sender info if not included
                    if newMessage.sender == nil {
                        let senderResponse: [UserProfile] = try await supabase
                            .from("users")
                            .select("*")
                            .eq("id", value: newMessage.senderId)
                            .limit(1)
                            .execute()
                            .value
                        
                        newMessage.sender = senderResponse.first
                    }
                    
                    // Add to messages if not already present
                    if !self.messages.contains(where: { $0.id == newMessage.id }) {
                        self.messages.append(newMessage)
                        
                        // Sort by created date to maintain order
                        self.messages.sort { $0.createdAt < $1.createdAt }
                    }
                    
                } catch {
                    print("Failed to parse realtime message: \(error)")
                }
            }
        }
        
        // Subscribe to the channel
        await channel.subscribe()
        
        // Store reference for cleanup
        self.realtimeChannel = channel
        
        print("✅ Realtime subscription setup for conversation: \(conversation.id)")
    }
    
    /// Clean up realtime subscription
    @MainActor
    private func cleanupRealtimeSubscription() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
            print("🧹 Cleaned up realtime subscription for conversation: \(conversation.id)")
        }
    }
    
    /// Mark messages as read (future implementation)
    func markMessagesAsRead() async {
        // Future: Update read_at timestamp for messages
        // This would require adding read tracking to the schema
    }
}
