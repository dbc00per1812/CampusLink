import SwiftUI
import StripePaymentSheet
import Realtime

struct OrderDetailView: View {
    let order: Order
    @EnvironmentObject private var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmAlert = false
    @State private var showDisputeSheet = false
    @State private var showContactSheet = false
    @State private var activeConversation: Conversation?
    @State private var isLoadingConversation = false
    @State private var showSuccessView = false
    @State private var successMessage = ""
    @State private var currentOrder: Order
    @State private var showOrderInfo = false
    @State private var showRatingSheet = false
    @State private var ratingType: RatingType?
    @State private var canRateSeller = false
    @State private var canRateBuyer = false
    @State private var hasRatedSeller = false
    @State private var hasRatedBuyer = false
    @State private var showDeliveryPhotoSheet = false
    @State private var showPINEntrySheet = false
    @State private var showCancelAlert = false
    @State private var refreshTimer: Timer?
    @State private var showPaymentSheet = false
    @State private var isProcessingPayment = false
    @State private var realtimeChannel: RealtimeChannelV2?
    @Environment(\.dismiss) private var dismiss
    @Environment(\.scenePhase) private var scenePhase
    
    private let paymentService = PaymentService.shared
    
    init(order: Order) {
        self.order = order
        self._currentOrder = State(initialValue: order)
    }
    
    private var isBuyer: Bool {
        authManager.session?.user.id == currentOrder.buyerId
    }
    
    private var isSeller: Bool {
        authManager.session?.user.id == currentOrder.sellerId
    }
    
    private var canConfirmReceived: Bool {
        // Buyer can confirm after seller delivers
        // Payment status can be either:
        // - .requiresCapture (escrow - funds held, released on confirm)
        // - .succeeded (direct payment - already captured)
        let validPaymentStatus = currentOrder.paymentStatus == .requiresCapture || 
                                 currentOrder.paymentStatus == .succeeded
        return isBuyer && validPaymentStatus && currentOrder.orderStatus == .sellerConfirmed
    }
    
    private var canMarkDelivered: Bool {
        isSeller && (currentOrder.orderStatus == .placed || currentOrder.orderStatus == .inProgress)
    }
    
    private var canCancelOrder: Bool {
        isBuyer && currentOrder.orderStatus == .placed
    }
    
    private var needsPayment: Bool {
        isBuyer && currentOrder.paymentStatus == .pending && currentOrder.orderStatus == .placed
    }
    
    var body: some View {
        ZStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Section
                    headerSection
                    
                    // Order Status Timeline
                    statusTimelineSection
                    
                    // Payment Details
                    paymentDetailsSection
                    
                    // Delivery Photo (if available)
                    if currentOrder.hasDeliveryPhoto {
                        deliveryPhotoSection
                    }
                    
                    // Escrow Status (if applicable)
                    if currentOrder.hasEscrowAccount {
                        escrowStatusSection
                    }
                    
                    // Actions Section
                    if !showSuccessView {
                        actionsSection
                    }
                    
                    // Collapsible Order Information
                    collapsibleOrderInfoSection
                }
                .padding()
            }
            .blur(radius: showSuccessView ? 3 : 0)
            .disabled(showSuccessView)
            
            // Success overlay
            if showSuccessView {
                successOverlay
            }
        }
        .navigationTitle("Order Details")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .navigationBarTrailing) {
                Button("Contact") {
                    Task {
                        await openContactSheet()
                    }
                }
                .foregroundColor(Color("ThemeColor"))
            }
        }
        .alert(currentOrder.listing?.listingType == .service ? "Confirm Service Completed?" : "Confirm Product Received?", isPresented: $showConfirmAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                Task { await confirmReceived() }
            }
        } message: {
            Text("This will release the payment to the seller and complete the transaction.")
        }
        .alert("Cancel Order?", isPresented: $showCancelAlert) {
            Button("No", role: .cancel) { }
            Button("Yes, Cancel", role: .destructive) {
                Task { await cancelOrder() }
            }
        } message: {
            Text("This will cancel the order and refund the full amount to your wallet. This action cannot be undone.")
        }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") {
                errorMessage = nil
            }
        } message: {
            Text(errorMessage ?? "")
        }
        .sheet(isPresented: $showDisputeSheet) {
            ReportDisputeView(order: order) {
                // Refresh order data after dispute
                Task { await loadOrderData() }
            }
            .environmentObject(authManager)
        }
                    .sheet(isPresented: $showContactSheet) {
                if let conversation = activeConversation {
                    ChatView(conversation: conversation)
                        .environmentObject(authManager)
                }
            }
            .sheet(isPresented: $showRatingSheet) {
                if let ratingType = ratingType {
                    RatingComposeView(order: currentOrder, ratingType: ratingType)
                        .environmentObject(authManager)
                        .onDisappear {
                            // Refresh rating status when sheet closes
                            Task { await checkRatingStatus() }
                        }
                }
            }
            .sheet(isPresented: $showDeliveryPhotoSheet) {
                DeliveryPhotoUploadView(orderId: currentOrder.id) { photoURL in
                    Task { await markDelivered(with: photoURL) }
                }
            }
            .sheet(isPresented: $showPINEntrySheet) {
                PINEntryView(orderId: currentOrder.id) {
                    Task { await loadOrderData() }
                }
            }
        .onAppear {
            Task { 
                await loadOrderData() 
                await checkRatingStatus()
                // Setup realtime subscription for instant updates
                await setupRealtimeSubscription()
            }
        }
        .onDisappear {
            Task {
                // Cleanup realtime subscription when view disappears
                await cleanupRealtimeSubscription()
            }
        }
        .onChange(of: scenePhase) { oldPhase, newPhase in
            // Refresh order data when app comes to foreground to prevent stale data
            if newPhase == .active {
                Task { await loadOrderData() }
            }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Order ID
            HStack {
                Text("Order #\(currentOrder.id.uuidString.prefix(8))")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                orderStatusBadge
            }
            
            // Deadline Warning (only show for active orders)
            if showDeadlineIndicator {
                deadlineIndicatorView
            }

            // Listing Info
            if let listing = currentOrder.listing {
                HStack(alignment: .top, spacing: 12) {
                    // Placeholder for listing image
                    RoundedRectangle(cornerRadius: 8)
                        .fill(Color.gray.opacity(0.2))
                        .frame(width: 80, height: 80)
                        .overlay(
                            Image(systemName: "photo")
                                .foregroundColor(.gray)
                        )

                    VStack(alignment: .leading, spacing: 4) {
                        Text(listing.title)
                            .font(.headline)
                            .lineLimit(2)
                        Text(listing.description)
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .lineLimit(3)
                    }
                    Spacer()
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Deadline Indicator
    
    /// Whether to show the deadline indicator
    private var showDeadlineIndicator: Bool {
        // Only show for active orders (not completed, cancelled, or refunded)
        let activeStatuses: [OrderStatus] = [.placed, .sellerConfirmed, .inProgress]
        return activeStatuses.contains(currentOrder.orderStatus)
    }
    
    /// Deadline indicator view showing time remaining
    @ViewBuilder
    private var deadlineIndicatorView: some View {
        let isNearDeadline = ActiveOrderMonitor.isNearDeadline(order: currentOrder)
        let isPastDeadline = ActiveOrderMonitor.isPastDeadline(order: currentOrder)
        let formattedTime = ActiveOrderMonitor.formattedTimeRemaining(for: currentOrder)
        let deadlineDate = ActiveOrderMonitor.deadlineDate(for: currentOrder)
        
        // Determine colors and icons based on state
        let iconName: String = isPastDeadline ? "exclamationmark.triangle.fill" : (isNearDeadline ? "clock.badge.exclamationmark.fill" : "clock.fill")
        let iconColor: Color = isPastDeadline ? .red : (isNearDeadline ? .orange : .blue)
        let bgColor: Color = isPastDeadline ? Color.red.opacity(0.1) : (isNearDeadline ? Color.orange.opacity(0.1) : Color.blue.opacity(0.1))
        
        HStack(spacing: 8) {
            Image(systemName: iconName)
                .foregroundColor(iconColor)
            
            VStack(alignment: .leading, spacing: 2) {
                Text(isPastDeadline ? "Deadline Expired" : "Complete by")
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if isPastDeadline {
                    Text("Order will be auto-cancelled")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.red)
                } else {
                    deadlineTimeText(deadlineDate: deadlineDate, formattedTime: formattedTime, isNearDeadline: isNearDeadline)
                }
            }
            
            Spacer()
            
            // Progress indicator
            if !isPastDeadline {
                deadlineProgressView(isNearDeadline: isNearDeadline)
            }
        }
        .padding(12)
        .background(
            RoundedRectangle(cornerRadius: 10)
                .fill(bgColor)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(iconColor.opacity(0.3), lineWidth: 1)
        )
    }
    
    /// Helper view for deadline time text
    @ViewBuilder
    private func deadlineTimeText(deadlineDate: Date, formattedTime: String, isNearDeadline: Bool) -> some View {
        HStack(spacing: 4) {
            Text(deadlineDate, style: .date)
            Text("•")
            Text(formattedTime)
                .fontWeight(.semibold)
        }
        .font(.subheadline)
        .foregroundColor(isNearDeadline ? .orange : .primary)
    }
    
    /// Helper view for deadline progress indicator
    @ViewBuilder
    private func deadlineProgressView(isNearDeadline: Bool) -> some View {
        let totalDuration = ActiveOrderMonitor.orderDeadlineSeconds
        let elapsed = Date().timeIntervalSince(currentOrder.createdAt)
        let progress = min(elapsed / totalDuration, 1.0)
        let progressColor: Color = isNearDeadline ? .orange : .blue
        
        CircularProgressView(progress: progress, color: progressColor)
            .frame(width: 36, height: 36)
    }
    
    // MARK: - Status Timeline Section
    private var statusTimelineSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Order Timeline")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                timelineStep(
                    title: "Order Placed",
                    subtitle: "Order created and payment processed",
                    isCompleted: true,
                    date: currentOrder.createdAt
                )
                
                timelineStep(
                    title: "Seller Confirmed",
                    subtitle: "Seller has marked as delivered",
                    isCompleted: currentOrder.orderStatus.rawValue >= OrderStatus.sellerConfirmed.rawValue,
                    date: currentOrder.sellerConfirmedAt
                )
                
                timelineStep(
                    title: "Buyer Confirmed",
                    subtitle: "Buyer has confirmed receipt",
                    isCompleted: currentOrder.orderStatus == .completed,
                    date: currentOrder.completedAt
                )
                
                timelineStep(
                    title: "Completed",
                    subtitle: "Order delivered and funds released",
                    isCompleted: currentOrder.orderStatus == .completed,
                    date: currentOrder.completedAt
                )
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func timelineStep(title: String, subtitle: String, isCompleted: Bool, date: Date?) -> some View {
        HStack(spacing: 12) {
            // Status indicator
            Circle()
                .fill(isCompleted ? Color.green : Color.gray.opacity(0.3))
                .frame(width: 12, height: 12)
                .overlay(
                    Circle()
                        .stroke(Color.white, lineWidth: 2)
                )
            
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .primary : .secondary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                if let date = date {
                    Text(date, style: .date)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
            
            Spacer()
        }
    }
    
    // MARK: - Payment Details Section
    private var paymentDetailsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payment Details")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Show role-based pricing
                if isBuyer {
                    paymentDetailRow(title: "Amount Paid", value: currentOrder.formattedBuyerPrice)
                } else if isSeller {
                    paymentDetailRow(title: "Amount Received", value: currentOrder.formattedSellerPrice)
                    // NEVER show buyer price to seller - prevents off-platform deals
                } else {
                    paymentDetailRow(title: "Amount", value: currentOrder.formattedPrice)
                }
                
                paymentDetailRow(title: "Payment Method", value: currentOrder.paymentMethod.displayName)
                paymentDetailRow(title: "Payment Status", value: currentOrder.paymentStatus.displayName)
                paymentDetailRow(title: "Escrow Protection", value: "Active until completion")
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    private func paymentDetailRow(title: String, value: String, style: Date.FormatStyle? = nil) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    
    // MARK: - Delivery Photo Section
    private var deliveryPhotoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Delivery Proof")
                .font(.headline)
                .fontWeight(.semibold)
            
            if let photoURL = currentOrder.deliveryPhotoUrl {
                AsyncImage(url: URL(string: photoURL)) { phase in
                    switch phase {
                    case .empty:
                        ProgressView()
                            .frame(maxWidth: .infinity)
                            .frame(height: 200)
                    case .success(let image):
                        image
                            .resizable()
                            .scaledToFit()
                            .frame(maxWidth: .infinity)
                            .cornerRadius(8)
                    case .failure:
                        VStack(spacing: 8) {
                            Image(systemName: "photo.on.rectangle.angled")
                                .font(.largeTitle)
                                .foregroundColor(.gray)
                            Text("Failed to load image")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        .frame(maxWidth: .infinity)
                        .frame(height: 200)
                    @unknown default:
                        EmptyView()
                    }
                }
                
                Text("Photo uploaded by seller as proof of delivery")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Escrow Status Section
    private var escrowStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escrow Protection")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Get escrow status from service
            AsyncEscrowStatusView(orderId: currentOrder.id)
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    

    
    // MARK: - Actions Section
    private var actionsSection: some View {
        VStack(spacing: 16) {
            Text("Actions")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // PRIORITY: Payment Required - Confirm Order & Pay
                if needsPayment {
                    VStack(spacing: 12) {
                        // Warning banner
                        HStack(spacing: 12) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Payment Required")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Complete payment to confirm this order")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Confirm & Pay button
                        Button(action: {
                            Task { await handleConfirmAndPay() }
                        }) {
                            HStack(spacing: 8) {
                                if isProcessingPayment {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "creditcard.fill")
                                        .font(.headline)
                                    Text("Confirm Order & Pay")
                                        .font(.headline)
                                        .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessingPayment)
                    }
                }
                
                // Seller waiting for payment - show Contact Buyer button
                if isSeller && currentOrder.paymentStatus == .pending && currentOrder.orderStatus == .placed {
                    VStack(spacing: 12) {
                        // Info banner for seller
                        HStack(spacing: 12) {
                            Image(systemName: "clock.fill")
                                .foregroundColor(.blue)
                                .font(.title3)
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Waiting for Payment")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("The buyer needs to complete payment")
                                    .font(.caption)
                                    .foregroundColor(.secondary)
                            }
                            Spacer()
                        }
                        .padding()
                        .background(Color.blue.opacity(0.1))
                        .cornerRadius(12)
                        
                        // Contact Buyer button
                        Button(action: {
                            Task {
                                await openContactSheet()
                            }
                        }) {
                            HStack(spacing: 8) {
                                if isLoadingConversation {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                Image(systemName: "message.fill")
                                    .font(.headline)
                                Text("Contact Buyer")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                }
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.blue)
                            .cornerRadius(12)
                        }
                        .disabled(isLoadingConversation)
                    }
                }
                
                // Show PIN for buyers with service orders in 'placed' status
                if isBuyer && currentOrder.orderStatus == .placed && currentOrder.listing?.listingType == .service {
                    if let pin = currentOrder.verificationPin {
                        PINDisplayView(pin: pin)
                            .padding(.vertical, 8)
                    }
                }
                
                // CONTACT BUTTONS - Show first so users can coordinate before taking action
                
                // Contact Seller button for buyers (show for active orders)
                if isBuyer && currentOrder.orderStatus != .completed && currentOrder.orderStatus != .cancelled {
                    Button(action: {
                        Task {
                            await openContactSheet()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isLoadingConversation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                            Image(systemName: "message.fill")
                                .font(.headline)
                            Text("Coordinate with Seller")
                                .font(.headline)
                                .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingConversation)
                }
                
                // Contact Buyer button for sellers (show for ALL active orders not already handled above)
                if isSeller && currentOrder.orderStatus != .completed && currentOrder.orderStatus != .cancelled &&
                   !(currentOrder.paymentStatus == .pending && currentOrder.orderStatus == .placed) {
                    Button(action: {
                        Task {
                            await openContactSheet()
                        }
                    }) {
                        HStack(spacing: 8) {
                            if isLoadingConversation {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            } else {
                            Image(systemName: "message.fill")
                                .font(.headline)
                            Text("Coordinate with Buyer")
                                .font(.headline)
                                .fontWeight(.semibold)
                            }
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                    .disabled(isLoadingConversation)
                }
                
                // PRIMARY ACTION BUTTONS
                
                // BUYER: Confirm Product Received
                if canConfirmReceived {
                    Button(action: { showConfirmAlert = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.headline)
                            Text(currentOrder.listing?.listingType == .service ? "Confirm Service Completed" : "Confirm Product Received")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.green)
                        .cornerRadius(12)
                    }
                }
                
                // SELLER: Mark as Delivered
                if canMarkDelivered {
                    // For service orders: PIN entry or direct confirmation
                    if currentOrder.listing?.listingType == .service {
                        // Service orders don't need photo - just mark complete
                        Button(action: { 
                            Task { await markDelivered(with: "") }
                        }) {
                            HStack(spacing: 8) {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.headline)
                                Text("Mark Service Complete")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    } else {
                        // For product orders (or unknown): ALWAYS show photo upload
                        Button(action: { showDeliveryPhotoSheet = true }) {
                            HStack(spacing: 8) {
                                Image(systemName: "shippingbox.fill")
                                    .font(.headline)
                                Text("Mark as Delivered")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                            }
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                        }
                    }
                }
                
                // Show PIN entry button for sellers with service orders
                if isSeller && currentOrder.listing?.listingType == .service && 
                   (currentOrder.orderStatus == .placed || currentOrder.orderStatus == .inProgress) &&
                   currentOrder.verificationPin != nil {
                    
                    Button(action: { showPINEntrySheet = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "key.fill")
                                .font(.headline)
                            Text("Enter Service PIN")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.blue)
                        .cornerRadius(12)
                    }
                }
                
                // Cancel order button (only for buyers when seller hasn't confirmed)
                if canCancelOrder {
                    Button(action: { showCancelAlert = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "xmark.circle.fill")
                                .font(.headline)
                            Text("Cancel Order")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.red)
                        .cornerRadius(12)
                    }
                }
                
                if currentOrder.orderStatus != .completed && currentOrder.orderStatus != .cancelled {
                    Button(action: { showDisputeSheet = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .font(.headline)
                            Text("Report Problem")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.orange)
                        .cornerRadius(12)
                    }
                }
                
                // Show rating prompts for completed orders
                if currentOrder.orderStatus == .completed && AppConfig.enableRatings {
                    ratingSection
                }
                
                // Show message when no actions are available
                if !canConfirmReceived && !canMarkDelivered && currentOrder.orderStatus == .completed {
                    VStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.green)
                        Text("Order Completed!")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.green)
                        Text("Funds have been released to the seller.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                } else if !canConfirmReceived && !canMarkDelivered && currentOrder.orderStatus != .placed {
                    VStack(spacing: 8) {
                        Image(systemName: "clock")
                            .font(.title2)
                            .foregroundColor(.orange)
                        Text("Waiting for Action")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        Text("The order is waiting for the next step in the process.")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
    }
    
    // MARK: - Rating Section
    private var ratingSection: some View {
        VStack(spacing: 16) {
            Text("Rate Your Experience")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                // Rate seller button (for buyers)
                if isBuyer && canRateSeller && !hasRatedSeller {
                    Button(action: {
                        ratingType = .buyerToSeller
                        showRatingSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.headline)
                            Text("Rate Seller")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow.opacity(0.8))
                        .cornerRadius(12)
                    }
                } else if isBuyer && hasRatedSeller {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.star.fill")
                            .font(.headline)
                        Text("You rated the seller")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Rate buyer button (for sellers)
                if isSeller && canRateBuyer && !hasRatedBuyer {
                    Button(action: {
                        ratingType = .sellerToBuyer
                        showRatingSheet = true
                    }) {
                        HStack(spacing: 8) {
                            Image(systemName: "star.fill")
                                .font(.headline)
                            Text("Rate Buyer")
                                .font(.headline)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.white)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(Color.yellow.opacity(0.8))
                        .cornerRadius(12)
                    }
                } else if isSeller && hasRatedBuyer {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.star.fill")
                            .font(.headline)
                        Text("You rated the buyer")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(.green)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 16)
                    .background(Color.green.opacity(0.1))
                    .cornerRadius(12)
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Collapsible Order Information Section
    private var collapsibleOrderInfoSection: some View {
        VStack(spacing: 0) {
            // Dropdown Header
            Button(action: {
                withAnimation(.easeInOut(duration: 0.3)) {
                    showOrderInfo.toggle()
                }
            }) {
                HStack {
                    Text("Order Information")
                        .font(.headline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    Spacer()
                    
                    Image(systemName: showOrderInfo ? "chevron.up" : "chevron.down")
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.secondary)
                        .rotationEffect(.degrees(showOrderInfo ? 180 : 0))
                }
                .padding()
                .background(Color(.secondarySystemBackground))
                .cornerRadius(12)
            }
            .buttonStyle(PlainButtonStyle())
            
            // Collapsible Content
            if showOrderInfo {
                VStack(spacing: 16) {
                    // Debug Info Section
                    VStack(spacing: 12) {
                        Text("Debug Info")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 8) {
                            HStack {
                                Text("Order Status:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(currentOrder.orderStatus.displayName)
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("Payment Status:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(currentOrder.paymentStatus.rawValue)
                                    .foregroundColor(.blue)
                            }
                            
                            HStack {
                                Text("Is Seller:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(isSeller ? "Yes" : "No")
                                    .foregroundColor(isSeller ? .green : .facebookBlue)
                            }
                            
                            HStack {
                                Text("Is Buyer:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(isBuyer ? "Yes" : "No")
                                    .foregroundColor(isBuyer ? .green : .facebookBlue)
                            }
                            
                            HStack {
                                Text("Can Mark Delivered:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(canMarkDelivered ? "Yes" : "No")
                                    .foregroundColor(canMarkDelivered ? .green : .facebookBlue)
                            }
                            
                            HStack {
                                Text("Can Confirm Received:")
                                    .fontWeight(.medium)
                                Spacer()
                                Text(canConfirmReceived ? "Yes" : "No")
                                    .foregroundColor(canConfirmReceived ? .green : .facebookBlue)
                            }
                        }
                        .font(.caption)
                        .padding()
                        .background(Color.orange.opacity(0.1))
                        .cornerRadius(8)
                    }
                    
                    Divider()
                    
                    // Order Details Section
                    VStack(spacing: 12) {
                        Text("Order Details")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                        
                        VStack(spacing: 8) {
                            infoRow(title: "Order ID", value: currentOrder.id.uuidString)
                            infoRow(title: "Created", value: currentOrder.createdAt.formatted(date: .abbreviated, time: .shortened))
                            infoRow(title: "Buyer", value: String(currentOrder.buyerId.uuidString.prefix(8)))
                            infoRow(title: "Seller", value: String(currentOrder.sellerId.uuidString.prefix(8)))
                            
                            if let updatedAt = currentOrder.updatedAt {
                                infoRow(title: "Last Updated", value: updatedAt.formatted(date: .abbreviated, time: .shortened))
                            }
                        }
                    }
                }
                .padding()
                .background(Color(.systemBackground))
                .clipShape(RoundedRectangle(cornerRadius: 12))
                .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .padding(.horizontal)
    }
    
    private func infoRow(title: String, value: String) -> some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            Spacer()
            Text(value)
                .font(.subheadline)
                .fontWeight(.medium)
        }
    }
    

    
    // MARK: - Order Status Badge
    private var orderStatusBadge: some View {
        Text(currentOrder.orderStatus.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(currentOrder.orderStatus.badgeColor.opacity(0.15))
            .foregroundColor(currentOrder.orderStatus.badgeColor)
            .cornerRadius(16)
    }
    
    // MARK: - Actions
    private func confirmReceived() async {
        print("🔵 confirmReceived: Starting confirmation for order \(currentOrder.id)")
        isLoading = true
        do {
            print("🔵 confirmReceived: Calling OrderService.confirmDelivery...")
            // This calls the function that releases funds to seller and marks order as completed
            let updatedOrder = try await OrderService.shared.confirmDelivery(currentOrder.id)
            
            print("✅ confirmReceived: Order confirmed successfully, new status: \(updatedOrder.orderStatus.displayName)")
            
            await MainActor.run {
                // Update the current order
                self.currentOrder = updatedOrder
                
                // Show success view
                self.successMessage = currentOrder.listing?.listingType == .service 
                    ? "Service has been marked as completed. Payment has been released to the seller."
                    : "Product has been marked as received. Payment has been released to the seller."
                self.showSuccessView = true
                
                print("✅ Order confirmed - funds released to seller")
            }
        } catch {
            print("❌ confirmReceived: Failed to confirm delivery: \(error)")
            await MainActor.run {
                errorMessage = "Failed to confirm delivery: \(error.localizedDescription)"
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Payment Handling
    
    private func handleConfirmAndPay() async {
        isProcessingPayment = true
        
        do {
            print("💳 Configuring payment for existing order: \(currentOrder.id)")
            print("💳 Using listing_id from order: \(currentOrder.listingId)")
            
            // SIMPLER APPROACH: Use listing_id from the order with existing payment flow
            // The order already exists, webhook will update it instead of creating new one
            let (_, _, _) = try await paymentService.configurePaymentSheet(for: currentOrder.listingId.uuidString)
            
            await MainActor.run {
                // Get the TOPMOST view controller (not the one presenting this sheet)
                guard let windowScene = UIApplication.shared.connectedScenes.first as? UIWindowScene,
                      let window = windowScene.windows.first else {
                    errorMessage = "Unable to present payment sheet"
                    isProcessingPayment = false
                    return
                }
                
                // Get the topmost presented view controller
                var topVC = window.rootViewController
                while let presented = topVC?.presentedViewController {
                    topVC = presented
                }
                
                guard let presentingVC = topVC else {
                    errorMessage = "Unable to find presenting view controller"
                    isProcessingPayment = false
                    return
                }
                
                print("🔵 About to present payment sheet from TOPMOST view controller: \(type(of: presentingVC))")
                
                // Present the payment sheet from the topmost VC
                paymentService.presentPaymentSheet(from: presentingVC)
                
                print("🔵 Payment sheet present() called, polling for result...")
                
                // Poll for payment result
                Task { @MainActor in
                    var attempts = 0
                    let maxAttempts = 60 // 60 seconds timeout
                    
                    while attempts < maxAttempts {
                        try? await Task.sleep(nanoseconds: 1_000_000_000) // 1 second
                        
                        if let result = paymentService.paymentResult {
                            print("🔵 Got payment result after \(attempts) seconds: \(result)")
                            await handlePaymentResult(result)
                            paymentService.paymentResult = nil
                            isProcessingPayment = false
                            return
                        }
                        
                        attempts += 1
                    }
                    
                    // Timeout
                    isProcessingPayment = false
                    print("⚠️ Payment result timeout after 60 seconds")
                }
                
                isProcessingPayment = false
            }
        } catch {
            print("❌ Failed to configure payment: \(error)")
            print("❌ Error type: \(type(of: error))")
            print("❌ Error description: \(error.localizedDescription)")
            if let nsError = error as NSError? {
                print("❌ Error domain: \(nsError.domain)")
                print("❌ Error code: \(nsError.code)")
                print("❌ Error userInfo: \(nsError.userInfo)")
            }
            await MainActor.run {
                isProcessingPayment = false
                errorMessage = "Payment failed: \(error.localizedDescription)"
            }
        }
    }
    
    private func handlePaymentResult(_ result: PaymentSheetResult) async {
        switch result {
        case .completed:
            print("✅ Payment completed! Refreshing order...")
            
            // Show success immediately for better UX
            await MainActor.run {
                successMessage = "Payment completed! Your order has been confirmed. Waiting for seller to fulfill the order."
                showSuccessView = true
                showPaymentSheet = false
                isProcessingPayment = false
            }
            
            // Start listening for order updates via Realtime
            await setupRealtimeSubscription()
            
            // Also do a quick refresh to catch any immediate updates
            await loadOrderData()
            
            // Poll a few times as fallback (much shorter delays)
            for attempt in 1...3 {
                try? await Task.sleep(nanoseconds: 500_000_000) // 0.5 seconds
                await loadOrderData()
                
                // If payment status updated, we're done
                if currentOrder.paymentStatus != .pending {
                    print("✅ Order updated after \(attempt * 500)ms")
                    break
                }
            }
            
        case .canceled:
            print("⚠️ Payment cancelled by user")
            
        case .failed(let error):
            print("❌ Payment failed: \(error.localizedDescription)")
            print("❌ Payment error type: \(type(of: error))")
            print("❌ Payment error details: \(error)")
            if let nsError = error as NSError? {
                print("❌ Payment NSError domain: \(nsError.domain)")
                print("❌ Payment NSError code: \(nsError.code)")
                print("❌ Payment NSError userInfo: \(nsError.userInfo)")
            }
            await MainActor.run {
                errorMessage = "Payment failed: \(error.localizedDescription). Please try again or contact support."
            }
        }
    }
    
    // MARK: - Realtime Subscription
    
    private func setupRealtimeSubscription() async {
        // Clean up any existing subscription first
        await cleanupRealtimeSubscription()
        
        let channel = supabase.realtimeV2.channel("order:\(currentOrder.id.uuidString)")
        
        // Subscribe to UPDATE events on orders table for this specific order
        _ = channel.onPostgresChange(
            UpdateAction.self,
            schema: "public",
            table: "orders",
            filter: "id=eq.\(currentOrder.id.uuidString)"
        ) { [currentOrder] change in
            Task { @MainActor in
                do {
                    let orderData = try JSONEncoder().encode(change.record)
                    let updatedOrder = try JSONDecoder().decode(Order.self, from: orderData)
                    
                    print("🔄 Realtime update: Order payment_status changed to \(updatedOrder.paymentStatus.rawValue)")
                    
                    // Update the current order with the new data
                    self.currentOrder = updatedOrder
                    
                    // Invalidate cache to ensure consistency
                    DataCacheManager.shared.invalidateOrders()
                    
                } catch {
                    print("❌ Failed to parse realtime order update: \(error)")
                }
            }
        }
        
        // Subscribe to the channel
        await channel.subscribe()
        
        // Store reference for cleanup
        await MainActor.run {
            self.realtimeChannel = channel
        }
        
        print("✅ Realtime subscription setup for order: \(currentOrder.id)")
    }
    
    private func cleanupRealtimeSubscription() async {
        if let channel = realtimeChannel {
            await channel.unsubscribe()
            await MainActor.run {
                self.realtimeChannel = nil
            }
            print("🧹 Cleaned up realtime subscription for order")
        }
    }
    
    private func cancelOrder() async {
        print("🔵 cancelOrder: Starting cancellation for order \(currentOrder.id)")
        isLoading = true
        do {
            print("🔵 cancelOrder: Calling OrderService.cancelOrder...")
            let updatedOrder = try await OrderService.shared.cancelOrder(currentOrder.id)
            
            print("✅ cancelOrder: Order cancelled successfully, new status: \(updatedOrder.orderStatus.displayName)")
            
            await MainActor.run {
                // Update the current order
                self.currentOrder = updatedOrder
                
                // Show success view
                self.successMessage = "Order has been cancelled. The full amount has been refunded to your wallet."
                self.showSuccessView = true
                
                print("✅ Order cancelled - buyer refunded")
            }
        } catch {
            print("❌ cancelOrder: Failed to cancel order: \(error)")
            await MainActor.run {
                errorMessage = "Failed to cancel order: \(error.localizedDescription)"
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func markDelivered(with photoURL: String) async {
        print("🔵 Button clicked! markDelivered() called")
        isLoading = true
        print("🔵 markDelivered() called for order: \(currentOrder.id)")
        print("🔵 Current order status: \(currentOrder.orderStatus.displayName)")
        print("🔵 Current user is seller: \(isSeller)")
        print("🔵 Delivery photo URL: \(photoURL)")
        do {
            print("🔵 Calling OrderService.markDelivered...")
            let updatedOrder = try await OrderService.shared.markDelivered(currentOrder.id, deliveryPhotoUrl: photoURL)
            print("✅ markDelivered succeeded: \(updatedOrder.orderStatus.displayName)")
            
            await MainActor.run {
                // Update the current order
                self.currentOrder = updatedOrder
                
                // Show success view
                self.successMessage = currentOrder.listing?.listingType == .service
                    ? "Service has been marked as delivered. Waiting for buyer to confirm completion."
                    : "Product has been marked as delivered. Waiting for buyer to confirm receipt."
                self.showSuccessView = true
            }
        } catch {
            await MainActor.run {
                print("❌ markDelivered failed: \(error)")
                errorMessage = "Failed to mark as delivered: \(error.localizedDescription)"
                print("❌ Error message set to:", errorMessage ?? "nil")
            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    // MARK: - Rating Status
    
    private func checkRatingStatus() async {
        guard AppConfig.enableRatings,
              currentOrder.orderStatus == .completed,
              let currentUserId = authManager.currentUserId else {
            return
        }
        
        do {
            // Check if current user can rate seller (if they're the buyer)
            if isBuyer {
                let canRate = try await RatingService.shared.canSubmitRating(
                    orderId: currentOrder.id,
                    raterId: currentUserId,
                    ratedId: currentOrder.sellerId.uuidString
                )
                
                await MainActor.run {
                    canRateSeller = canRate
                    hasRatedSeller = !canRate // If can't rate, they already rated
                }
            }
            
            // Check if current user can rate buyer (if they're the seller)
            if isSeller {
                let canRate = try await RatingService.shared.canSubmitRating(
                    orderId: currentOrder.id,
                    raterId: currentUserId,
                    ratedId: currentOrder.buyerId.uuidString
                )
                
                await MainActor.run {
                    canRateBuyer = canRate
                    hasRatedBuyer = !canRate // If can't rate, they already rated
                }
            }
            
        } catch {
            print("Failed to check rating status: \(error)")
        }
    }
    
    private func loadOrderData() async {
        // Refresh order data from the service to prevent stale data issues
        do {
            let updatedOrder = try await OrderService.shared.getOrderDetails(currentOrder.id)
            await MainActor.run {
                // Update local state with fresh data from database
                self.currentOrder = updatedOrder
                print("🔄 Order refreshed:")
                print("   Order Status: \(updatedOrder.orderStatus.displayName)")
                print("   Payment Status: \(updatedOrder.paymentStatus.displayName)")
                print("   Can confirm received? \(canConfirmReceived)")
                print("   Needs payment? \(needsPayment)")
            }
        } catch {
            print("❌ Failed to refresh order data: \(error)")
        }
        await loadConversation()
    }
    
    private func openContactSheet() async {
        // If conversation already loaded, just show the sheet
        if activeConversation != nil {
            await MainActor.run {
                showContactSheet = true
            }
            return
        }
        
        // Otherwise, load the conversation first
        await MainActor.run {
            isLoadingConversation = true
        }
        
        await loadConversation()
        
        await MainActor.run {
            isLoadingConversation = false
            
            // Only show sheet if conversation was successfully loaded
            if activeConversation != nil {
                showContactSheet = true
            } else {
                errorMessage = "Failed to load conversation. Please try again."
            }
        }
    }
    
    private func loadConversation() async {
        guard let currentUserId = authManager.session?.user.id else { return }
        
        let otherUserId = isBuyer ? currentOrder.sellerId : currentOrder.buyerId
        
        do {
            // Find existing conversation - check BOTH directions
            // Conversation could have current user as buyer OR seller
            // IMPORTANT: Include buyer and seller user profiles for proper display names
            let existing: [Conversation] = try await supabase
                .from("conversations")
                .select("""
                    *,
                    buyer:buyer_id(*),
                    seller:seller_id(*),
                    listing:listing_id(*)
                """)
                .eq("listing_id", value: currentOrder.listingId.uuidString)
                .or("and(buyer_id.eq.\(currentUserId.uuidString),seller_id.eq.\(otherUserId.uuidString)),and(buyer_id.eq.\(otherUserId.uuidString),seller_id.eq.\(currentUserId.uuidString))")
                .limit(1)
                .execute()
                .value
            
            if let conversation = existing.first {
                print("✅ Found existing conversation: \(conversation.id)")
                print("   Buyer: \(conversation.buyer?.name ?? "nil")")
                print("   Seller: \(conversation.seller?.name ?? "nil")")
                await MainActor.run {
                    activeConversation = conversation
                }
                return
            }
            
            print("📝 Creating new conversation for order: \(currentOrder.id)")
            
            // Create new conversation if none exists
            struct ConversationInsert: Encodable {
                let buyer_id: String
                let seller_id: String
                let listing_id: String
                let order_id: String
            }
            
            let created: Conversation = try await supabase
                .from("conversations")
                .insert(ConversationInsert(
                    buyer_id: currentOrder.buyerId.uuidString,
                    seller_id: currentOrder.sellerId.uuidString,
                    listing_id: currentOrder.listingId.uuidString,
                    order_id: currentOrder.id.uuidString
                ))
                .select("""
                    *,
                    buyer:buyer_id(*),
                    seller:seller_id(*),
                    listing:listing_id(*)
                """)
                .single()
                .execute()
                .value
            
            print("✅ Created new conversation: \(created.id)")
            print("   Buyer: \(created.buyer?.name ?? "nil")")
            print("   Seller: \(created.seller?.name ?? "nil")")
            
            await MainActor.run {
                activeConversation = created
            }
        } catch {
            print("❌ Error loading conversation: \(error)")
        }
    }
    
    // MARK: - Success Overlay
    private var successOverlay: some View {
        VStack(spacing: 24) {
            Spacer()
            
            VStack(spacing: 20) {
                // Success checkmark animation
                ZStack {
                    Circle()
                        .fill(Color.green.opacity(0.1))
                        .frame(width: 120, height: 120)
                    
                    Circle()
                        .stroke(Color.green, lineWidth: 3)
                        .frame(width: 120, height: 120)
                    
                    Image(systemName: "checkmark")
                        .font(.system(size: 60, weight: .bold))
                        .foregroundColor(.green)
                }
                .transition(.scale.combined(with: .opacity))
                
                Text("Success!")
                    .font(.largeTitle)
                    .fontWeight(.bold)
                
                Text(successMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal)
                
                VStack(spacing: 12) {
                    Button(action: {
                        dismiss()
                    }) {
                        Text("Done")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color.green)
                            .cornerRadius(12)
                    }
                    
                    Button(action: {
                        showSuccessView = false
                    }) {
                        Text("View Order Details")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(Color("ThemeColor"))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 16)
                            .background(Color("ThemeColor").opacity(0.1))
                            .cornerRadius(12)
                    }
                }
                .padding(.horizontal)
            }
            .padding(24)
            .background(Color(UIColor.systemBackground))
            .cornerRadius(20)
            .shadow(radius: 20)
            .padding(.horizontal, 40)
            
            Spacer()
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(Color.black.opacity(0.3))
        .ignoresSafeArea()
        .transition(.opacity)
        .animation(.easeInOut, value: showSuccessView)
    }
}

// MARK: - Circular Progress View for Deadline
struct CircularProgressView: View {
    let progress: Double
    let color: Color
    
    var body: some View {
        ZStack {
            // Background circle
            Circle()
                .stroke(color.opacity(0.2), lineWidth: 3)
            
            // Progress circle
            Circle()
                .trim(from: 0, to: progress)
                .stroke(color, style: StrokeStyle(lineWidth: 3, lineCap: .round))
                .rotationEffect(.degrees(-90))
            
            // Percentage text
            Text("\(Int(progress * 100))%")
                .font(.system(size: 10, weight: .semibold))
                .foregroundColor(color)
        }
    }
}

// MARK: - Preview
struct OrderDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OrderDetailView(order: OrderWithDetails.sampleOrder.order)
                .environmentObject(AuthManager())
        }
    }
}
