import SwiftUI

struct MyTransactionsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var selection: Segment = .purchases
    @State private var purchases: [Order] = []
    @State private var sales: [Order] = []
    @State private var isLoading = true
    @State private var isRefreshing = false
    @State private var errorMessage: String?
    @State private var searchText = ""
    @State private var selectedStatusFilter: OrderStatus?
    @State private var showingFilters = false
    @State private var showSuccessToast = false
    @State private var successToastMessage = ""

    enum Segment: String, CaseIterable { 
        case purchases = "Purchases"
        case sales = "Sales" 
    }

    var body: some View {
        ZStack {
            content
                .navigationTitle("My Transactions")
                .searchable(text: $searchText, prompt: "Search orders...")
            
            // Success toast overlay
            if showSuccessToast {
                VStack {
                    HStack(spacing: 12) {
                        Image(systemName: "checkmark.circle.fill")
                            .font(.title2)
                            .foregroundColor(.white)
                        
                        Text(successToastMessage)
                            .font(.headline)
                            .fontWeight(.semibold)
                            .foregroundColor(.white)
                    }
                    .padding()
                    .background(Color.green)
                    .cornerRadius(12)
                    .shadow(radius: 10)
                    .transition(.move(edge: .top).combined(with: .opacity))
                    .animation(.spring(), value: showSuccessToast)
                    
                    Spacer()
                }
                .padding(.top, 50)
                .zIndex(1)
            }
        }
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button(action: { showingFilters.toggle() }) {
                        Image(systemName: "line.3.horizontal.decrease.circle")
                            .foregroundColor(selectedStatusFilter != nil ? .blue : .primary)
                    }
                }
            }
            .onAppear { Task { await loadData() } }
            .onDisappear {
                // Ensure no lingering modals cause dimming when leaving this tab
                errorMessage = nil
                showConfirmAlert = false
                showDeliveryPhotoSheet = false
                activeOrder = nil
                activeConversation = nil
            }
            .refreshable {
                await refreshData()
            }
            .alert(
                "Error",
                isPresented: Binding(
                    get: { errorMessage != nil },
                    set: { if !$0 { errorMessage = nil } }
                )
            ) {
                Button("OK") { errorMessage = nil }
            } message: {
                Text(errorMessage ?? "")
            }
            .alert("Confirm Received?", isPresented: $showConfirmAlert) {
                Button("Cancel", role: .cancel) { pendingCaptureOrder = nil }
                Button("Confirm") {
                    if let order = pendingCaptureOrder { Task { await confirmReceived(order: order) } }
                    pendingCaptureOrder = nil
                }
            } message: { Text("This will release funds to the seller.") }
            .sheet(isPresented: $showDeliveryPhotoSheet) {
                if let order = pendingDeliveredOrder {
                    DeliveryPhotoUploadView(orderId: order.id) { photoURL in
                        Task { await markDelivered(order, with: photoURL) }
                    }
                }
            }
            .sheet(item: $disputeDraft) { draft in
                ReportDisputeView(order: draft.order) {
                    Task { await loadData() }
                }
                .environmentObject(authManager)
            }
            .sheet(item: $disputeToView) { order in
                DisputeDetailView(order: order)
            }
            .fullScreenCover(item: $activeOrder) { order in
                TransactionActionSheetView(
                    order: order,
                    isBuyer: selection == .purchases,
                    canConfirm: order.paymentStatus == .requiresCapture && order.orderStatus == .sellerConfirmed,
                    onConfirm: { pendingCaptureOrder = order; showConfirmAlert = true },
                    onContactSeller: { Task { await contactSeller(order) } },
                    onReport: { reportProblem(order: order) }
                )
                .environmentObject(authManager)
            }
            .sheet(item: $activeConversation) { convo in
                ChatView(conversation: convo)
                    .environmentObject(authManager)
            }
            .sheet(isPresented: $showingFilters) {
                FilterSheet(
                    selectedStatus: $selectedStatusFilter,
                    onApply: { Task { await loadData() } }
                )
            }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 12) {
            // Enhanced segment picker with order counts
            enhancedSegmentPicker
            
            if isLoading && !isRefreshing {
                loadingView
            } else if let errorMessage = errorMessage {
                errorView(message: errorMessage)
            } else if filteredOrders.isEmpty {
                emptyStateView
            } else {
                transactionsList
            }
        }
    }
    
    @ViewBuilder
    private var enhancedSegmentPicker: some View {
        VStack(spacing: 8) {
            Picker("Type", selection: $selection) {
                ForEach(Segment.allCases, id: \.self) { seg in
                    Text("\(seg.rawValue) (\(segmentOrderCount(for: seg)))")
                        .tag(seg as Segment)
                }
            }
            .pickerStyle(SegmentedPickerStyle())
            .padding(.horizontal)
            
            // Status filter indicator
            if let filter = selectedStatusFilter {
                HStack {
                    Text("Filtered by: \(filter.displayName)")
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Button("Clear") {
                        selectedStatusFilter = nil
                        Task { await loadData() }
                    }
                    .font(.caption)
                    .foregroundColor(.blue)
                }
                .padding(.horizontal)
            }
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading your transactions...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func errorView(message: String) -> some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            Text("Something went wrong")
                .font(.headline)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            Button("Try Again") {
                Task { await loadData() }
            }
            .buttonStyle(.borderedProminent)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    @ViewBuilder
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: selection == .purchases ? "bag" : "tag")
                .font(.system(size: 48))
                .foregroundColor(.secondary)
            Text(selection == .purchases ? "No purchases yet" : "No sales yet")
                .font(.headline)
            Text(selection == .purchases ? 
                "When you buy items, they'll appear here" : 
                "When you sell items, they'll appear here")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }

    @ViewBuilder
    private var transactionsList: some View {
        List {
            ForEach(filteredOrders) { order in
                NavigationLink(destination: OrderDetailView(order: order)) {
                    TransactionRow(
                        order: order,
                        isBuyer: selection == .purchases,
                        onConfirmReceived: { pendingCaptureOrder = order; showConfirmAlert = true },
                        onReportProblem: { reportProblem(order: order) },
                        onMarkDelivered: { pendingDeliveredOrder = order; showDeliveryPhotoSheet = true }
                    )
                }
                .buttonStyle(PlainButtonStyle())
                .swipeActions(edge: .trailing, allowsFullSwipe: false) {
                    if selection == .purchases && order.paymentStatus == .requiresCapture && order.orderStatus == .sellerConfirmed {
                        Button("Confirm") {
                            pendingCaptureOrder = order
                            showConfirmAlert = true
                        }
                        .tint(.green)
                    }
                    
                    Button("Chat") {
                        Task { await contactSeller(order) }
                    }
                    .tint(.blue)
                }
            }
        }
        .listStyle(PlainListStyle())
        .overlay(
            Group {
                if isRefreshing {
                    VStack {
                        ProgressView()
                            .scaleEffect(0.8)
                        Text("Refreshing...")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .frame(maxWidth: .infinity)
                    .padding(.top, 20)
                }
            }
        )
    }
    
    // MARK: - Computed Properties
    
    private var filteredOrders: [Order] {
        let orders = selection == .purchases ? purchases : sales
        
        var filtered = orders
        
        // Apply status filter
        if let statusFilter = selectedStatusFilter {
            filtered = filtered.filter { $0.orderStatus == statusFilter }
        }
        
        // Apply search filter
        if !searchText.isEmpty {
            filtered = filtered.filter { order in
                order.listing?.title.localizedCaseInsensitiveContains(searchText) == true ||
                order.listing?.description.localizedCaseInsensitiveContains(searchText) == true ||
                order.id.uuidString.localizedCaseInsensitiveContains(searchText) == true
            }
        }
        
        return filtered
    }
    
    private func segmentOrderCount(for segment: Segment) -> Int {
        switch segment {
        case .purchases:
            return purchases.count
        case .sales:
            return sales.count
        }
    }

    // MARK: - Data

    private func loadData() async {
        guard let currentUserId = authManager.session?.user.id else { return }
        
        await MainActor.run { isLoading = true; errorMessage = nil }
        
        do {
            let purchaseResults: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("buyer_id", value: currentUserId.uuidString)
                .neq("order_status", value: "cancelled")
                .neq("payment_status", value: "failed")
                .order("created_at", ascending: false)
                .execute()
                .value

            let saleResults: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("seller_id", value: currentUserId.uuidString)
                .neq("order_status", value: "cancelled")
                .neq("payment_status", value: "failed")
                .order("created_at", ascending: false)
                .execute()
                .value

            await MainActor.run {
                self.purchases = purchaseResults
                self.sales = saleResults
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load transactions: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
    
    private func refreshData() async {
        await MainActor.run { isRefreshing = true }
        await loadData()
        await MainActor.run { isRefreshing = false }
    }

    // MARK: - Actions

    private func confirmReceived(order: Order) async {
        // Ensure caller is buyer
        guard let currentUserId = authManager.session?.user.id,
              order.buyerId == currentUserId else {
            await MainActor.run { errorMessage = "Only the buyer can confirm receipt." }
            return
        }
        // Only attempt capture when order is ready
        guard order.paymentStatus == .requiresCapture && order.orderStatus == .sellerConfirmed else {
            await MainActor.run { errorMessage = "This order isn't ready to complete yet." }
            return
        }
        do {
            try await OrderService.shared.updateOrderStatus(order.id, status: .completed)
            await MainActor.run {
                successToastMessage = order.listing?.listingType == .service 
                    ? "Service marked as completed! ✅"
                    : "Product marked as received! ✅"
                showSuccessToast = true
                
                // Hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showSuccessToast = false
                }
            }
            await loadData()
        } catch {
            await MainActor.run { errorMessage = "Failed to confirm receipt: \(error.localizedDescription)" }
        }
    }

    private func markDelivered(_ order: Order, with photoURL: String) async {
        // Verify current user is seller
        guard let currentUserId = authManager.session?.user.id,
              order.sellerId == currentUserId else {
            await MainActor.run { errorMessage = "Only the seller can mark delivered." }
            return
        }
        do {
            try await OrderService.shared.markDelivered(order.id, deliveryPhotoUrl: photoURL)
            await MainActor.run {
                successToastMessage = order.listing?.listingType == .service
                    ? "Service marked as delivered! ✅"
                    : "Product marked as delivered! ✅"
                showSuccessToast = true
                pendingDeliveredOrder = nil
                
                // Hide toast after 3 seconds
                DispatchQueue.main.asyncAfter(deadline: .now() + 3) {
                    showSuccessToast = false
                }
            }
            await loadData()
        } catch {
            await MainActor.run { errorMessage = "Failed to mark as delivered: \(error.localizedDescription)" }
        }
    }

    @State private var disputeDraft: DisputeDraft?
    @State private var disputeToView: Order?
    @State private var pendingCaptureOrder: Order?
    @State private var pendingDeliveredOrder: Order?
    @State private var showConfirmAlert = false
    @State private var showDeliveredAlert = false
    @State private var showDeliveryPhotoSheet = false
    @State private var activeOrder: Order?
    @State private var activeConversation: Conversation?

    private func reportProblem(order: Order) {
        disputeDraft = DisputeDraft(order: order)
    }
    private func viewDispute(order: Order) {
        disputeToView = order
    }

    private func contactSeller(_ order: Order) async {
        guard let currentUserId = authManager.session?.user.id else { return }
        
        let otherUserId = selection == .purchases ? order.sellerId : order.buyerId
        
        do {
            // find existing
            let existing: [Conversation] = try await supabase
                .from("conversations")
                .select("*")
                .eq("buyer_id", value: currentUserId.uuidString)
                .eq("seller_id", value: otherUserId.uuidString)
                .eq("listing_id", value: order.listingId.uuidString)
                .limit(1)
                .execute()
                .value
            if let convo = existing.first {
                await MainActor.run { activeConversation = convo }
                return
            }
            // create using an Encodable struct
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
            await MainActor.run { activeConversation = created }
        } catch {
            await MainActor.run { errorMessage = "Unable to open chat: \(error.localizedDescription)" }
        }
    }
}

// MARK: - Filter Sheet

struct FilterSheet: View {
    @Binding var selectedStatus: OrderStatus?
    let onApply: () -> Void
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            List {
                Section("Order Status") {
                    Button("All Orders") {
                        selectedStatus = nil
                    }
                    .foregroundColor(selectedStatus == nil ? .blue : .primary)
                    
                    ForEach(OrderStatus.allCases, id: \.self) { status in
                        Button(status.displayName) {
                            selectedStatus = status
                        }
                        .foregroundColor(selectedStatus == status ? .blue : .primary)
                    }
                }
            }
            .navigationTitle("Filter Orders")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        dismiss()
                    }
                }
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Apply") {
                        onApply()
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Row

    private struct TransactionRow: View {
        let order: Order
        let isBuyer: Bool
        let onConfirmReceived: () -> Void
        let onReportProblem: () -> Void
        var onMarkDelivered: (() -> Void)? = nil
        var onViewDispute: (() -> Void)? = nil

        private var statusBadgeColor: Color {
            order.orderStatus.badgeColor
        }

        private var canConfirm: Bool {
            isBuyer && order.paymentStatus == .requiresCapture && order.orderStatus == .sellerConfirmed
        }

        private var statusLabel: String {
            order.orderStatus.displayName
        }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(order.listing?.title ?? "Listing")
                        .font(.headline)
                        .lineLimit(2)
                    // Show role-based pricing
                    if isBuyer {
                        Text(order.formattedBuyerPrice)
                            .font(.subheadline)
                            .foregroundColor(Color("ThemeColor"))
                    } else {
                        Text(order.formattedSellerPrice)
                            .font(.subheadline)
                            .foregroundColor(Color("ThemeColor"))
                    }
                }
                Spacer()
                VStack(alignment: .trailing, spacing: 4) {
                    Text(statusLabel)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(statusBadgeColor.opacity(0.15))
                        .foregroundColor(statusBadgeColor)
                        .cornerRadius(8)
                    
                    Text(order.createdAt.formatted(date: .abbreviated, time: .omitted))
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }

            // Summary badges row
            HStack(spacing: 8) {
                if order.orderStatus == .disputed {
                    CampusLink.badge(text: "Disputed", color: .orange)
                }
                if order.paymentStatus == .requiresCapture {
                    CampusLink.badge(text: "Requires Capture", color: .orange)
                }
                if order.orderStatus == .completed {
                    CampusLink.badge(text: "Completed", color: .green)
                }
                if order.paymentStatus == .succeeded {
                    CampusLink.badge(text: "Paid", color: .green)
                }
            }

            HStack(spacing: 12) {
                if isBuyer {
                    Button(action: onConfirmReceived) {
                        Text("Confirm Received")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(canConfirm ? Color.green : Color.gray.opacity(0.3))
                            .foregroundColor(.white)
                            .cornerRadius(8)
                    }
                    .disabled(!canConfirm)
                }

                if !isBuyer {
                    Button(action: { onMarkDelivered?() }) {
                        Text("Mark Delivered")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                }

                if order.orderStatus == .disputed {
                    Button(action: { onViewDispute?() }) {
                        Text("View Dispute")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.orange.opacity(0.15))
                            .foregroundColor(.orange)
                            .cornerRadius(8)
                    }
                } else {
                    Button(action: onReportProblem) {
                        Text("Report Problem")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.facebookBlue.opacity(0.1))
                            .foregroundColor(.facebookBlue)
                            .cornerRadius(8)
                    }
                }
            }
        }
        .padding(.vertical, 8)
    }
}

private struct DisputeDraft: Identifiable {
    let id = UUID()
    let order: Order
}

// MARK: - Small badge view
private func badge(text: String, color: Color) -> some View {
    Text(text)
        .font(.caption2)
        .fontWeight(.medium)
        .padding(.horizontal, 6)
        .padding(.vertical, 3)
        .background(color.opacity(0.15))
        .foregroundColor(color)
        .cornerRadius(6)
}

// MARK: - Seller mark delivered

struct MyTransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        MyTransactionsView()
            .environmentObject(AuthManager())
    }
}


