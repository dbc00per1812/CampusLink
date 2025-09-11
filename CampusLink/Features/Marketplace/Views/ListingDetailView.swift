import SwiftUI

struct ListingDetailView: View {
    let listing: ListingWithUser
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager

    @StateObject private var paymentService = PaymentService.shared
    @StateObject private var conversationViewModel = ConversationListViewModel()
    @StateObject private var orderService = OrderService.shared
    @StateObject private var walletService = WalletService.shared
    @StateObject private var timeSlotService = TimeSlotService.shared

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
    @State private var showDeleteAlert = false
    @State private var isDeleting = false
    @State private var timeSlots: [TimeSlot] = []
    @State private var selectedTimeSlot: TimeSlot?
    @State private var isLoadingTimeSlots = false

    private var isOwnListing: Bool {
        guard let currentUserId = authManager.session?.user.id.uuidString else { 
            print("🔍 No current user ID")
            return false 
        }
        
        // Try case-insensitive comparison since UUIDs might have different casing
        let isOwner = listing.user.id.lowercased() == currentUserId.lowercased()
        
        print("🔍 Current User ID: \(currentUserId)")
        print("🔍 Current User ID (lowercase): \(currentUserId.lowercased())")
        print("🔍 Listing User ID: \(listing.user.id)")
        print("🔍 Listing User ID (lowercase): \(listing.user.id.lowercased())")
        print("🔍 Is Owner: \(isOwner)")
        print("🔍 Auth Session User: \(authManager.session?.user.id.uuidString ?? "nil")")
        
        return isOwner
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
                            if AppConfig.enableSeekMode && listing.intent == .seek {
                                // Show budget for seek posts
                                if let min = listing.budgetMin, let max = listing.budgetMax {
                                    Text("$\(min, specifier: "%.0f") - $\(max, specifier: "%.0f")")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color("ThemeColor"))
                                } else if let max = listing.budgetMax {
                                    Text("Up to $\(max, specifier: "%.0f")")
                                        .font(.title)
                                        .fontWeight(.bold)
                                        .foregroundColor(Color("ThemeColor"))
                                }
                                Text("Budget")
                                    .font(.subheadline)
                                    .foregroundColor(.secondary)
                            } else {
                                // Show price for offer posts
                                Text("$\(listing.price, specifier: "%.2f")")
                                    .font(.title)
                                    .fontWeight(.bold)
                                    .foregroundColor(Color("ThemeColor"))
                                
                                // Always show estimated processing fee
                                VStack(alignment: .trailing, spacing: 2) {
                                    Text("Est. total $\(listing.price + (listing.price * 0.029 + 0.30), specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundColor(.secondary)
                                }
                            }
                        }
                    }
                    
                    // Seller rating summary (Phase 2)
                    if AppConfig.enableRatings {
                        SellerRatingSummaryView(userId: listing.user.id)
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
                if AppConfig.enableSeekMode && listing.intent == .seek && !isOwnListing {
                    // Seek post actions for non-owners
                    VStack(spacing: 12) {
                        Button(action: handleOfferMyItem) {
                            HStack {
                                Image(systemName: "tag.fill")
                                Text("Offer My Item")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("ThemeColor"))
                            .cornerRadius(12)
                        }
                        
                        Button(action: handleContactSeller) {
                            HStack {
                                Image(systemName: "message.fill")
                                Text("Contact Seeker")
                            }
                            .font(.headline)
                            .foregroundColor(Color("ThemeColor"))
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(
                                RoundedRectangle(cornerRadius: 12)
                                    .stroke(Color("ThemeColor"), lineWidth: 2)
                            )
                        }
                    }
                } else if AppConfig.enableSeekMode && listing.intent == .seek && isOwnListing {
                    // Seek post actions for owner
                    VStack(spacing: 12) {
                        Button(action: handleViewOffers) {
                            HStack {
                                Image(systemName: "envelope.badge")
                                Text("View Offers")
                            }
                            .font(.headline)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color("ThemeColor"))
                            .cornerRadius(12)
                        }
                        
                        HStack(spacing: 12) {
                            Button(action: handleEditListing) {
                                Text("Edit")
                                    .font(.headline)
                                    .foregroundColor(Color("ThemeColor"))
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color("ThemeColor"), lineWidth: 2)
                                    )
                            }
                            
                            Button(action: handleDeleteListing) {
                                Text("Delete")
                                    .font(.headline)
                                    .foregroundColor(.red)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(
                                        RoundedRectangle(cornerRadius: 12)
                                            .stroke(Color.red, lineWidth: 2)
                                    )
                            }
                        }
                    }
                } else {
                    // Regular offer post actions
                    ActionButtonRow(
                        listing: listing,
                        isOwnListing: isOwnListing,
                        isContactingLoading: isContactingSeller,
                        isPrimaryActionLoading: isPrimaryActionLoading,
                        onContactSeller: { handleContactSeller() },
                        onPrimaryAction: { handlePrimaryAction() },
                        onEditListing: isOwnListing ? { handleEditListing() } : nil,
                        onDeleteListing: isOwnListing ? { handleDeleteListing() } : nil
                    )
                }

                Spacer(minLength: 100)
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
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
                            Task {
                                await handleContactSellerFromOrder(order)
                            }
                        }
                    }
                )

            case let .chat(conversation):
                ChatView(conversation: conversation)
            case .editListing:
                EditListingView(listing: listing) {
                    // On updated, simply dismiss this detail view to refresh upstream
                    dismiss()
                }
                .environmentObject(authManager)
                
            case .timeSlotSelection:
                TimeSlotSelectionView(
                    listing: listing,
                    timeSlots: timeSlots,
                    onSlotSelected: { slot in
                        selectedTimeSlot = slot
                        activeSheet = nil
                        // After slot selection, show payment method sheet
                        showPaymentMethodSheet = true
                    },
                    onCancel: {
                        activeSheet = nil
                        selectedTimeSlot = nil
                    }
                )
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
        .alert("Delete Listing", isPresented: $showDeleteAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Delete", role: .destructive) {
                Task {
                    await deleteListing()
                }
            }
        } message: {
            Text("Are you sure you want to delete this listing? This action cannot be undone.")
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

    private func handleEditListing() {
        activeSheet = .editListing
    }
    
    private func handleDeleteListing() {
        showDeleteAlert = true
    }
    
    // MARK: - Seek Mode Actions (Phase 2)
    
    private func handleOfferMyItem() {
        // Phase 3: Navigate to OfferComposeView
        print("📦 Offer My Item - Coming Soon!")
    }
    
    private func handleViewOffers() {
        // Phase 3: Navigate to OffersListView
        print("📋 View Offers - Coming Soon!")
    }
    
    private func deleteListing() async {
        guard let userId = authManager.session?.user.id.uuidString else { return }
        
        await MainActor.run {
            isDeleting = true
        }
        
        do {
            // Prefer hard-delete via RPC that cascades related rows
            do {
                let _: Bool = try await supabase
                    .rpc("delete_listing_cascade", params: [
                        "p_listing_id": listing.id.uuidString,
                        "p_user_id": userId
                    ])
                    .execute()
                    .value
            } catch {
                // Fallback to soft-delete if RPC not available yet
                try await supabase
                    .from("listings")
                    .update(["status": "archived"])
                    .eq("id", value: listing.id.uuidString)
                    .eq("user_id", value: userId)
                    .execute()
            }
            
            await MainActor.run {
                isDeleting = false
                // Navigate back to the previous screen
                dismiss()
            }
            
            #if DEBUG
            print("✅ Listing removed (hard or soft) successfully: \(listing.id)")
            #endif
            
        } catch {
            await MainActor.run {
                isDeleting = false
                purchaseError = "Failed to archive listing: \(error.localizedDescription)"
                showErrorAlert = true
            }
            
            #if DEBUG
            print("❌ Failed to delete listing: \(error)")
            #endif
        }
    }

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
    
    private func handleContactSellerFromOrder(_ order: Order) async {
        isContactingSeller = true

        if let userId = authManager.session?.user.id.uuidString {
            await conversationViewModel.initialize(userId: userId)

            if let conversation = await conversationViewModel.getOrCreateConversation(for: listing) {
                await MainActor.run {
                    isContactingSeller = false
                    // Dismiss the purchase confirmation first
                    activeSheet = nil
                    createdOrder = nil
                    selectedPaymentMethod = nil
                    // Then open chat
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
                        activeSheet = .chat(conversation)
                    }
                    #if DEBUG
                    print("✅ Opening chat for order: \(order.id)")
                    #endif
                }
            } else {
                await MainActor.run {
                    isContactingSeller = false
                    purchaseError = "Failed to start conversation. Please try again."
                    showErrorAlert = true
                    #if DEBUG
                    print("❌ Failed to create/find conversation for order: \(order.id)")
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

    private func handlePrimaryAction() {
        let impactFeedback = UIImpactFeedbackGenerator(style: .heavy)
        impactFeedback.impactOccurred()

        if listing.listingType == .product {
            // Show payment method selection for products
            showPaymentMethodSheet = true
        } else if listing.listingType == .service {
            // Check if this is a slot-based service
            if listing.serviceType == .slots {
                // Show time slot selection first
                loadTimeSlots()
                activeSheet = .timeSlotSelection
            } else {
                // Calendar-based service - show payment method selection directly
                showPaymentMethodSheet = true
            }
        }
    }
    
    private func loadTimeSlots() {
        guard listing.serviceType == .slots else { return }
        
        isLoadingTimeSlots = true
        
        Task {
            do {
                let slots = try await timeSlotService.getTimeSlotsForListing(listing.id)
                await MainActor.run {
                    self.timeSlots = slots
                    self.isLoadingTimeSlots = false
                }
            } catch {
                await MainActor.run {
                    self.purchaseError = "Failed to load time slots: \(error.localizedDescription)"
                    self.showErrorAlert = true
                    self.isLoadingTimeSlots = false
                }
            }
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
            paymentMethod: .wallet,
            timeSlotId: selectedTimeSlot?.id
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
        // Use existing Stripe flow for card payments with fee information
        let (baseAmountCents, stripeFeeCents, totalAmountCents) = try await paymentService.configurePaymentSheet(for: listing.id.uuidString)
        
        // Update UI with actual fee information
        await MainActor.run {
            self.processingFeeCents = stripeFeeCents
        }

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
                                        paymentMethod: .card,
                                        timeSlotId: selectedTimeSlot?.id
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
    case editListing
    case timeSlotSelection

    var id: String {
        switch self {
        case let .report(userId, _, listingId, _): return "report:\(userId):\(listingId)"
        case .purchaseConfirmation: return "purchaseConfirmation"
        case let .chat(conversation): return "chat:\(conversation.id)"
        case .editListing: return "editListing"
        case .timeSlotSelection: return "timeSlotSelection"
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
