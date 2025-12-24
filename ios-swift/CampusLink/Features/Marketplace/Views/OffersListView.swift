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
    @State private var offerForPayment: Offer? // Separate state for payment sheet
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
    @State private var currentPaymentIntentId: String?  // Store payment intent ID for order update
    
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
            PaymentMethodSheetWrapper(
                offerForPayment: $offerForPayment,
                selectedOffer: $selectedOffer,
                currentWallet: currentWallet,
                onPaymentMethodSelected: { paymentMethod in
                    showPaymentMethodSheet = false
                    handlePaymentMethodSelection(paymentMethod)
                },
                onClose: {
                    showPaymentMethodSheet = false
                }
            )
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
                            offerForPayment = nil
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
            // Use unified offer fields - filter by listing_id and user role
            // Current user should be offer_to_user_id (they're receiving offers on their listing)
            // Only show pending and accepted offers (not declined/withdrawn)
            let response: [OfferWithDetails] = try await supabase
                .from("offers")
                .select("*")
                .eq("listing_id", value: seekListing.id.uuidString)
                .eq("offer_to_user_id", value: currentUserId)
                .in("status", values: ["pending", "accepted"])
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                // Convert to simple Offer models
                self.offers = response.map { $0.toOffer(listingType: seekListing.intent == .seek ? .seek : .regular) }
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
        guard let currentUserId = authManager.currentUserId else {
            await MainActor.run {
                errorMessage = "You must be logged in to accept offers"
            }
            return
        }
        
        print("🔄 acceptOffer called for offer: \(offer.id)")
        
        // Check if offer already has an associated order
        if let orderId = offer.orderId {
            // Offer was already paid for, just navigate to the order
            await MainActor.run {
                selectedOrderId = orderId
                showOrderDetail = true
            }
            print("📊 Navigating to existing order: \(orderId)")
            return
        }
        
        do {
            // Call UnifiedOfferService to create the order
            let offerService = UnifiedOfferService.shared
            let order = try await offerService.acceptOffer(offerId: offer.id, currentUserId: currentUserId)
            
            print("✅ Order created: \(order.id)")
            
            // Determine if current user is the buyer (who needs to pay)
            let isBuyer: Bool
            if offer.listingType == .seek {
                // On seek listings: offer_to_user is the buyer
                isBuyer = (currentUserId == offer.offerToUserId)
        } else {
                // On regular listings: offer_from_user is the buyer
                isBuyer = (currentUserId == offer.offerFromUserId)
            }
            
            if isBuyer {
                // Current user is the buyer - they need to complete payment
                print("💳 Current user is buyer, showing payment sheet")
            await MainActor.run {
                selectedOffer = offer
                offerForPayment = offer
            }
            await loadWalletBalance()
            await MainActor.run {
                showPaymentMethodSheet = true
                }
            } else {
                // Current user is the seller - order created, buyer will be notified
                print("✅ Seller accepted offer. Buyer will be notified to pay.")
                await MainActor.run {
                    errorMessage = "Offer accepted! The buyer will be notified to complete payment."
                }
                // Reload offers to show updated status
                await loadOffers()
            }
        } catch {
            print("❌ Failed to accept offer: \(error)")
            await MainActor.run {
                errorMessage = "Failed to accept offer: \(error.localizedDescription)"
            }
        }
    }
    
    private func loadWalletBalance() async {
        do {
            // Fetch REAL balance from Stripe (source of truth)
            let wallet = try await walletService.fetchStripeBalance()
            await MainActor.run {
                currentWallet = wallet
            }
            print("💰 Loaded Stripe balance for checkout: \(wallet.formattedAvailableBalance)")
        } catch {
            print("❌ Failed to load wallet balance: \(error)")
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
        let sellerPriceCents = priceCents
        let buyerPriceCents = FeeCalculationService.shared.calculateBuyerPrice(sellerPriceCents: sellerPriceCents)
        
        let orderCreate = OrderCreate(
            listingId: offer.listingId, // Use listing as reference
            buyerId: currentUserId, // Seeker pays when accepting the offer
            sellerId: UUID(uuidString: offer.offerFromUserId) ?? UUID(), // Offer maker provides service/product
            priceCents: sellerPriceCents,
            sellerPriceCents: sellerPriceCents,
            buyerPriceCents: buyerPriceCents,
            paymentMethod: .wallet,
            timeSlotId: nil,
            quantity: 1  // Offers are always for single unit
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
            let (clientSecret, _, _, _, paymentIntentId) = try await createOfferPaymentIntent(
                offerId: offer.id.uuidString,
                buyerId: currentUserId.uuidString
            )
            
            // Store payment intent ID for later use when order is created
            await MainActor.run {
                self.currentPaymentIntentId = paymentIntentId
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
            
            // Present the payment sheet from the root view controller
            await MainActor.run {
                // First dismiss our payment method sheet
                showPaymentMethodSheet = false
            }
            
            // Wait longer for the sheet to fully dismiss and find the topmost view controller
            try await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
            
            // Find the topmost view controller to present from
            await MainActor.run {
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else {
                    print("❌ Could not find window scene")
                    return
                }
                
                // Find the topmost presented view controller
                var topViewController = window.rootViewController
                while let presentedViewController = topViewController?.presentedViewController {
                    topViewController = presentedViewController
                }
                
                guard let presentingVC = topViewController else {
                    print("❌ Could not find presenting view controller")
                    return
                }
                
                print("🔍 Presenting Stripe PaymentSheet from: \(type(of: presentingVC))")
                
                paymentSheet?.present(from: presentingVC) { paymentResult in
                    Task {
                        await self.handleStripePaymentResult(paymentResult, for: offer)
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
    
           // Helper function for timeout
           private func withTimeout<T>(seconds: TimeInterval, operation: @escaping () async throws -> T) async throws -> T {
               try await withThrowingTaskGroup(of: T.self) { group in
                   group.addTask {
                       try await operation()
                   }
                   
                   group.addTask {
                       try await Task.sleep(nanoseconds: UInt64(seconds * 1_000_000_000))
                       throw NSError(domain: "Timeout", code: -1, userInfo: [NSLocalizedDescriptionKey: "Operation timed out after \(seconds) seconds"])
                   }
                   
                   let result = try await group.next()!
                   group.cancelAll()
                   return result
               }
           }
           
           private func createOfferPaymentIntent(offerId: String, buyerId: String) async throws -> (String, Int, Int, Int, String) {
               print("🔍 Creating payment intent for offer: \(offerId), buyer: \(buyerId)")
               
               struct RequestBody: Encodable {
                   let offer_id: String
                   let buyer_id: String
               }
               
               struct ResponseBody: Decodable {
                   let client_secret: String
                   let base_amount_cents: Int
                   let stripe_fee_cents: Int
                   let total_amount_cents: Int
                   let payment_intent_id: String  // CRITICAL: Needed for payment capture
               }
               
               let body = RequestBody(offer_id: offerId, buyer_id: buyerId)
               
               // Log the request body
               if let jsonData = try? JSONEncoder().encode(body),
                  let jsonString = String(data: jsonData, encoding: .utf8) {
                   print("🔍 Request body JSON: \(jsonString)")
               }
               
               do {
                   print("🔍 Calling supabase.functions.invoke...")
                   
                   // Add timeout to the function call
                   let response: ResponseBody = try await withTimeout(seconds: 30) {
                       try await supabase.functions.invoke(
                           "create_offer_payment_intent",
                           options: FunctionInvokeOptions(
                               method: .post,
                               body: body
                           )
                       )
                   }
                   
                   print("✅ Edge Function response received:")
                   print("  client_secret: \(response.client_secret.prefix(20))...")
                   print("  payment_intent_id: \(response.payment_intent_id)")
                   print("  base_amount_cents: \(response.base_amount_cents)")
                   print("  stripe_fee_cents: \(response.stripe_fee_cents)")
                   print("  total_amount_cents: \(response.total_amount_cents)")
                   
                   return (response.client_secret, response.base_amount_cents, response.stripe_fee_cents, response.total_amount_cents, response.payment_intent_id)
               } catch {
                   // Handle function errors properly with detailed logging
                   print("❌ Edge Function Error Details:")
                   print("  Error type: \(type(of: error))")
                   print("  Error description: \(error.localizedDescription)")
                   print("  Full error: \(error)")
                   
                   if let functionError = error as? FunctionsError {
                       print("  FunctionsError details: \(functionError)")
                       print("  FunctionsError message: \(functionError.localizedDescription)")
                       throw NSError(
                           domain: "OfferPayment",
                           code: 0,
                           userInfo: [NSLocalizedDescriptionKey: "Edge Function Error: \(functionError.localizedDescription)"]
                       )
                   }
                   
                   if let nsError = error as? NSError {
                       print("  NSError domain: \(nsError.domain)")
                       print("  NSError code: \(nsError.code)")
                       print("  NSError userInfo: \(nsError.userInfo)")
                   }
                   
                   // Try to extract more details from the error
                   let errorString = String(describing: error)
                   print("  Full error string: \(errorString)")
                   
                   throw NSError(
                       domain: "OfferPayment",
                       code: 0,
                       userInfo: [NSLocalizedDescriptionKey: "Payment setup failed: \(error.localizedDescription)"]
                   )
               }
           }
    
    private func handleStripePaymentResult(_ paymentResult: PaymentSheetResult, for offer: Offer) async {
        switch paymentResult {
        case .completed:
            // Payment successful, create order and accept offer
            guard let currentUserId = authManager.session?.user.id else { return }
            
            do {
                let sellerPriceCents = offer.priceCents ?? 0
                let buyerPriceCents = FeeCalculationService.shared.calculateBuyerPrice(sellerPriceCents: sellerPriceCents)
                
                let orderCreate = OrderCreate(
                    listingId: offer.listingId,
                    buyerId: currentUserId,
                    sellerId: UUID(uuidString: offer.offerFromUserId) ?? UUID(),
                    priceCents: sellerPriceCents,
                    sellerPriceCents: sellerPriceCents,
                    buyerPriceCents: buyerPriceCents,
                    paymentMethod: .card,
                    timeSlotId: nil,
                    quantity: 1  // Offers are always for single unit
                )
                
                let order = try await orderService.createOrder(orderCreate)
                
                // CRITICAL: Update order with payment intent ID for capture
                if let paymentIntentId = currentPaymentIntentId {
                    print("💳 Updating order \(order.id) with payment intent: \(paymentIntentId)")
                    do {
                        _ = try await orderService.updateOrderWithPaymentIntent(order.id, paymentIntentId: paymentIntentId)
                        print("✅ Payment intent ID saved to order")
                    } catch {
                        print("⚠️ Failed to save payment intent ID: \(error)")
                        // Non-fatal: order was still created, payment was authorized
                    }
                    await MainActor.run {
                        self.currentPaymentIntentId = nil  // Clear stored payment intent ID
                    }
                } else {
                    print("⚠️ No payment intent ID available to save to order")
                }
                
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
        guard let currentUserId = authManager.currentUserId else {
            await MainActor.run {
                errorMessage = "You must be logged in to decline offers"
            }
            return
        }
        
        do {
            // Use UnifiedOfferService instead of old OfferService
            try await UnifiedOfferService.shared.rejectOffer(offerId: offer.id, currentUserId: currentUserId)
            
            print("✅ Offer declined: \(offer.id)")
            
            // Refresh offers list to remove the declined offer
            await loadOffers()
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to decline offer: \(error.localizedDescription)"
            }
            print("❌ Failed to decline offer: \(error)")
        }
    }
    
    // MARK: - Helper Functions
    
    /// Creates a virtual listing for the payment flow using offer data
    private func createVirtualListing(from offer: Offer) -> ListingWithUser {
        // Create a virtual seller user from the offer seller ID
        let virtualSeller = User(
            id: offer.offerFromUserId,
            name: "Seller", // Will be loaded dynamically in UI
            bio: nil,
            profilePic: nil,
            email: nil,
            campus: nil,
            createdAt: Date(),
            campusEmailVerified: nil,
            trustScore: nil,
            stripeConnectId: nil,
            stripePayoutsEnabled: nil,
            stripeDetailsSubmitted: nil,
            verificationStatus: nil,
            studentIdImageUrl: nil,
            verificationSubmittedAt: nil,
            verificationReviewedAt: nil,
            verificationNotes: nil
        )
        
        return ListingWithUser(
            id: offer.seekListingId ?? offer.listingId,
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
            archived: false,
            createdAt: offer.createdAt,
            user: virtualSeller, // The seller who made the offer
            intent: .offer, // Change to offer for payment flow compatibility
            budgetMin: nil,
            budgetMax: nil,
            expiresAt: nil,
            deliveryMethod: seekListing.deliveryMethod,
            quantityAvailable: 1,
            quantitySold: 0,
            acceptsOffers: false
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

// MARK: - Payment Method Sheet Wrapper
struct PaymentMethodSheetWrapper: View {
    @Binding var offerForPayment: Offer?
    @Binding var selectedOffer: Offer?
    let currentWallet: Wallet?
    let onPaymentMethodSelected: (PaymentMethod) -> Void
    let onClose: () -> Void
    
    var body: some View {
        Group {
            if let offer = offerForPayment ?? selectedOffer {
                PaymentMethodSheet(
                    listing: createVirtualListing(from: offer),
                    wallet: currentWallet,
                    onPaymentMethodSelected: onPaymentMethodSelected
                )
                .onAppear {
                    print("🔄 PaymentMethodSheet presented for offer: \(offer.id)")
                    print("🔄 currentWallet exists: \(currentWallet != nil)")
                }
            } else {
                VStack(spacing: 20) {
                    Text("Error: No offer selected")
                        .font(.headline)
                    
                    Text("Debug Info:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("offerForPayment: \(offerForPayment?.id.uuidString ?? "nil")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Text("selectedOffer: \(selectedOffer?.id.uuidString ?? "nil")")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    Button("Close") {
                        onClose()
                    }
                    .padding()
                    .background(Color.blue)
                    .foregroundColor(.white)
                    .cornerRadius(8)
                }
                .onAppear {
                    print("❌ PaymentMethodSheetWrapper: Both offers are nil")
                    print("❌ offerForPayment: \(offerForPayment?.id.uuidString ?? "nil")")
                    print("❌ selectedOffer: \(selectedOffer?.id.uuidString ?? "nil")")
                }
            }
        }
    }
    
    private func createVirtualListing(from offer: Offer) -> ListingWithUser {
        // Create a virtual seller user from the offer seller ID
        let virtualSeller = User(
            id: offer.offerFromUserId,
            name: "Seller",
            bio: nil,
            profilePic: nil,
            email: nil,
            campus: nil,
            createdAt: Date(),
            campusEmailVerified: nil,
            trustScore: nil,
            stripeConnectId: nil,
            stripePayoutsEnabled: nil,
            stripeDetailsSubmitted: nil,
            verificationStatus: nil,
            studentIdImageUrl: nil,
            verificationSubmittedAt: nil,
            verificationReviewedAt: nil,
            verificationNotes: nil
        )
        
        return ListingWithUser(
            id: offer.seekListingId ?? offer.listingId,
            title: "Accepted Offer",
            description: "Accepted offer",
            price: offer.price,
            category: "Service",
            photo: nil,
            photos: [],
            isSold: false,
            listingType: .service,
            serviceDuration: nil,
            serviceLocation: nil,
            serviceAvailability: nil,
            archived: false,
            createdAt: offer.createdAt,
            user: virtualSeller,
            intent: .offer,
            budgetMin: nil,
            budgetMax: nil,
            expiresAt: nil,
            deliveryMethod: nil,
            quantityAvailable: 1,
            quantitySold: 0,
            acceptsOffers: false
        )
    }
}

struct OfferRowView: View {
    let offer: Offer
    let onAction: (OfferAction) -> Void
    
    @State private var offererName: String = "Loading..."
    @StateObject private var feeService = FeeCalculationService.shared
    
    private var isClickableAcceptedOffer: Bool {
        offer.status == "accepted" && offer.orderId != nil
    }
    
    // Determine the role label based on listing type
    private var offererRoleLabel: String {
        if offer.listingType == .seek {
            return "Seller"  // On seek listings, offers come from sellers
        } else {
            return "Buyer"   // On regular listings, offers come from buyers
        }
    }
    
    // Calculate fees for pending offers
    private var offerPriceCents: Int { offer.priceCents ?? 0 }
    private var stripeFee: Int { feeService.calculateStripeProcessingFee(amountCents: offerPriceCents) }
    private var totalYouPay: Int { feeService.calculateBuyerPrice(sellerPriceCents: offerPriceCents) }
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offer from \(offererRoleLabel)")
                    .font(.headline)
                    .lineLimit(1)
                    
                    Text(offererName)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
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
            
            // Note: Sellers see the offer amount they'll receive (no fees shown)
            // Fees are calculated when buyer completes payment
            
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
                        .foregroundColor(.facebookBlue)
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
            await loadOffererName()
        }
    }
    
    private func loadOffererName() async {
        do {
            let user: User = try await supabase
                .from("users")
                .select("name")
                .eq("id", value: offer.offerFromUserId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                offererName = (user.name ?? "Unknown User").formattedName
            }
        } catch {
            await MainActor.run {
                offererName = "Unknown User"
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
        case "declined": return .facebookBlue
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

// Helper model for fetching offers with details (Unified Model)
struct OfferWithDetails: Codable {
    let id: UUID
    let listingId: UUID
    let listingType: String
    let offerListingId: UUID?
    let offerFromUserId: String
    let offerToUserId: String
    let parentOfferId: UUID?
    let message: String?
    let status: String
    let priceCents: Int?
    let orderId: UUID?
    let createdAt: Date
    let updatedAt: Date
    
    // Legacy fields for backward compatibility
    let seekListingId: UUID?
    let seekerId: String?
    let sellerId: String?
    
    enum CodingKeys: String, CodingKey {
        case id
        case listingId = "listing_id"
        case listingType = "listing_type"
        case offerListingId = "offer_listing_id"
        case offerFromUserId = "offer_from_user_id"
        case offerToUserId = "offer_to_user_id"
        case parentOfferId = "parent_offer_id"
        case message, status
        case priceCents = "price_cents"
        case orderId = "order_id"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        // Legacy
        case seekListingId = "seek_listing_id"
        case seekerId = "seeker_id"
        case sellerId = "seller_id"
    }
    
    func toOffer(listingType: OfferListingType) -> Offer {
        return Offer(
            id: id,
            listingId: listingId,
            listingType: listingType,
            offerListingId: offerListingId,
            offerFromUserId: offerFromUserId,
            offerToUserId: offerToUserId,
            parentOfferId: parentOfferId,
            seekListingId: seekListingId,
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
