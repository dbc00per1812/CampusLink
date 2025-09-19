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
        #if DEBUG
        print("🔧 ChatViewModel.initialize() called with userId: \(userId)")
        #endif
        
        self.currentUserId = userId
        
        // Ensure the current user's profile exists to satisfy FK on messages.sender_id
        do {
            #if DEBUG
            print("🔧 Calling ensure_current_user_profile RPC...")
            #endif
            
            struct EmptyParams: Encodable {}
            let result = try await supabase
                .rpc("ensure_current_user_profile", params: EmptyParams())
                .execute()
                
            #if DEBUG
            print("✅ ensure_current_user_profile succeeded")
            #endif
        } catch {
            #if DEBUG
            print("❌ ensure_current_user_profile failed: \(error)")
            print("❌ Error details: \(error.localizedDescription)")
            #endif
        }
        await loadMessages()
        // After loading, try to mark any unread incoming messages as read
        await markMessagesAsRead()
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
            #if DEBUG
            print("Failed to load messages: \(error)")
            #endif
            errorMessage = "Failed to load messages"
            isLoading = false
        }
    }
    
    /// Send a new message
    @MainActor
    func sendMessage() async {
        print("SENDMESSAGE FUNCTION CALLED")
        print("MESSAGE TEXT: '\(messageText)'")
        
        guard !messageText.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { 
            #if DEBUG
            print("❌ Empty message text, aborting")
            #endif
            return 
        }
        
        guard let userId = currentUserId else {
            #if DEBUG
            print("❌ No currentUserId - not authenticated")
            #endif
            errorMessage = "Not authenticated"
            return
        }
        
        #if DEBUG
        print("✅ User ID: \(userId)")
        print("✅ Conversation ID: \(conversation.id.uuidString)")
        print("✅ Conversation buyer_id: \(conversation.buyerId)")
        print("✅ Conversation seller_id: \(conversation.sellerId)")
        #endif
        
        // Check if user is participant
        let isParticipant = conversation.isParticipant(userId: userId)
        #if DEBUG
        print("✅ Is participant check: \(isParticipant)")
        #endif
        
        guard isParticipant else {
            #if DEBUG
            print("❌ User is not a participant in this conversation")
            #endif
            errorMessage = "You are not a participant in this conversation"
            return
        }
        
        let content = messageText.trimmingCharacters(in: .whitespacesAndNewlines)
        messageText = "" // Clear immediately for better UX
        
        #if DEBUG
        print("🔄 Starting message send process...")
        print("Content: '\(content)'")
        #endif
        
        isSending = true
        errorMessage = nil
        
        do {
            let newMessage = [
                "conversation_id": conversation.id.uuidString,
                "sender_id": userId,
                "content": content,
                "message_type": "text"
            ]

            #if DEBUG
            print("📝 Attempting direct INSERT with data: \(newMessage)")
            #endif

            // First, try direct insert (fast path when RLS is configured)
            let createdDirect: Message = try await supabase
                .from("messages")
                .insert(newMessage)
                .select("""
                    *,
                    sender:users!messages_sender_fkey(*)
                """)
                .single()
                .execute()
                .value

            #if DEBUG
            print("✅ Direct INSERT succeeded! Message ID: \(createdDirect.id)")
            #endif

            if !messages.contains(where: { $0.id == createdDirect.id }) {
                messages.append(createdDirect)
            }

            isSending = false

        } catch {
            // If direct insert is blocked (likely RLS), fallback to RPC
            #if DEBUG
            print("Direct insert failed, attempting RPC send_message: \(error)")
            print("Error details: \(error.localizedDescription)")
            if let supabaseError = error as? PostgRESTError {
                print("PostgREST Error: \(supabaseError)")
            }
            #endif
            do {
                let params = [
                    "_conversation_id": conversation.id.uuidString,
                    "_content": content,
                    "_message_type": "text"
                ]
                
                #if DEBUG
                print("📞 Attempting RPC send_message with params: \(params)")
                #endif
                
                // Try original send_message first, then bypass function
                let createdRpc: Message
                do {
                    createdRpc = try await supabase
                        .rpc("send_message", params: params)
                        .execute()
                        .value
                    
                    #if DEBUG
                    print("✅ RPC send_message succeeded! Message ID: \(createdRpc.id)")
                    #endif
                } catch {
                    #if DEBUG
                    print("❌ send_message RPC failed: \(error)")
                    print("❌ Error details: \(error.localizedDescription)")
                    #endif
                    // Fallback to bypass function with different param names
                    let bypassParams = [
                        "conversation_id_param": conversation.id.uuidString,
                        "content_param": content,
                        "message_type_param": "text"
                    ]
                    
                    #if DEBUG
                    print("📞 Trying bypass RPC with params: \(bypassParams)")
                    #endif
                    
                    createdRpc = try await supabase
                        .rpc("send_message_bypass", params: bypassParams)
                        .execute()
                        .value
                        
                    #if DEBUG
                    print("✅ Bypass RPC succeeded! Message ID: \(createdRpc.id)")
                    #endif
                }

                if !messages.contains(where: { $0.id == createdRpc.id }) {
                    messages.append(createdRpc)
                }

                isSending = false
            } catch {
                #if DEBUG
                print("Failed to send message via RPC: \(error)")
                print("RPC Error details: \(error.localizedDescription)")
                if let supabaseError = error as? PostgRESTError {
                    print("PostgREST RPC Error: \(supabaseError)")
                }
                print("Params sent: \(params)")
                print("User ID: \(userId)")
                print("Conversation ID: \(conversation.id.uuidString)")
                print("Is participant: \(conversation.isParticipant(userId: userId))")
                #endif
                var message = Self.mapSendError(error)
                #if DEBUG
                message += "\nDetails: \(error.localizedDescription)"
                #endif
                errorMessage = message
                messageText = content // Restore text so user can retry
                isSending = false
            }
        }
    }
    
    /// Setup realtime subscription for new messages
    @MainActor
    private func setupRealtimeSubscription() async {
        guard let userId = currentUserId else { return }
        
        // Create channel for this conversation
        let channel = supabase.realtimeV2.channel("messages:\(conversation.id.uuidString)")
        
        // Subscribe to INSERT events on messages table for this conversation
        _ = channel.onPostgresChange(
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

                    // If the new message is from the other user, immediately mark as read
                    if newMessage.senderId.lowercased() != userId.lowercased() {
                        await self.markMessagesAsRead()
                    }
                    
                } catch {
                    #if DEBUG
                    print("Failed to parse realtime message: \(error)")
                    #endif
                }
            }
        }

        // Subscribe to UPDATE events to receive read_at changes
        let _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "messages",
            filter: "conversation_id=eq.\(conversation.id.uuidString)"
        ) { [weak self] change in
            Task { @MainActor [weak self] in
                guard let self = self else { return }
                do {
                    let messageData = try JSONEncoder().encode(change.record)
                    let updatedMessage = try JSONDecoder().decode(Message.self, from: messageData)
                    if let index = self.messages.firstIndex(where: { $0.id == updatedMessage.id }) {
                        self.messages[index] = updatedMessage
                    }
                } catch {
                    #if DEBUG
                    print("Failed to parse message update: \(error)")
                    #endif
                }
            }
        }
        
        // Subscribe to the channel
        await channel.subscribe()
        
        // Store reference for cleanup
        self.realtimeChannel = channel
        
        #if DEBUG
        print("✅ Realtime subscription setup for conversation: \(conversation.id)")
        #endif
    }
    
    /// Clean up realtime subscription
    @MainActor
    private func cleanupRealtimeSubscription() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            realtimeChannel = nil
            #if DEBUG
            print("🧹 Cleaned up realtime subscription for conversation: \(conversation.id)")
            #endif
        }
    }
    
    /// Mark messages as read (future implementation)
    func markMessagesAsRead() async {
        guard let userId = currentUserId else { return }
        do {
            // Update all messages in this conversation not sent by me and not yet read
            // Note: requires DB to have read_at column and RLS to allow recipient update
            let now = ISO8601DateFormatter().string(from: Date())
            _ = try await supabase
                .from("messages")
                .update(["read_at": now])
                .eq("conversation_id", value: conversation.id.uuidString)
                .neq("sender_id", value: userId)
                .is("read_at", value: nil)
                .execute()

            // Update local cache
            for i in messages.indices {
                if messages[i].senderId.lowercased() != userId.lowercased() && messages[i].readAt == nil {
                    messages[i].readAt = Date()
                }
            }
        } catch {
            #if DEBUG
            print("Failed to mark messages as read: \(error)")
            #endif
        }
    }

    // MARK: - Error Mapping
    private static func mapSendError(_ error: Error) -> String {
        let raw = error.localizedDescription.lowercased()
        // PostgREST RLS
        if raw.contains("row-level security") || raw.contains("rls") {
            return "You don't have permission to send messages in this conversation."
        }
        // Permission denied / not participant
        if raw.contains("permission") || raw.contains("denied") {
            return "Permission denied to send messages."
        }
        // Foreign key issues (conversation or user missing)
        if raw.contains("foreign key") || raw.contains("violates foreign key") {
            return "Conversation no longer exists or is invalid."
        }
        // Network issues
        if raw.contains("network") || raw.contains("connection") || raw.contains("timeout") {
            return "Network error. Check your connection and try again."
        }
        // Default fallback
        return "Failed to send message"
    }
}
