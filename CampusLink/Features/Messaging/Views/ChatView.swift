import SwiftUI

struct ChatView: View {
    let conversation: Conversation
    @StateObject private var viewModel: ChatViewModel
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @FocusState private var isTextFieldFocused: Bool
    @State private var showingReportSheet = false
    @State private var showingOfferAcceptance = false
    @State private var selectedOffer: Offer?
    @State private var isProcessingOffer = false
    @State private var offerError: String?
    @State private var showingOrderDetail = false
    @State private var showingListingDetail = false
    @State private var conversationOrder: Order?
    
    init(conversation: Conversation) {
        print("CHATVIEW INIT CALLED") // Simple print
        self.conversation = conversation
        self._viewModel = StateObject(wrappedValue: ChatViewModel(conversation: conversation))
        print("CHATVIEW INIT COMPLETE") // Simple print
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
                ChatSkeleton(messageCount: 8)
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
                HStack {
                    if AppConfig.enableNotifications {
                        Button(action: { testNotification() }) {
                            Image(systemName: "bell.badge").foregroundColor(.blue)
                        }
                    }
                    Button(action: { showingReportSheet = true }) {
                        Image(systemName: "flag").foregroundColor(.facebookBlue)
                    }
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
                    userName: (otherParticipant.name ?? "Unknown User").formattedName,
                    listingId: conversation.listing?.id.uuidString,
                    listingTitle: conversation.listing?.title
                )
                .environmentObject(authManager)
            }
        }
        .sheet(isPresented: $showingOfferAcceptance) {
            if let offer = selectedOffer {
                OfferAcceptanceView(
                    offer: offer,
                    isProcessing: $isProcessingOffer,
                    errorMessage: $offerError,
                    onAccept: acceptOffer,
                    onDecline: declineOffer,
                    onDismiss: { showingOfferAcceptance = false }
                )
            }
        }
        .sheet(isPresented: $showingOrderDetail) {
            if let order = conversationOrder {
                NavigationView {
                    OrderDetailView(order: order)
                        .environmentObject(authManager)
                }
            }
        }
        .sheet(isPresented: $showingListingDetail) {
            if let listingWithUser = conversation.listingWithUser(currentUserId: authManager.session?.user.id.uuidString ?? "") {
                NavigationView {
                    ListingDetailView(listing: listingWithUser)
                        .environmentObject(authManager)
                }
            }
        }
        .hideKeyboardOnTap()
        .onAppear {
            print("CHATVIEW ONAPPEAR CALLED") // Simple print
            print("AUTH SESSION EXISTS: \(authManager.session != nil)")
            if let userId = authManager.session?.user.id.uuidString {
                print("USER ID: \(userId)")
                Task { await viewModel.initialize(userId: userId) }
            } else {
                print("NO USER ID FOUND")
            }
            // Best-effort mark as read when view appears
            Task { await viewModel.markMessagesAsRead() }
            // Load order for this conversation
            Task { await loadConversationOrder() }
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
            
            // Tap to view indicator
            Image(systemName: "chevron.right")
                .font(.caption2)
                .foregroundColor(.secondary)
        }
        .padding(8)
        .background(Color(UIColor.secondarySystemBackground))
        .contentShape(Rectangle())
        .onTapGesture {
            // If there's an order, show order details. Otherwise, show listing details.
            if conversationOrder != nil {
                showingOrderDetail = true
            } else {
                showingListingDetail = true
            }
        }
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
                                MessageBubble(
                                    message: message, 
                                    isFromCurrentUser: true,
                                    onOfferTap: handleOfferTap
                                )
                                .id(message.id)
                            }
                            .padding(.horizontal, 8)
                        } else {
                            // Sender message on the left (with avatar)
                            HStack(alignment: .bottom, spacing: 8) {
                                AvatarView(user: message.sender)
                                MessageBubble(
                                    message: message, 
                                    isFromCurrentUser: false,
                                    onOfferTap: handleOfferTap
                                )
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
                print("SEND BUTTON TAPPED")
                print("MESSAGE TEXT: '\(viewModel.messageText)'")
                print("IS EMPTY: \(viewModel.messageText.isEmpty)")
                print("IS SENDING: \(viewModel.isSending)")
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
    
    private func testNotification() {
        // Test OneSignal push notification
        Task {
            let success = await NotificationManager.shared.sendTestNotification()
            print("🔔 OneSignal test notification sent: \(success)")
        }
    }
    
    private func handleOfferTap(_ offer: Offer) {
        selectedOffer = offer
        showingOfferAcceptance = true
    }
    
    private func acceptOffer() {
        guard let offer = selectedOffer else { return }
        
        isProcessingOffer = true
        offerError = nil
        
        Task {
            do {
                let success = try await OfferService.shared.acceptOfferStatus(offer.id)
                await MainActor.run {
                    isProcessingOffer = false
                    showingOfferAcceptance = false
                    // Navigate to order or show success
                    if success {
                        viewModel.errorMessage = "Offer accepted! Please check your wallet to complete payment."
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingOffer = false
                    offerError = error.localizedDescription
                }
            }
        }
    }
    
    private func declineOffer() {
        guard let offer = selectedOffer else { return }
        
        isProcessingOffer = true
        offerError = nil
        
        Task {
            do {
                try await OfferService.shared.declineOffer(offer.id)
                await MainActor.run {
                    isProcessingOffer = false
                    showingOfferAcceptance = false
                }
            } catch {
                await MainActor.run {
                    isProcessingOffer = false
                    offerError = error.localizedDescription
                }
            }
        }
    }
    
    private func loadConversationOrder() async {
        guard let listingId = conversation.listingId else {
            print("No listing ID for conversation")
            return
        }
        
        do {
            // Query for order with this listing and buyer/seller
            let orders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("listing_id", value: listingId.uuidString)
                .or("buyer_id.eq.\(conversation.buyerId),buyer_id.eq.\(conversation.sellerId)")
                .or("seller_id.eq.\(conversation.buyerId),seller_id.eq.\(conversation.sellerId)")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            if let order = orders.first {
                await MainActor.run {
                    conversationOrder = order
                }
                print("✅ Loaded order for conversation: \(order.id)")
            } else {
                print("No order found for this conversation")
            }
        } catch {
            print("❌ Failed to load conversation order: \(error)")
        }
    }
}

struct MessageBubble: View {
    let message: Message
    let isFromCurrentUser: Bool
    var onOfferTap: ((Offer) -> Void)? = nil
    
    @State private var loadedOffer: Offer?
    @State private var isLoadingOffer = false
    
    private var timeString: String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: message.createdAt)
    }
    
    private var isOfferMessage: Bool {
        message.messageType == "offer_notification" && message.content.contains("💰 New Offer:")
    }
    
    var body: some View {
        VStack(alignment: isFromCurrentUser ? .trailing : .leading, spacing: 4) {
            // Message content
            VStack(alignment: .leading, spacing: 8) {
                Text(message.content)
                    .font(.body)
                    .foregroundColor(isFromCurrentUser ? .primary : .white)
                
                // Add offer action buttons if this is an offer notification
                if isOfferMessage && !isFromCurrentUser {
                    Divider()
                        .background(isFromCurrentUser ? Color.gray.opacity(0.3) : Color.white.opacity(0.3))
                    
                    if isLoadingOffer {
                        HStack {
                            Spacer()
                            ProgressView()
                                .scaleEffect(0.8)
                                .tint(isFromCurrentUser ? .gray : .white)
                            Spacer()
                        }
                        .padding(.vertical, 4)
                    } else if let offer = loadedOffer, offer.status == "pending" {
                        HStack(spacing: 12) {
                            Button(action: {
                                onOfferTap?(offer)
                            }) {
                                Label("Accept", systemImage: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.borderedProminent)
                            .controlSize(.small)
                            
                            Button(action: {
                                // For now, just show decline in the offer acceptance sheet
                                onOfferTap?(offer)
                            }) {
                                Label("View", systemImage: "eye")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                            }
                            .buttonStyle(.bordered)
                            .controlSize(.small)
                        }
                    } else if let offer = loadedOffer {
                        // Show offer status
                        HStack {
                            Image(systemName: offer.status == "accepted" ? "checkmark.circle.fill" : "xmark.circle.fill")
                            Text(offer.status.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                        }
                        .foregroundColor(isFromCurrentUser ? .secondary : .white.opacity(0.8))
                    }
                }
            }
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
        .task {
            if isOfferMessage && !isFromCurrentUser {
                await loadOfferDetails()
            }
        }
    }
    
    private func loadOfferDetails() async {
        isLoadingOffer = true
        loadedOffer = await OfferService.shared.getOfferFromMessage(message)
        isLoadingOffer = false
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
