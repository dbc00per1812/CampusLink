import SwiftUI

struct ListingDetailView: View {
    let listing: ListingWithUser
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @StateObject private var paymentService = PaymentService.shared
    @StateObject private var conversationViewModel = ConversationListViewModel()
    @StateObject private var orderService = OrderService.shared
    @StateObject private var walletService = WalletService.shared

    @State private var isContactingSeller = false
    @State private var isPrimaryActionLoading = false
    @State private var purchaseError: String?
    @State private var showErrorAlert = false
    @State private var activeSheet: ActiveSheet?
    @State private var showPaymentMethodSheet = false
    @State private var currentWallet: Wallet?
    @State private var isWalletLoading = false
    @State private var createdOrder: Order?
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var processingFeeCents: Int = 0

    private var isOwnListing: Bool {
        guard let currentUserId = authManager.session?.user.id.uuidString else { return false }
        return listing.user.id == currentUserId
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                // Large Photo Section
                if let photoURL = listing.photo, let url = URL(string: photoURL) {
                    AsyncImage(url: url) { image in
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                    } placeholder: {
                        Rectangle()
                            .fill(Color(UIColor.systemGray5))
                            .overlay(ProgressView())
                    }
                    .frame(height: 300)
                    .frame(maxWidth: .infinity)
                    .clipped()
                    .cornerRadius(16)
                } else {
                    Rectangle()
                        .fill(Color(UIColor.systemGray6))
                        .frame(height: 300)
                        .overlay(
                            VStack {
                                Image(systemName: "photo")
                                    .font(.system(size: 60))
                                    .foregroundColor(.gray)
                                Text("No Photo")
                                    .font(.headline)
                                    .foregroundColor(.gray)
                            }
                        )
                        .cornerRadius(16)
                }

                // Title and Price
                VStack(alignment: .leading, spacing: 8) {
                    HStack(alignment: .top) {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.title)
                                .font(.title)
                                .fontWeight(.bold)
                                .lineLimit(3)

                            HStack {
                                Text(listing.category)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(Color("ThemeColor").opacity(0.2))
                                    .foregroundColor(Color("ThemeColor"))
                                    .cornerRadius(8)

                                Text(listing.listingType.displayName)
                                    .font(.subheadline)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(listing.listingType == .product ? Color.blue.opacity(0.2) : Color.green.opacity(0.2))
                                    .foregroundColor(listing.listingType == .product ? .blue : .green)
                                    .cornerRadius(8)
                            }
                        }

                        Spacer()

                        VStack(alignment: .trailing) {
                            Text("$\(listing.price, specifier: "%.2f")")
                                .font(.title)
                                .fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                            
                            // Show processing fee if available
                            if processingFeeCents > 0 {
                                let feeAmount = Double(processingFeeCents) / 100.0
                                Text("+ $\(feeAmount, specifier: "%.2f") processing")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }

                            if listing.isSold {
                                Text("SOLD")
                                    .font(.caption)
                                    .fontWeight(.bold)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 4)
                                    .background(Color.red)
                                    .foregroundColor(.white)
                                    .cornerRadius(6)
                            }
                        }
                    }
                }

                // Service-Specific
                if listing.listingType == .service {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Service Details")
                            .font(.headline)
                            .foregroundColor(.primary)

                        VStack(spacing: 8) {
                            if let duration = listing.serviceDuration, !duration.isEmpty {
                                ServiceDetailRow(title: "Duration", value: duration, icon: "clock")
                            }
                            if let location = listing.serviceLocation {
                                ServiceDetailRow(title: "Location", value: location.displayName, icon: "location")
                            }
                            if let availability = listing.serviceAvailability, !availability.isEmpty {
                                ServiceDetailRow(title: "Availability", value: availability, icon: "calendar")
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }

                // Description
                VStack(alignment: .leading, spacing: 8) {
                    Text("Description")
                        .font(.headline)
                        .foregroundColor(.primary)

                    Text(listing.description)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineSpacing(4)
                }

                // Seller Info
                VStack(alignment: .leading, spacing: 12) {
                    Text("Seller Information")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack(spacing: 12) {
                        Circle()
                            .fill(Color("ThemeColor").opacity(0.2))
                            .frame(width: 50, height: 50)
                            .overlay(
                                Text((listing.user.name?.first?.uppercased()) ?? "?")
                                    .font(.title2)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("ThemeColor"))
                            )

                        VStack(alignment: .leading, spacing: 4) {
                            Text(listing.user.name ?? "Unknown Seller")
                                .font(.headline)
                                .foregroundColor(.primary)

                            Text(listing.user.email ?? "")
                                .font(.subheadline)
                                .foregroundColor(.secondary)

                            Text("Member since \(formatDate(listing.createdAt))")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        Spacer()
                    }
                    .padding()
                    .background(Color(UIColor.systemGray6))
                    .cornerRadius(12)
                }

                // Listing Details
                VStack(alignment: .leading, spacing: 8) {
                    Text("Listing Details")
                        .font(.headline)
                        .foregroundColor(.primary)

                    HStack {
                        Text("Posted:")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        Spacer()
                        Text(formatDate(listing.createdAt))
                            .font(.subheadline)
                            .foregroundColor(.primary)
                    }
                }
                .padding()
                .background(Color(UIColor.systemGray6))
                .cornerRadius(12)

                // Actions
                ActionButtonRow(
                    listing: listing,
                    isOwnListing: isOwnListing,
                    isContactingLoading: isContactingSeller,
                    isPrimaryActionLoading: isPrimaryActionLoading,
                    onContactSeller: { handleContactSeller() },
                    onPrimaryAction: { handlePrimaryAction() }
                )

                Spacer(minLength: 100)
            }
            .padding()
        }
        .navigationBarTitleDisplayMode(.inline)
        .navigationBarBackButtonHidden(false)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                HStack(spacing: 16) {
                    if !isOwnListing {
                        Button {
                            activeSheet = .report(
                                userId: listing.user.id,
                                userName: listing.user.name ?? "Unknown User",
                                listingId: listing.id.uuidString,
                                listingTitle: listing.title
                            )
                        } label: {
                            Image(systemName: "flag").foregroundColor(.red)
                        }
                    }

                    Button("Done") { dismiss() }
                }
            }
        }

        // Single sheet router
        .sheet(item: $activeSheet, onDismiss: sheetDidDismiss) { sheet in
            switch sheet {
            case let .report(userId, userName, listingId, listingTitle):
                ReportUserView(
                    userId: userId,
                    userName: userName,
                    listingId: listingId,
                    listingTitle: listingTitle
                )
                .environmentObject(authManager)

            case .purchaseConfirmation:
                PurchaseConfirmationView(
                    listing: listing,
                    order: createdOrder,
                    paymentMethod: selectedPaymentMethod ?? .card,
                    onDismiss: {
                        activeSheet = nil
                        createdOrder = nil
                        selectedPaymentMethod = nil
                        // Clear Stripe state
                        paymentService.paymentResult = nil
                        paymentService.paymentSheet = nil
                        dismiss()
                    },
                    onViewOrder: {
                        // Navigate to order details
                        if let order = createdOrder {
                            // TODO: Navigate to order details
                            #if DEBUG
                            print("📱 Navigate to order details: \(order.id)")
                            #endif
                        }
                    },
                    onContactSeller: {
                        // Navigate to chat with seller
                        if let order = createdOrder {
                            // TODO: Navigate to chat
                            #if DEBUG
                            print("📱 Navigate to chat for order: \(order.id)")
                            #endif
                        }
                    }
                )

            case let .chat(conversation):
                ChatView(conversation: conversation)
            }
        }

        .sheet(isPresented: $showPaymentMethodSheet) {
            PaymentMethodSheet(
                listing: listing,
                wallet: currentWallet,
                onPaymentMethodSelected: { paymentMethod in
                    showPaymentMethodSheet = false
                    handlePaymentMethodSelection(paymentMethod)
                }
            )
        }

        .alert("Payment Error", isPresented: $showErrorAlert) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "An unknown error occurred")
        }

        .onAppear {
            // Clear any stale payment state when view appears
            paymentService.paymentResult = nil
            paymentService.paymentSheet = nil
            activeSheet = nil  // Ensure no sheet is shown on appear
            
            // Load wallet balance for payment method selection
            if !isOwnListing && listing.listingType == .product {
                loadWalletBalance()
            }
        }
        .onDisappear {
            // Clear to prevent re-triggering elsewhere
            paymentService.paymentResult = nil
            paymentService.paymentSheet = nil
            activeSheet = nil  // Clear sheet state
        }
    }

    // MARK: - Helpers

    private func sheetDidDismiss() {
        // Safety: ensure Stripe state is cleared whenever any sheet goes away
        paymentService.paymentResult = nil
        paymentService.paymentSheet = nil
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateStyle = .medium
        formatter.timeStyle = .none
        return formatter.string(from: date)
    }

    private func loadWalletBalance() {
        guard let currentUserId = authManager.session?.user.id else { return }
        
        isWalletLoading = true
        Task {
            do {
                let wallet = try await walletService.fetchBalance()
                await MainActor.run {
                    currentWallet = wallet
                    isWalletLoading = false
                }
            } catch {
                await MainActor.run {
                    isWalletLoading = false
                    #if DEBUG
                    print("❌ Failed to load wallet balance: \(error)")
                    #endif
                }
            }
        }
    }

    private func handleContactSeller() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()

        isContactingSeller = true

        Task {
            if let userId = authManager.session?.user.id.uuidString {
                await conversationViewModel.initialize(userId: userId)

                if let conversation = await conversationViewModel.getOrCreateConversation(for: listing) {
                    await MainActor.run {
                        isContactingSeller = false
                        activeSheet = .chat(conversation)
                        #if DEBUG
                        print("✅ Opening chat for listing: \(listing.title)")
                        #endif
                    }
                } else {
                    await MainActor.run {
                        isContactingSeller = false
                        purchaseError = "Failed to start conversation. Please try again."
                        showErrorAlert = true
                        #if DEBUG
                        print("❌ Failed to create/find conversation for listing: \(listing.title)")
                        #endif
                    }
                }
            } else {
                await MainActor.run {
                    isContactingSeller = false
                    purchaseError = "You must be logged in to contact the seller."
                    showErrorAlert = true
                }
            }
        }
    }

    private func handlePrimaryAction() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        if listing.listingType == .product {
            // Show payment method selection instead of direct Stripe payment
            showPaymentMethodSheet = true
        } else {
            // Service booking - show payment method selection
            showPaymentMethodSheet = true
        }
    }

    private func handlePaymentMethodSelection(_ paymentMethod: PaymentMethod) {
        isPrimaryActionLoading = true
        
        Task {
            do {
                switch paymentMethod {
                case .wallet:
                    try await handleWalletPayment()
                case .card:
                    try await handleCardPayment()
                }
            } catch {
                await MainActor.run {
                    isPrimaryActionLoading = false
                    purchaseError = error.localizedDescription
                    showErrorAlert = true
                    #if DEBUG
                    print("❌ Payment method selection failed: \(error)")
                    #endif
                }
            }
        }
    }

    private func handleWalletPayment() async throws {
        guard let currentUserId = authManager.session?.user.id else {
            throw PaymentError.userNotAuthenticated
        }
        
        guard let wallet = currentWallet else {
            throw PaymentError.walletNotLoaded
        }
        
        let priceCents = Int(listing.price * 100)
        guard wallet.availableCents >= priceCents else {
            throw PaymentError.insufficientFunds
        }
        
        // Wallet payments have no processing fees
        await MainActor.run {
            self.processingFeeCents = 0
        }
        
        // Create order with wallet payment
        let orderCreate = OrderCreate(
            listingId: listing.id,
            buyerId: currentUserId,
            sellerId: UUID(uuidString: listing.user.id) ?? UUID(),
            priceCents: priceCents,
            paymentMethod: .wallet
        )
        
        let order = try await orderService.createOrder(orderCreate)
        
        await MainActor.run {
            isPrimaryActionLoading = false
            createdOrder = order
            selectedPaymentMethod = .wallet
            // Show order confirmation
            activeSheet = .purchaseConfirmation
        }
        
        #if DEBUG
        print("✅ Wallet payment order created: \(order.id)")
        #endif
    }

    private func handleCardPayment() async throws {
        // Use existing Stripe flow for card payments
        try await paymentService.configurePaymentSheet(for: listing.id.uuidString)

        await MainActor.run {
            isPrimaryActionLoading = false

            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootVC = windowScene.windows.first?.rootViewController {
                
                // Present the payment sheet
                paymentService.presentPaymentSheet(from: rootVC)
                
                // Set up a timer to check for payment result
                Task { @MainActor in
                    // Wait for payment result with timeout
                    var attempts = 0
                    while attempts < 60 { // 30 second timeout
                        if let paymentResult = paymentService.paymentResult {
                            switch paymentResult {
                            case .completed:
                                // Create order after successful payment
                                do {
                                    guard let currentUserId = authManager.session?.user.id else {
                                        throw PaymentError.userNotAuthenticated
                                    }
                                    
                                    // Calculate Stripe processing fees
                                    let basePriceCents = Int(listing.price * 100)
                                    let processingFeeCents = paymentService.calculateProcessingFee(amountCents: basePriceCents)
                                    
                                    // Update UI with processing fee
                                    await MainActor.run {
                                        self.processingFeeCents = processingFeeCents
                                    }
                                    
                                    let orderCreate = OrderCreate(
                                        listingId: listing.id,
                                        buyerId: currentUserId,
                                        sellerId: UUID(uuidString: listing.user.id) ?? UUID(),
                                        priceCents: basePriceCents,
                                        paymentMethod: .card
                                    )
                                    
                                    let order = try await orderService.createOrder(orderCreate)
                                    
                                    await MainActor.run {
                                        createdOrder = order
                                        selectedPaymentMethod = .card
                                        activeSheet = .purchaseConfirmation
                                    }
                                    
                                    #if DEBUG
                                    print("✅ Card payment order created: \(order.id)")
                                    #endif
                                    return
                                } catch {
                                    await MainActor.run {
                                        purchaseError = "Payment succeeded but order creation failed: \(error.localizedDescription)"
                                        showErrorAlert = true
                                    }
                                    #if DEBUG
                                    print("❌ Order creation failed after payment: \(error)")
                                    #endif
                                    return
                                }
                            case .canceled:
                                #if DEBUG
                                print("⚠️ Payment canceled by user")
                                #endif
                                return
                            case .failed(let error):
                                await MainActor.run {
                                    purchaseError = "Payment failed: \(error.localizedDescription)"
                                    showErrorAlert = true
                                }
                                #if DEBUG
                                print("❌ Payment failed: \(error)")
                                #endif
                                return
                            }
                        }
                        
                        try? await Task.sleep(nanoseconds: 500_000_000) // Wait 0.5 seconds
                        attempts += 1
                    }
                    
                    // Timeout - payment didn't complete
                    await MainActor.run {
                        purchaseError = "Payment timed out. Please try again."
                        showErrorAlert = true
                    }
                }
            }
        }
    }


}

// MARK: - Payment Errors

enum PaymentError: Error, LocalizedError {
    case userNotAuthenticated
    case walletNotLoaded
    case insufficientFunds
    case orderCreationFailed
    
    var errorDescription: String? {
        switch self {
        case .userNotAuthenticated:
            return "You must be logged in to make a purchase."
        case .walletNotLoaded:
            return "Unable to load wallet information. Please try again."
        case .insufficientFunds:
            return "Insufficient funds in your wallet. Please add funds or choose a different payment method."
        case .orderCreationFailed:
            return "Failed to create order. Please try again."
        }
    }
}

// MARK: - Sheet Router

enum ActiveSheet: Identifiable {
    case report(userId: String, userName: String, listingId: String, listingTitle: String)
    case purchaseConfirmation
    case chat(Conversation)

    var id: String {
        switch self {
        case let .report(userId, _, listingId, _): return "report:\(userId):\(listingId)"
        case .purchaseConfirmation: return "purchaseConfirmation"
        case let .chat(conversation): return "chat:\(conversation.id)"
        }
    }
}

// MARK: - Support Views

struct ServiceDetailRow: View {
    let title: String
    let value: String
    let icon: String

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color("ThemeColor"))
                .frame(width: 20)

            Text(title + ":")
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(.secondary)

            Spacer()

            Text(value)
                .font(.subheadline)
                .foregroundColor(.primary)
        }
    }
}
