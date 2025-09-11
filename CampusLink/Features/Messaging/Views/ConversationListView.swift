import SwiftUI

struct ConversationListView: View {
    @StateObject private var viewModel = ConversationListViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedConversation: Conversation?
    @State private var showingChat = false
    
    var body: some View {
        VStack {
            // Title Bar
            HStack {
                Text("Messages")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                Spacer()
                Button(action: {
                    Task {
                        await viewModel.loadConversations()
                    }
                }) {
                    Image(systemName: "arrow.clockwise")
                        .foregroundColor(Color("ThemeColor"))
                }
            }
            .padding(.horizontal)
            .padding(.top)
            
            if viewModel.isLoading && viewModel.conversations.isEmpty {
                Spacer()
                ProgressView("Loading conversations...")
                Spacer()
            } else if viewModel.conversations.isEmpty {
                emptyStateView
            } else {
                conversationsList
            }
        }
        .sheet(item: $selectedConversation) { conversation in
            ChatView(conversation: conversation)
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: {
            Text(viewModel.errorMessage ?? "")
        }
        .onAppear {
            if let userId = authManager.session?.user.id.uuidString {
                Task {
                    await viewModel.initialize(userId: userId)
                }
            }
        }
    }
    
    private var emptyStateView: some View {
        VStack(spacing: 20) {
            Spacer()
            
            Image(systemName: "message.circle")
                .font(.system(size: 60))
                .foregroundColor(.gray)
            
            Text("No Conversations Yet")
                .font(.title2)
                .fontWeight(.semibold)
            
            Text("Start a conversation by contacting a seller about their listing")
                .font(.body)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)
            
            Spacer()
        }
    }
    
    private var conversationsList: some View {
        ScrollView {
            LazyVStack(spacing: 0) {
                ForEach(viewModel.conversations) { conversation in
                    ConversationRow(
                        conversation: conversation,
                        currentUserId: authManager.session?.user.id.uuidString ?? ""
                    )
                    .onTapGesture {
                        selectedConversation = conversation
                    }
                    
                    Divider()
                        .padding(.leading, 76)
                }
            }
        }
        .refreshable {
            await viewModel.refreshConversations()
        }
    }
}

struct ConversationRow: View {
    let conversation: Conversation
    let currentUserId: String
    
    private var otherUser: UserProfile? {
        conversation.otherParticipant(currentUserId: currentUserId)
    }
    
    private var timeString: String {
        let date = conversation.lastMessageAt ?? conversation.createdAt
        
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: date, relativeTo: Date())
    }
    
    var body: some View {
        HStack(spacing: 12) {
            // Profile picture placeholder
            Circle()
                .fill(Color("ThemeColor").opacity(0.2))
                .frame(width: 56, height: 56)
                .overlay(
                    Text(otherUser?.name?.first?.uppercased() ?? "?")
                        .font(.title2)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("ThemeColor"))
                )
            
            VStack(alignment: .leading, spacing: 4) {
                HStack {
                    Text(conversation.displayName(currentUserId: currentUserId))
                        .font(.headline)
                        .lineLimit(1)
                    
                    Spacer()
                    
                    if !timeString.isEmpty {
                        Text(timeString)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                
                HStack(spacing: 6) {
                    Text(conversation.previewText)
                        .lineLimit(2)
                    // Unread dot if the last message exists and is from other user and unread
                    if let last = conversation.lastMessage,
                       last.senderId.lowercased() != currentUserId.lowercased(),
                       last.readAt == nil {
                        Circle()
                            .fill(Color("ThemeColor"))
                            .frame(width: 8, height: 8)
                    }
                }
                .font(.subheadline)
                .foregroundColor(.secondary)
                
                if let listing = conversation.listing {
                    HStack(spacing: 4) {
                        Image(systemName: "tag")
                            .font(.caption2)
                        Text(listing.title)
                            .font(.caption)
                            .lineLimit(1)
                    }
                    .foregroundColor(Color("ThemeColor"))
                }
            }
            
            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundColor(.gray.opacity(0.4))
        }
        .padding(.horizontal)
        .padding(.vertical, 12)
        .contentShape(Rectangle())
    }
}

struct ConversationListView_Previews: PreviewProvider {
    static var previews: some View {
        ConversationListView()
            .environmentObject(AuthManager())
    }
}
