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
    
    private var isBuyer: Bool {
        authManager.session?.user.id == order.buyerId
    }
    
    private var isSeller: Bool {
        authManager.session?.user.id == order.sellerId
    }
    
    private var canConfirmReceived: Bool {
        isBuyer && order.paymentStatus == .succeeded && order.orderStatus == .sellerConfirmed
    }
    
    private var canMarkDelivered: Bool {
        isSeller && (order.orderStatus == .placed || order.orderStatus == .inProgress)
    }
    
    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // Header Section
                headerSection
                
                // Order Status Timeline
                statusTimelineSection
                
                // Payment Details
                paymentDetailsSection
                
                // Escrow Status (if applicable)
                if order.hasEscrowAccount {
                    escrowStatusSection
                }
                
                // Actions Section
                actionsSection
                
                // Debug Section (for development)
                debugSection
                
                // Order Information
                orderInfoSection
            }
            .padding()
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
        .alert(order.listing?.listingType == .service ? "Confirm Service Completed?" : "Confirm Product Received?", isPresented: $showConfirmAlert) {
            Button("Cancel", role: .cancel) { }
            Button("Confirm") {
                Task { await confirmReceived() }
            }
        } message: {
            Text("This will release the payment to the seller and complete the transaction.")
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
        .onAppear {
            Task { await loadOrderData() }
        }
    }
    
    // MARK: - Header Section
    private var headerSection: some View {
        VStack(spacing: 16) {
            // Order ID
            HStack {
                Text("Order #\(order.id.uuidString.prefix(8))")
                    .font(.title2)
                    .fontWeight(.bold)
                Spacer()
                orderStatusBadge
            }
            
            // Listing Info
            if let listing = order.listing {
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
                    date: order.createdAt
                )
                
                timelineStep(
                    title: "Seller Confirmed",
                    subtitle: "Seller has marked as delivered",
                    isCompleted: order.orderStatus.rawValue >= OrderStatus.sellerConfirmed.rawValue,
                    date: order.sellerConfirmedAt
                )
                
                timelineStep(
                    title: "Buyer Confirmed",
                    subtitle: "Buyer has confirmed receipt",
                    isCompleted: order.orderStatus == .completed,
                    date: order.completedAt
                )
                
                timelineStep(
                    title: "Completed",
                    subtitle: "Order delivered and funds released",
                    isCompleted: order.orderStatus == .completed,
                    date: order.completedAt
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
                paymentDetailRow(title: "Amount", value: order.formattedPrice)
                paymentDetailRow(title: "Payment Method", value: order.paymentMethod.displayName)
                paymentDetailRow(title: "Payment Status", value: order.paymentStatus.displayName)
                paymentDetailRow(title: "Escrow Protection", value: "Active until completion")
                
                if let autoReleaseAt = order.autoReleaseAt {
                    paymentDetailRow(title: "Auto-Release", value: autoReleaseAt.formatted(date: .abbreviated, time: .shortened))
                }
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
    
    // MARK: - Escrow Status Section
    private var escrowStatusSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Escrow Protection")
                .font(.headline)
                .fontWeight(.semibold)
            
            // Get escrow status from service
            AsyncEscrowStatusView(orderId: order.id)
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
                if canConfirmReceived {
                    Button(action: { showConfirmAlert = true }) {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.circle.fill")
                                .font(.headline)
                            Text(order.listing?.listingType == .service ? "Confirm Service Completed" : "Confirm Product Received")
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
                
                if canMarkDelivered {
                    Button(action: { Task { await markDelivered() } }) {
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
                
                if order.orderStatus != .completed && order.orderStatus != .cancelled {
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
                
                // Show message when no actions are available
                if !canConfirmReceived && !canMarkDelivered && order.orderStatus == .completed {
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
    
    // MARK: - Debug Section
    private var debugSection: some View {
        VStack(spacing: 16) {
            Text("Debug Info")
                .font(.headline)
                .fontWeight(.semibold)
                .foregroundColor(.orange)
            
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("Order Status:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(order.orderStatus.displayName)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Payment Status:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(order.paymentStatus.rawValue)
                        .foregroundColor(.blue)
                }
                
                HStack {
                    Text("Is Seller:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(isSeller ? "Yes" : "No")
                        .foregroundColor(isSeller ? .green : .red)
                }
                
                HStack {
                    Text("Is Buyer:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(isBuyer ? "Yes" : "No")
                        .foregroundColor(isBuyer ? .green : .red)
                }
                
                HStack {
                    Text("Can Mark Delivered:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(canMarkDelivered ? "Yes" : "No")
                        .foregroundColor(canMarkDelivered ? .green : .red)
                }
                
                HStack {
                    Text("Can Confirm Received:")
                        .fontWeight(.medium)
                    Spacer()
                    Text(canConfirmReceived ? "Yes" : "No")
                        .foregroundColor(canConfirmReceived ? .green : .red)
                }
            }
            .font(.caption)
            .padding()
            .background(Color.orange.opacity(0.1))
            .cornerRadius(8)
        }
        .padding()
    }
    
    // MARK: - Order Information Section
    private var orderInfoSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Order Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                infoRow(title: "Order ID", value: order.id.uuidString)
                infoRow(title: "Created", value: order.createdAt.formatted(date: .abbreviated, time: .shortened))
                infoRow(title: "Buyer", value: String(order.buyerId.uuidString.prefix(8)))
                infoRow(title: "Seller", value: String(order.sellerId.uuidString.prefix(8)))
                
                if let updatedAt = order.updatedAt {
                    infoRow(title: "Last Updated", value: updatedAt.formatted(date: .abbreviated, time: .shortened))
                }
            }
        }
        .padding()
        .background(Color(.systemBackground))
        .cornerRadius(12)
        .shadow(color: .black.opacity(0.05), radius: 2, x: 0, y: 1)
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
        Text(order.orderStatus.displayName)
            .font(.caption)
            .fontWeight(.semibold)
            .padding(.horizontal, 12)
            .padding(.vertical, 6)
            .background(order.orderStatus.badgeColor.opacity(0.15))
            .foregroundColor(order.orderStatus.badgeColor)
            .cornerRadius(16)
    }
    
    // MARK: - Actions
    private func confirmReceived() async {
        print("🔵 confirmReceived: Starting confirmation for order \(order.id)")
        isLoading = true
        do {
            print("🔵 confirmReceived: Calling OrderService.confirmDelivery...")
            // This calls the function that releases funds to seller and marks order as completed
            let updatedOrder = try await OrderService.shared.confirmDelivery(order.id)
            
            print("✅ confirmReceived: Order confirmed successfully, new status: \(updatedOrder.orderStatus.displayName)")
            
            await MainActor.run {
                // Refresh order data to show updated status
                Task {
                    await loadOrderData()
                }
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
    
    private func markDelivered() async {
        print("🔵 Button clicked! markDelivered() called")
        isLoading = true
        print("🔵 markDelivered() called for order: \(order.id)")
        print("🔵 Current order status: \(order.orderStatus.displayName)")
        print("🔵 Current user is seller: \(isSeller)")
        do {
            print("🔵 Calling OrderService.markDelivered...")
            let updatedOrder = try await OrderService.shared.markDelivered(order.id)
            print("✅ markDelivered succeeded: \(updatedOrder.orderStatus.displayName)")
            // Refresh order data
            await loadOrderData()
        } catch {
            await MainActor.run {
                print("❌ markDelivered failed: \(error)")
                errorMessage = "Failed to mark as delivered: \(error.localizedDescription)"
                print("❌ Error message set to:", errorMessage ?? "nil")            }
        }
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func loadOrderData() async {
        // Refresh order data from the service
        do {
            let updatedOrder = try await OrderService.shared.getOrderDetails(order.id)
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
        
        let otherUserId = isBuyer ? order.sellerId : order.buyerId
        
        do {
            // Find existing conversation
            let existing: [Conversation] = try await supabase
                .from("conversations")
                .select("*")
                .eq("buyer_id", value: currentUserId.uuidString)
                .eq("seller_id", value: otherUserId.uuidString)
                .eq("listing_id", value: order.listingId.uuidString)
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
                    buyer_id: order.buyerId.uuidString,
                    seller_id: order.sellerId.uuidString,
                    listing_id: order.listingId.uuidString,
                    order_id: order.id.uuidString
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
