import SwiftUI
import Supabase
import StripePaymentSheet

struct OffersListView: View {
    let seekListing: ListingWithUser
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var offers: [Offer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showPaymentMethodSheet = false
    @State private var selectedOffer: Offer?
    @State private var currentWallet: Wallet?
    @State private var createdOrder: Order?
    @State private var activeSheet: OfferSheet?
    @State private var isPrimaryActionLoading = false
    @State private var processingFeeCents: Int = 0
    @State private var showErrorAlert = false
    @State private var purchaseError: String?
    @State private var selectedOrderId: UUID?
    @State private var showOrderDetail = false
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var paymentSheet: PaymentSheet?
    @State private var paymentResult: PaymentSheetResult?
    @State private var currentPaymentIntentId: String?
    
    @StateObject private var paymentService = PaymentService.shared
    @StateObject private var orderService = OrderService.shared
    @StateObject private var walletService = WalletService.shared
    
    var body: some View {
        NavigationView {
            VStack {
                if AppConfig.enableSeekMode {
                    if isLoading {
                        ProgressView("Loading offers...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if offers.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "tray")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("No offers yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("When sellers respond to your wanted post, their offers will appear here.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                            
                            Text("💡 Tip: Make sure your wanted post has a clear description and reasonable budget to attract offers.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(offers) { offer in
                                    OfferRowView(offer: offer) { action in
                                        handleOfferAction(offer: offer, action: action)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    // Feature disabled
                    VStack(spacing: 20) {
                        Image(systemName: "hammer.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Coming Soon")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Managing offers is currently under development.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Offers")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if AppConfig.enableSeekMode {
                Task { await loadOffers() }
            }
        }
        .sheet(isPresented: $showPaymentMethodSheet) {
            if let offer = selectedOffer {
                PaymentMethodSheet(
                    listing: createVirtualListing(from: offer),
                    wallet: currentWallet,
                    onPaymentMethodSelected: { paymentMethod in
                        showPaymentMethodSheet = false
                        handlePaymentMethodSelection(paymentMethod)
                    }
                )
            }
        }
        .sheet(item: $activeSheet) { sheet in
            switch sheet {
            case .purchaseConfirmation:
                if let order = createdOrder, let offer = selectedOffer {
                    PurchaseConfirmationView(
                        listing: createVirtualListing(from: offer),
                        order: order,
                        paymentMethod: order.paymentMethod,
                        onDismiss: {
                            activeSheet = nil
                            createdOrder = nil
                            selectedOffer = nil
                        },
                        onViewOrder: {
                            // Navigate to order details
                            if let order = createdOrder {
                                print("📱 Navigate to order details: \(order.id)")
                            }
                        },
                        onContactSeller: {
                            // Navigate to chat with seller
                            print("📱 Contact seller")
                        }
                    )
                }
            }
        }
        .alert("Payment Error", isPresented: $showErrorAlert) {
            Button("OK") { purchaseError = nil }
        } message: {
            Text(purchaseError ?? "An unknown error occurred")
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .background(
            NavigationLink(
                destination: OrderDetailNavigationView(orderId: selectedOrderId),
                isActive: $showOrderDetail
            ) {
                EmptyView()
            }
        )
    }
    
    private func loadOffers() async {
        guard let currentUserId = authManager.currentUserId else {
            await MainActor.run {
                errorMessage = "You must be logged in to view offers"
                isLoading = false
            }
            return
        }
        
        do {
            // Fetch offers for this seek listing where current user is the seeker
            let response: [OfferWithDetails] = try await supabase
                .from("offers")
                .select("""
                    *,
                    offer_listing:listings!offers_offer_listing_id_fkey(*,user:users(*)),
                    seller:users!offers_seller_id_fkey(*)
                """)
                .eq("seek_listing_id", value: seekListing.id.uuidString)
                .eq("seeker_id", value: currentUserId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                // Convert to simple Offer models
                self.offers = response.map { $0.toOffer() }
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load offers: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func handleOfferAction(offer: Offer, action: OfferAction) {
        switch action {
        case .accept:
            Task { await acceptOffer(offer) }
        case .decline:
            Task { await declineOffer(offer) }
        case .viewListing:
            // TODO: Navigate to listing detail
            print("View listing for offer \(offer.id)")
        case .contactSeller:
            // TODO: Open chat with seller
            print("Contact seller for offer \(offer.id)")
        case .viewOrder(let orderId):
            selectedOrderId = orderId
            showOrderDetail = true
        }
    }
    
    private func acceptOffer(_ offer: Offer) async {
        await MainActor.run {
            // Check if offer already has an associated order (shouldn't happen in new flow)
            if let orderId = offer.orderId {
                // Offer was already paid for, just navigate to the order
                selectedOrderId = orderId
                showOrderDetail = true
                print("📊 Analytics: Navigating to existing order for accepted offer - Order: \(orderId)")
            } else {
                // Normal flow: offer needs payment before acceptance
                selectedOffer = offer
                loadWalletBalance()
                showPaymentMethodSheet = true
                print("🔄 Starting payment flow for offer: \(offer.id)")
            }
        }
    }
    
    private func loadWalletBalance() {
        Task {
            do {
                currentWallet = try await walletService.fetchBalance()
            } catch {
                print("Failed to load wallet balance: \(error)")
            }
        }
    }
    
    private func handlePaymentMethodSelection(_ paymentMethod: PaymentMethod) {
        guard let offer = selectedOffer else { return }
        
        isPrimaryActionLoading = true
        
        Task {
            do {
                switch paymentMethod {
                case .wallet:
                    try await handleWalletPayment(for: offer)
                case .card:
                    try await handleCardPayment(for: offer)
                }
            } catch {
                await MainActor.run {
                    isPrimaryActionLoading = false
                    purchaseError = error.localizedDescription
                    showErrorAlert = true
                }
            }
        }
    }
    
    private func handleWalletPayment(for offer: Offer) async throws {
        guard let currentUserId = authManager.session?.user.id else {
            throw PaymentError.userNotAuthenticated
        }
        
        guard let wallet = currentWallet else {
            throw PaymentError.walletNotLoaded
        }
        
        let priceCents = offer.priceCents ?? 0
        guard wallet.availableCents >= priceCents else {
            throw PaymentError.insufficientFunds
        }
        
        // Create order with wallet payment using existing flow
        // When accepting an offer: seeker (current user) pays, offer maker provides the service/product
        let orderCreate = OrderCreate(
            listingId: offer.seekListingId, // Use seek listing as reference
            buyerId: currentUserId, // Seeker pays when accepting the offer
            sellerId: UUID(uuidString: offer.sellerId) ?? UUID(), // Offer maker provides service/product
            priceCents: priceCents,
            paymentMethod: .wallet,
            timeSlotId: nil,
            stripePaymentIntentId: nil
        )
        
        let order = try await orderService.createOrder(orderCreate)
        
        // Now that payment is successful, update offer status to accepted
        do {
            _ = try await OfferService.shared.acceptOfferStatus(offer.id)
            print("✅ Offer accepted after wallet payment - Offer: \(offer.id), Order: \(order.id)")
        } catch {
            print("⚠️ Payment succeeded but failed to update offer status: \(error)")
            // Payment went through, so continue to show confirmation
        }
        
        await MainActor.run {
            isPrimaryActionLoading = false
            createdOrder = order
            activeSheet = .purchaseConfirmation
            
            // Refresh offers list to show accepted status
            Task {
                await loadOffers()
            }
        }
    }
    
    private func handleCardPayment(for offer: Offer) async throws {
        guard let currentUserId = authManager.session?.user.id else {
            throw PaymentError.userNotAuthenticated
        }
        
        let priceCents = offer.priceCents ?? 0
        
        // Calculate processing fees
        let processingFeeCents = paymentService.calculateProcessingFee(amountCents: priceCents)
        
        await MainActor.run {
            self.processingFeeCents = processingFeeCents
        }
        
        // Call the new edge function for offer payments
        do {
            let (clientSecret, _, _, _) = try await createOfferPaymentIntent(
                offerId: offer.id.uuidString,
                buyerId: currentUserId.uuidString
            )
            
            // Extract payment intent ID from client secret
            // Client secret format: pi_xxx_secret_xxx
            let components = clientSecret.split(separator: "_")
            if components.count >= 2 && components[0] == "pi" {
                self.currentPaymentIntentId = "pi_\(components[1])"
            }
            
            // Configure payment sheet
            var configuration = PaymentSheet.Configuration()
            configuration.merchantDisplayName = "CampusLink"
            
            // Initialize payment sheet
            await MainActor.run {
                self.paymentSheet = PaymentSheet(
                    paymentIntentClientSecret: clientSecret,
                    configuration: configuration
                )
                self.isPrimaryActionLoading = false
            }
            
            // Present the payment sheet
            if let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
               let rootViewController = windowScene.windows.first?.rootViewController {
                await MainActor.run {
                    paymentSheet?.present(from: rootViewController) { paymentResult in
                        Task {
                            await self.handleStripePaymentResult(paymentResult, for: offer)
                        }
                    }
                }
            }
            
        } catch {
            await MainActor.run {
                self.isPrimaryActionLoading = false
            }
            throw error
        }
    }
    
    private func createOfferPaymentIntent(offerId: String, buyerId: String) async throws -> (String, Int, Int, Int) {
        struct RequestBody: Encodable {
            let offer_id: String
            let buyer_id: String
        }
        
        struct ResponseBody: Decodable {
            let client_secret: String
            let base_amount_cents: Int
            let stripe_fee_cents: Int
            let total_amount_cents: Int
        }
        
        let body = RequestBody(offer_id: offerId, buyer_id: buyerId)
        
        do {
            let response: ResponseBody = try await supabase.functions.invoke(
                "create_offer_payment_intent",
                options: FunctionInvokeOptions(
                    method: .post,
                    body: body
                )
            )
            
            return (response.client_secret, response.base_amount_cents, response.stripe_fee_cents, response.total_amount_cents)
        } catch {
            // Handle function errors properly
            if let functionError = error as? FunctionsError {
                throw NSError(
                    domain: "OfferPayment",
                    code: 0,
                    userInfo: [NSLocalizedDescriptionKey: functionError.localizedDescription]
                )
            }
            throw error
        }
    }
    
    private func handleStripePaymentResult(_ paymentResult: PaymentSheetResult, for offer: Offer) async {
        switch paymentResult {
        case .completed:
            // Payment successful, create order and accept offer
            guard let currentUserId = authManager.session?.user.id else { return }
            
            do {
                let orderCreate = OrderCreate(
                    listingId: offer.seekListingId,
                    buyerId: currentUserId,
                    sellerId: UUID(uuidString: offer.sellerId) ?? UUID(),
                    priceCents: offer.priceCents ?? 0,
                    paymentMethod: .card,
                    timeSlotId: nil,
                    stripePaymentIntentId: self.currentPaymentIntentId
                )
                
                let order = try await orderService.createOrder(orderCreate)
                
                // Now accept the offer after successful payment
                do {
                    _ = try await OfferService.shared.acceptOfferStatus(offer.id)
                    print("✅ Offer accepted after card payment - Offer: \(offer.id), Order: \(order.id)")
                } catch {
                    print("⚠️ Payment succeeded but failed to update offer status: \(error)")
                }
                
                await MainActor.run {
                    createdOrder = order
                    selectedPaymentMethod = .card
                    activeSheet = .purchaseConfirmation
                    
                    // Refresh offers list
                    Task {
                        await loadOffers()
                    }
                }
            } catch {
                await MainActor.run {
                    purchaseError = "Failed to create order: \(error.localizedDescription)"
                    showErrorAlert = true
                }
            }
            
        case .canceled:
            print("Payment canceled by user")
            await MainActor.run {
                isPrimaryActionLoading = false
            }
            
        case .failed(let error):
            print("Payment failed: \(error)")
            await MainActor.run {
                purchaseError = error.localizedDescription
                showErrorAlert = true
                isPrimaryActionLoading = false
            }
        }
    }
    
    private func declineOffer(_ offer: Offer) async {
        do {
            try await OfferService.shared.declineOffer(offer.id)
            
            print("📊 Analytics: Offer declined - Seek: \(seekListing.id), Offer: \(offer.id)")
            
            // Refresh offers list
            await loadOffers()
            
        } catch {
            await MainActor.run {
                let errorDesc = error.localizedDescription
                if errorDesc.contains("function") || errorDesc.contains("decline_offer") {
                    errorMessage = "Database setup required. Please run the offers migration script in Supabase first."
                } else {
                    errorMessage = "Failed to decline offer: \(errorDesc)"
                }
            }
            print("❌ Failed to decline offer: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    /// Creates a virtual listing for the payment flow using offer data
    private func createVirtualListing(from offer: Offer) -> ListingWithUser {
        // Create a virtual seller user from the offer seller ID
        let virtualSeller = User(
            id: offer.sellerId,
            name: "Seller", // Will be loaded dynamically in UI
            bio: nil,
            profilePic: nil,
            email: nil,
            createdAt: Date(),
            campusEmailVerified: nil,
            trustScore: nil,
            stripeConnectId: nil,
            stripePayoutsEnabled: nil,
            stripeDetailsSubmitted: nil
        )
        
        return ListingWithUser(
            id: offer.seekListingId,
            title: seekListing.title + " (Accepted Offer)",
            description: "Accepted offer for \(seekListing.title)",
            price: offer.price,
            category: seekListing.category,
            photo: seekListing.photo,
            photos: seekListing.photos,
            isSold: false,
            listingType: seekListing.listingType,
            serviceDuration: seekListing.serviceDuration,
            serviceLocation: seekListing.serviceLocation,
            serviceAvailability: seekListing.serviceAvailability,
            serviceType: seekListing.serviceType,
            slotsAvailable: seekListing.slotsAvailable,
            maxBookingsPerSlot: seekListing.maxBookingsPerSlot,
            archived: false,
            createdAt: offer.createdAt,
            user: virtualSeller, // The seller who made the offer
            intent: .offer, // Change to offer for payment flow compatibility
            budgetMin: nil,
            budgetMax: nil,
            expiresAt: nil
        )
    }
}

// MARK: - Sheet Router
enum OfferSheet: Identifiable {
    case purchaseConfirmation
    
    var id: String {
        switch self {
        case .purchaseConfirmation: return "purchaseConfirmation"
        }
    }
}

enum OfferAction {
    case accept
    case decline
    case viewListing
    case contactSeller
    case viewOrder(UUID)
}

struct OfferRowView: View {
    let offer: Offer
    let onAction: (OfferAction) -> Void
    
    @State private var sellerName: String = "Loading..."
    
    private var isClickableAcceptedOffer: Bool {
        offer.status == "accepted" && offer.orderId != nil
    }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offer from \(sellerName)")
                    .font(.headline)
                    .lineLimit(1)
                    
                    // Show offer amount
                    if let price = offer.formattedPrice {
                        Text(price)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                    } else {
                        Text("Custom offer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                Text(offer.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    
                    // Status badge
                    HStack(spacing: 4) {
                        if offer.orderId != nil {
                            Image(systemName: "checkmark.seal.fill")
                                .font(.caption)
                                .foregroundColor(.green)
                        }
                        Text(offer.displayStatus)
                            .font(.caption)
                            .fontWeight(.medium)
                    }
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(offer.statusColor.opacity(0.2))
                    .foregroundColor(offer.statusColor)
                    .cornerRadius(8)
                }
            }
            
            // Message from seller
            if let message = offer.message, !message.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                Text(message)
                    .font(.body)
                        .foregroundColor(.primary)
                    .lineLimit(3)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                    .cornerRadius(8)
            }
            }
            
            // Action buttons for pending offers (including paid pending)
            if offer.status == "pending" || offer.status == "paid_pending_acceptance" {
                HStack(spacing: 12) {
                    Button(action: { onAction(.accept) }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    
                    Button(action: { onAction(.decline) }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Decline")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    // Only show "View Listing" if there's an actual listing (not custom price)
                    if offer.offerListingId != nil {
                        Button(action: { onAction(.viewListing) }) {
                            Text("View Item")
                                .font(.caption)
                                .foregroundColor(Color("ThemeColor"))
                        }
                    }
                }
            }
            
            // Show "View Order" button for accepted offers with an order
            if isClickableAcceptedOffer {
                HStack {
                    Image(systemName: "doc.text.fill")
                        .font(.caption)
                        .foregroundColor(Color("ThemeColor"))
                    Text("View Order Details")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(Color("ThemeColor"))
                    Spacer()
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding(.horizontal, 12)
                .padding(.vertical, 10)
                .background(Color("ThemeColor").opacity(0.1))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .onTapGesture {
            if let orderId = offer.orderId, offer.status == "accepted" {
                onAction(.viewOrder(orderId))
            }
        }
        .task {
            await loadSellerName()
        }
    }
    
    private func loadSellerName() async {
        do {
            let seller: User = try await supabase
                .from("users")
                .select("name")
                .eq("id", value: offer.sellerId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                sellerName = seller.name ?? "Unknown Seller"
            }
        } catch {
            await MainActor.run {
                sellerName = "Seller"
            }
        }
    }
}

// Add status color extension for Offer
extension Offer {
    var statusColor: Color {
        switch status {
        case "pending": return .orange
        case "paid_pending_acceptance": return .blue
        case "accepted": return .green
        case "declined": return .red
        case "withdrawn": return .gray
        case "expired": return .gray
        default: return .gray
        }
    }
    
    var displayStatus: String {
        switch status {
        case "paid_pending_acceptance": return "Paid - Awaiting Acceptance"
        default: return status.capitalized
        }
    }
}

// Helper model for fetching offers with details
struct OfferWithDetails: Codable {
    let id: UUID
    let seekListingId: UUID
    let offerListingId: UUID?
    let seekerId: String
    let sellerId: String
    let message: String?
    let status: String
    let priceCents: Int?
    let orderId: UUID?
    let createdAt: Date
    let updatedAt: Date
    
    // Joined data
    let offerListing: ListingWithUser?
    let seller: User?
    
    enum CodingKeys: String, CodingKey {
        case id
        case seekListingId = "seek_listing_id"
        case offerListingId = "offer_listing_id"
        case seekerId = "seeker_id"
        case sellerId = "seller_id"
        case message, status
        case priceCents = "price_cents"
        case orderId = "order_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case offerListing = "offer_listing"
        case seller
    }
    
    func toOffer() -> Offer {
        return Offer(
            id: id,
            seekListingId: seekListingId,
            offerListingId: offerListingId,
            seekerId: seekerId,
            sellerId: sellerId,
            message: message,
            status: status,
            priceCents: priceCents,
            orderId: orderId,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

// MARK: - Order Detail Navigation Wrapper
struct OrderDetailNavigationView: View {
    let orderId: UUID?
    @State private var order: Order?
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        Group {
            if isLoading {
                ProgressView("Loading order...")
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else if let order = order {
                OrderDetailView(order: order)
            } else {
                VStack(spacing: 20) {
                    Image(systemName: "exclamationmark.triangle")
                        .font(.system(size: 50))
                        .foregroundColor(.orange)
                    
                    Text("Order Not Found")
                        .font(.title2)
                        .fontWeight(.semibold)
                    
                    Text(errorMessage ?? "The order could not be loaded.")
                        .multilineTextAlignment(.center)
                        .foregroundColor(.secondary)
                        .padding(.horizontal)
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .task {
            await loadOrder()
        }
    }
    
    private func loadOrder() async {
        guard let orderId = orderId else {
            await MainActor.run {
                errorMessage = "Invalid order ID"
                isLoading = false
            }
            return
        }
        
        do {
            let fetchedOrder: Order = try await supabase
                .from("orders")
                .select("*")
                .eq("id", value: orderId.uuidString)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                self.order = fetchedOrder
                isLoading = false
            }
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load order: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
}

struct OffersListView_Previews: PreviewProvider {
    static var previews: some View {
        OffersListView(seekListing: .sampleListing)
            .environmentObject(AuthManager())
    }
}
