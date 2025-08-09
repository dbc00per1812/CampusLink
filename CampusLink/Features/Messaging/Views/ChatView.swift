import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    
    init(conversation: Conversation) {
        self.conversation = conversation
        self._viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
    }
    
    private var currentUserId: String {
        authManager.session?.user.id.uuidString ?? ""
    }
    
    private var otherUser: UserProfile? {
        conversation.otherParticipant(currentUserId: currentUserId)
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Listing info bar if available
                if let listing = conversation.listing {
                    listingInfoBar(listing: listing)
                }
                
                // Messages list
                if viewModel.isLoading && viewModel.messages.isEmpty {
                    Spacer()
                    ProgressView("Loading messages...")
                    Spacer()
                } else {
                    messagesList
                }
                
                // Message input
                messageInputBar
            }
            .navigationTitle(conversation.displayName(currentUserId: currentUserId))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Close") {
                        dismiss()
                    }
                }
                
                ToolbarItem(placement: .navigationBarTrailing) {
                    if let otherUser = otherUser {
                        HStack(spacing: 8) {
                            Circle()
                                .fill(Color("ThemeColor").opacity(0.2))
                                .frame(width: 32, height: 32)
                                .overlay(
                                    Text(otherUser.name?.first?.uppercased() ?? "?")
                                        .font(.caption)
                                        .fontWeight(.semibold)
                                        .foregroundColor(Color("ThemeColor"))
                                )
                        }
                    }
                }
            }
            .alert("Error", isPresented: .constant(viewModel.errorMessage != nil)) {
                Button("OK") {
                    viewModel.errorMessage = nil
                }
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
    }
    
    private func listingInfoBar(listing: Listing) -> some View {
        HStack(spacing: 12) {
            // Listing photo thumbnail
            if let photoURL = listing.photo, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image
                        .resizable()
                        .aspectRatio(contentMode: .fill)
                } placeholder: {
                    Rectangle()
                        .fill(Color(UIColor.systemGray5))
                }
                .frame(width: 40, height: 40)
                .cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8)
                    .fill(Color(UIColor.systemGray5))
                    .frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title)
                    .font(.caption)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text("$\(listing.price, specifier: "%.2f")")
                    .font(.caption2)
                    .foregroundColor(Color("ThemeColor"))
            }
            
            Spacer()
            
            if listing.isSold {
                Text("SOLD")
                    .font(.caption2)
                    .fontWeight(.bold)
                    .padding(.horizontal, 6)
                    .padding(.vertical, 3)
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(4)
            }
        }
        .padding(.horizontal)
        .padding(.vertical, 8)
        .background(Color(UIColor.systemGray6))
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 12) {
                    ForEach(viewModel.messages) { message in
                        MessageBubble(
                            message: message,
                            isFromCurrentUser: message.isSentByCurrentUser(userId: currentUserId)
                        )
                        .id(message.id)
                    }
                }
                .padding()
            }
            .onAppear {
                scrollToBottom(proxy: proxy)
            }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation {
                    scrollToBottom(proxy: proxy)
                }
            }
        }
    }
    
    private var messageInputBar: some View {
        HStack(spacing: 12) {
            TextField("Type a message...", text: $viewModel.messageText, axis: .vertical)
                .textFieldStyle(RoundedBorderTextFieldStyle())
                .lineLimit(1...4)
                .focused($isTextFieldFocused)
                .disabled(viewModel.isSending)
                .onSubmit {
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            
            Button(action: {
                Task {
                    await viewModel.sendMessage()
                }
            }) {
                if viewModel.isSending {
                    ProgressView()
                        .frame(width: 20, height: 20)
                } else {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundColor(viewModel.messageText.isEmpty ? .gray : Color("ThemeColor"))
                }
            }
            .disabled(viewModel.messageText.isEmpty || viewModel.isSending)
        }
        .padding()
        .background(Color(UIColor.systemBackground))
        .shadow(color: Color.black.opacity(0.05), radius: 1, y: -1)
    }
    
    private func scrollToBottom(proxy: ScrollViewProxy) {
        if let lastMessage = viewModel.messages.last {
            proxy.scrollTo(lastMessage.id, anchor: .bottom)
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.createdAt)
    }
    
    var body: some View {
        HStack {
            if isFromCurrentUser { Spacer() }
            
            VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
                Text(message.content)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .background(
                        RoundedRectangle(cornerRadius: 16)
                            .fill(isFromCurrentUser ? Color("ThemeColor") : Color(UIColor.systemGray5))
                    )
                    .foregroundColor(isFromCurrentUser ? .white : .primary)
                
                Text(timeString)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            .frame(maxWidth: UIScreen.main.bounds.width * 0.7, alignment: isFromCurrentUser ? .trailing : .leading)
            
            if !isFromCurrentUser { Spacer() }
        }
    }
}

struct ChatView_Previews: PreviewProvider {
    static var previews: some View {
        ChatView(conversation: Conversation(
            id: UUID(),
            listingId: UUID(),
            buyerId: "buyer-id",
            sellerId: "seller-id",
            lastMessageAt: Date(),
            createdAt: Date(),
            updatedAt: Date()
        ))
        .environmentObject(AuthManager())
    }
}
