import SwiftUI

struct OrderDetailView: View {
    let order: Order
    @EnvironmentObject private var authManager: AuthManager
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var showConfirmAlert = false
    @State private var showDisputeSheet = false
    @State private var showContactSheet = false
    @State private var activeConversation: Conversation?
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
    @Environment(\.dismiss) private var dismiss
    
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
        isBuyer && currentOrder.paymentStatus == .succeeded && currentOrder.orderStatus == .sellerConfirmed
    }
    
    private var canMarkDelivered: Bool {
        isSeller && (currentOrder.orderStatus == .placed || currentOrder.orderStatus == .inProgress)
    }
    
    private var canCancelOrder: Bool {
        isBuyer && currentOrder.orderStatus == .placed
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
                    showContactSheet = true
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
                // Show PIN for buyers with service orders in 'placed' status
                if isBuyer && currentOrder.orderStatus == .placed && currentOrder.listing?.listingType == .service {
                    if let pin = currentOrder.verificationPin {
                        PINDisplayView(pin: pin)
                            .padding(.vertical, 8)
                    }
                }
                
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
                
                // Show photo upload for product orders only
                if canMarkDelivered && currentOrder.listing?.listingType == .product {
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
                        .background(Color.facebookBlue)
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
                } else if !canConfirmReceived && !canMarkDelivered && currentOrder.orderStatus == .placed {
                    // Show coordination message for placed orders
                    VStack(spacing: 8) {
                        Image(systemName: "bubble.left.and.bubble.right.fill")
                            .font(.title2)
                            .foregroundColor(.blue)
                        Text(isBuyer ? "Coordinate with Seller" : "Coordinate with Buyer")
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.blue)
                        Text(isBuyer ? "Coordinate with seller to complete transaction" : "Coordinate with buyer to complete transaction")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.blue.opacity(0.1))
                    .cornerRadius(12)
                } else if !canConfirmReceived && !canMarkDelivered {
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
        // Refresh order data from the service
        do {
            let updatedOrder = try await OrderService.shared.getOrderDetails(currentOrder.id)
            // In a real app, you would update the local order state
            // For now, we'll just ensure the conversation is loaded
            print("✅ Order data refreshed")
        } catch {
            print("❌ Failed to refresh order data: \(error)")
        }
        await loadConversation()
    }
    
    private func loadConversation() async {
        guard let currentUserId = authManager.session?.user.id else { return }
        
        let otherUserId = isBuyer ? currentOrder.sellerId : currentOrder.buyerId
        
        do {
            // Find existing conversation
            let existing: [Conversation] = try await supabase
                .from("conversations")
                .select("*")
                .eq("buyer_id", value: currentUserId.uuidString)
                .eq("seller_id", value: otherUserId.uuidString)
                .eq("listing_id", value: currentOrder.listingId.uuidString)
                .limit(1)
                .execute()
                .value
            
            if let conversation = existing.first {
                await MainActor.run {
                    activeConversation = conversation
                }
                return
            }
            
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
                .select("*")
                .single()
                .execute()
                .value
            
            await MainActor.run {
                activeConversation = created
            }
        } catch {
            print("Error loading conversation: \(error)")
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

// MARK: - Preview
struct OrderDetailView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            OrderDetailView(order: OrderWithDetails.sampleOrder.order)
                .environmentObject(AuthManager())
        }
    }
}
