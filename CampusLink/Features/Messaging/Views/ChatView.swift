import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingReportSheet = false
    
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
    
    @ViewBuilder
    var body: some View {
        NavigationView {
            chatContent
        }
    }
    
    @ViewBuilder
    private var chatContent: some View {
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
                Button("Close") { dismiss() }
            }
            ToolbarItem(placement: .navigationBarTrailing) {
                Button(action: { showingReportSheet = true }) {
                    Image(systemName: "flag").foregroundColor(.red)
                }
            }
        }
        .alert(
            "Error",
            isPresented: Binding(
                get: { viewModel.errorMessage != nil },
                set: { if !$0 { viewModel.errorMessage = nil } }
            )
        ) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .sheet(isPresented: $showingReportSheet) {
            if let otherParticipant = conversation.otherParticipant(currentUserId: currentUserId) {
                ReportUserView(
                    userId: otherParticipant.id,
                    userName: otherParticipant.name ?? "Unknown User",
                    listingId: conversation.listing?.id.uuidString,
                    listingTitle: conversation.listing?.title
                )
                .environmentObject(authManager)
            }
        }
        .hideKeyboardOnTap()
        .onAppear {
            #if DEBUG
            print("🟡 ChatView onAppear")
            print("🟡 Auth session exists: \(authManager.session != nil)")
            if let userId = authManager.session?.user.id.uuidString {
                print("🟡 User ID: \(userId)")
            }
            #endif
            if let userId = authManager.session?.user.id.uuidString { Task { await viewModel.initialize(userId: userId) } }
            // Best-effort mark as read when view appears
            Task { await viewModel.markMessagesAsRead() }
        }
    }
    
    private func listingInfoBar(listing: Listing) -> some View {
        HStack(spacing: 12) {
            // Listing photo thumbnail
            if let photoURL = listing.photo, let url = URL(string: photoURL) {
                AsyncImage(url: url) { image in
                    image.resizable().aspectRatio(contentMode: .fill)
                } placeholder: { Rectangle().fill(Color(UIColor.systemGray5)) }
                .frame(width: 40, height: 40).cornerRadius(8)
            } else {
                RoundedRectangle(cornerRadius: 8).fill(Color(UIColor.systemGray5)).frame(width: 40, height: 40)
            }
            
            VStack(alignment: .leading, spacing: 2) {
                Text(listing.title).font(.caption).fontWeight(.medium).lineLimit(1)
                Text("$\((listing.price ?? 0), specifier: "%.2f")").font(.caption2).foregroundColor(.secondary)
            }
            Spacer()
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
    }
    
    private var messagesList: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(spacing: 10) {
                    ForEach(viewModel.messages) { message in
                        let isMe = message.isSentByCurrentUser(userId: currentUserId)
                        if isMe {
                            // Current user message on the right
                            HStack(alignment: .bottom, spacing: 8) {
                                Spacer()
                                MessageBubble(message: message, isFromCurrentUser: true)
                                    .id(message.id)
                            }
                            .padding(.horizontal, 8)
                        } else {
                            // Sender message on the left (with avatar)
                            HStack(alignment: .bottom, spacing: 8) {
                                AvatarView(user: message.sender)
                                MessageBubble(message: message, isFromCurrentUser: false)
                                    .id(message.id)
                                Spacer()
                            }
                            .padding(.horizontal, 8)
                        }
                    }
                }
                .padding(.top, 8)
                .padding(.bottom, 6)
            }
            .onAppear { scrollToBottom(proxy: proxy) }
            .onChange(of: viewModel.messages.count) { _ in
                withAnimation { scrollToBottom(proxy: proxy) }
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
                    #if DEBUG
                    print("🟢 TextField onSubmit triggered!")
                    print("🟢 Message text: '\(viewModel.messageText)'")
                    #endif
                    Task {
                        await viewModel.sendMessage()
                    }
                }
            
            Button(action: {
                #if DEBUG
                print("🔵 Send button tapped!")
                print("🔵 Message text: '\(viewModel.messageText)'")
                print("🔵 Is empty: \(viewModel.messageText.isEmpty)")
                print("🔵 Is sending: \(viewModel.isSending)")
                #endif
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
            .onTapGesture {
                #if DEBUG
                print("🔴 Button tap detected (even if disabled)")
                print("🔴 Message text: '\(viewModel.messageText)'")
                print("🔴 Is disabled: \(viewModel.messageText.isEmpty || viewModel.isSending)")
                #endif
            }
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
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            Text(message.content)
                .font(.body)
                .foregroundColor(isFromCurrentUser ? .primary : .white)
                .padding(.horizontal, 14)
                .padding(.vertical, 10)
                .background(
                    RoundedRectangle(cornerRadius: 18, style: .continuous)
                        .fill(isFromCurrentUser ? Color(UIColor.systemGray5) : Color.blue)
                )
                .frame(maxWidth: UIScreen.main.bounds.width * 0.72, alignment: isFromCurrentUser ? .trailing : .leading)

            HStack(spacing: 6) {
                Text(timeString)
                if isFromCurrentUser, let _ = message.readAt {
                    Text("Seen")
                }
            }
            .font(.caption2)
            .foregroundColor(.secondary)
            .padding(isFromCurrentUser ? .trailing : .leading, 6)
        }
    }
}

// MARK: - Avatar

private struct AvatarView: View {
    let user: UserProfile?
    
    var body: some View {
        ZStack {
            Circle()
                .fill(Color(UIColor.systemGray5))
            if let user = user, let first = user.name?.first?.uppercased() {
                Text(first)
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            } else {
                Text("?")
                    .font(.caption)
                    .fontWeight(.semibold)
                    .foregroundColor(.secondary)
            }
        }
        .frame(width: 28, height: 28)
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
