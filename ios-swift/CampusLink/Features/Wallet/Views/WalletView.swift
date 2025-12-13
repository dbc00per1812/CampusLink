import SwiftUI
import SafariServices

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @EnvironmentObject private var tabCoordinator: TabCoordinator
    @State private var selectedTransaction: PaymentTransaction?
    @State private var selectedOrder: Order?
    @State private var selectedOffer: UserOffer?
    @State private var selectedPendingTransaction: PendingTransaction?
    @State private var showingOfferAcceptance = false
    @State private var isProcessingOffer = false
    @State private var offerError: String?
    @State private var shouldHighlightOffers = false
    
    var body: some View {
        NavigationView {
            ScrollView {
                ResponsiveVStack(spacing: 24) {
                    // Balance Card
                    balanceCard
                    
                    // Action Buttons
                    actionButtons
                    
                    // Pending Transactions (Unified)
                    pendingTransactionsSection
                    
                    // Transaction History
                    transactionHistory
                }
                .responsivePadding(16)
            }
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { 
                // Only refresh if user is authenticated
                guard authManager.session != nil else {
                    print("🔵 WalletView: Skipping refresh - no authentication session")
                    return
                }
                await viewModel.refreshData() 
            }
        }
        .onChange(of: tabCoordinator.walletShouldFocusOffers) { shouldFocus in
            if shouldFocus {
                // Refresh offers when navigating from "View My Offers" button
                Task {
                    await viewModel.loadPendingOffers()
                }
                
                withAnimation(.easeInOut(duration: 0.3)) {
                    shouldHighlightOffers = true
                }
                
                // Reset highlight after animation
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                    withAnimation(.easeOut(duration: 0.3)) {
                        shouldHighlightOffers = false
                    }
                }
            }
        }
        .task { 
            // Only load wallet data if user is authenticated
            guard authManager.session != nil else {
                print("🔵 WalletView: Skipping wallet data load - no authentication session")
                return
            }
            
            await viewModel.loadWalletData()
            if AppConfig.enableSeekMode {
                await viewModel.loadPendingOffers()
            }
            await viewModel.loadPendingTransactions()
        }
        .sheet(isPresented: $viewModel.showPayoutRequestSheet, onDismiss: { viewModel.showPayoutRequestSheet = false }) { 
            // ✅ Pass STRIPE balance (source of truth), not database wallet
                PayoutRequestView(
                availableBalance: viewModel.stripeBalance?.availableStandard ?? 0,
                pendingBalance: viewModel.stripeBalance?.pending ?? 0,
                    onPayoutRequested: { payout in
                        viewModel.showPayoutRequestSheet = false
                        // Refresh wallet data after payout request
                        Task {
                            await viewModel.refreshData()
                        }
                    },
                    onDismiss: {
                        viewModel.showPayoutRequestSheet = false
                    }
                )
        }
        .sheet(isPresented: $viewModel.showPayoutHistorySheet, onDismiss: { viewModel.showPayoutHistorySheet = false }) {
            if let userId = authManager.session?.user.id.uuidString {
                PayoutHistoryView(userId: userId)
            }
        }
        .sheet(item: $viewModel.onboardingLink, onDismiss: { 
            viewModel.onboardingLink = nil
            // Refresh data after onboarding to update Stripe Connect status
            Task {
                await viewModel.refreshData()
            }
        }) { link in
            SafariView(url: link.url).ignoresSafeArea()
        }
        .sheet(isPresented: $showingOfferAcceptance) {
            if let offer = selectedOffer {
                OfferAcceptanceDetailView(
                    userOffer: offer,
                    isProcessing: $isProcessingOffer,
                    errorMessage: $offerError,
                    onAccept: { acceptOffer(offer) },
                    onDecline: { declineOffer(offer) },
                    onDismiss: { showingOfferAcceptance = false }
                )
            }
        }
        .sheet(item: $selectedPendingTransaction) { transaction in
            PendingTransactionDetailView(transaction: transaction)
                .environmentObject(authManager)
        }
        .alert("Wallet", isPresented: $viewModel.isShowingError) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
        .onDisappear {
            // Ensure no overlays linger when switching tabs
            viewModel.showPayoutRequestSheet = false
            viewModel.showPayoutHistorySheet = false
            viewModel.onboardingLink = nil
            viewModel.errorMessage = nil
        }
    }
    
    // MARK: - Balance Card
    private var balanceCard: some View {
        ResponsiveVStack(spacing: 0) {
            // Available Balance
            HStack {
                ResponsiveVStack(spacing: 4, alignment: .leading) {
                    Text("Available Balance")
                        .responsiveFont(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.wallet?.formattedAvailableBalance ?? "$0.00")
                        .responsiveFontSize(36, weight: .bold)
                        .foregroundColor(Color("ThemeColor"))
                }
                Spacer()
                Image(systemName: "creditcard.fill")
                    .responsiveFontSize(28)
                    .foregroundColor(Color("ThemeColor").opacity(0.7))
            }
            .responsivePadding(16)
            
            Divider()
            
            // Escrow Balance
            if let wallet = viewModel.wallet, wallet.hasEscrowBalance {
                HStack {
                    ResponsiveVStack(spacing: 4, alignment: .leading) {
                        Text("In Escrow")
                            .responsiveFont(.caption)
                            .foregroundColor(.secondary)
                        Text(wallet.formattedEscrowBalance)
                            .responsiveFontSize(20, weight: .semibold)
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .responsiveFontSize(16)
                        .foregroundColor(.orange.opacity(0.7))
                }
                .responsivePadding(16)
                .background(Color.orange.opacity(0.1))
            }
            
            // Total Balance Footer
            HStack {
                Text("Total Balance")
                    .responsiveFont(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(viewModel.wallet?.formattedTotalBalance ?? "$0.00")
                    .responsiveFontSize(18, weight: .semibold)
            }
            .responsivePadding(16)
            .background(Color(UIColor.secondarySystemBackground))
        }
        .background(Color(UIColor.secondarySystemBackground))
        .responsiveCornerRadius(16)
        .shadow(color: Color.black.opacity(0.15), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        HStack(spacing: 12) {
            // Request Payout Button
            Button(action: {
                if viewModel.hasStripeConnectAccount {
                    viewModel.showPayoutRequestSheet = true
                } else {
                    Task {
                        await viewModel.startStripeOnboarding()
                    }
                }
            }) {
                HStack {
                    Image(systemName: viewModel.hasStripeConnectAccount ? "banknote" : "link")
                    Text(viewModel.hasStripeConnectAccount ? "Request Payout" : "Complete Payout Setup")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("ThemeColor"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            
            // Payout History Button (only show if Stripe Connect is set up)
            if viewModel.hasStripeConnectAccount {
                Button(action: {
                    viewModel.showPayoutHistorySheet = true
                }) {
                    HStack {
                        Image(systemName: "clock.arrow.circlepath")
                        Text("History")
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(.secondarySystemBackground))
                    .foregroundColor(.primary)
                    .cornerRadius(12)
                }
            }
        }
    }
    
    // MARK: - Pending Transactions Section
    private var pendingTransactionsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Pending Transactions")
                    .font(.headline)
                Spacer()
                    NavigationLink(destination: AllPendingTransactionsView(
                        transactions: viewModel.pendingTransactions
                    ).environmentObject(authManager)) {
                        Text("See All")
                            .font(.subheadline)
                            .foregroundColor(Color("ThemeColor"))
                }
            }
            
            if viewModel.isLoadingPendingTransactions {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if viewModel.pendingTransactions.isEmpty {
                Text("No pending transactions")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 8) {
                    ForEach(viewModel.pendingTransactions.prefix(5)) { transaction in
                        pendingTransactionRow(transaction)
                    }
                }
            }
        }
        .padding(shouldHighlightOffers ? 8 : 0)
        .background(
            RoundedRectangle(cornerRadius: 12)
                .fill(shouldHighlightOffers ? Color.blue.opacity(0.1) : Color.clear)
                .overlay(
                    RoundedRectangle(cornerRadius: 12)
                        .stroke(shouldHighlightOffers ? Color.blue.opacity(0.3) : Color.clear, lineWidth: 2)
                )
        )
        .animation(.easeInOut(duration: 0.3), value: shouldHighlightOffers)
    }
    
    // MARK: - Pending Transaction Row
    private func pendingTransactionRow(_ transaction: PendingTransaction) -> some View {
        Button(action: {
            // Navigate to appropriate detail view based on transaction type
            if let order = transaction.order {
                // Navigate to order detail
                selectedOrder = order
            } else if transaction.offer != nil || transaction.payout != nil {
                // Show pending transaction detail for offers and payouts
                selectedPendingTransaction = transaction
            }
        }) {
            HStack {
                VStack(alignment: .leading, spacing: 6) {
                    // Type tag
                    HStack(spacing: 4) {
                        Image(systemName: transaction.typeIcon)
                            .font(.caption)
                        Text(transaction.typeTag)
                            .font(.caption)
                            .fontWeight(.semibold)
                    }
                    .foregroundColor(transaction.typeColor)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(transaction.typeColor.opacity(0.15))
                    .cornerRadius(6)
                    
                    // Title
                    Text(transaction.title)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.primary)
                        .lineLimit(1)
                    
                    // Amount
                    Text(transaction.amount)
                        .font(.headline)
                        .fontWeight(.bold)
                        .foregroundColor(Color("ThemeColor"))
                    
                    // From/To info
                    if let fromUser = transaction.fromUser {
                        HStack(spacing: 4) {
                            Text("From:")
                                .font(.caption)
                                .foregroundColor(.secondary)
                            Text(fromUser)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(.primary)
                        }
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 6) {
                    // Status badge
                    Text(transaction.status)
                        .font(.caption2)
                        .fontWeight(.medium)
                        .padding(.horizontal, 6)
                        .padding(.vertical, 3)
                        .background(transaction.statusColor.opacity(0.15))
                        .foregroundColor(transaction.statusColor)
                        .cornerRadius(6)
                    
                    // Time
                    Text(transaction.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Arrow
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Transaction History
    private var transactionHistory: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Recent Transactions")
                    .font(.headline)
                Spacer()
                NavigationLink(destination: MyTransactionsView()) {
                    Text("See All")
                        .font(.subheadline)
                        .foregroundColor(Color("ThemeColor"))
                }
            }
            
            if viewModel.isLoading {
                HStack {
                    Spacer()
                    ProgressView()
                        .padding()
                    Spacer()
                }
            } else if viewModel.transactions.isEmpty {
                Text("No transactions yet")
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
            } else {
                VStack(spacing: 12) {
                    ForEach(viewModel.transactions.prefix(5)) { transaction in
                        transactionRow(transaction)
                    }
                }
            }
        }
    }
    
    // MARK: - Transaction Row (Order Widget)
    private func transactionRow(_ transaction: PaymentTransaction) -> some View {
        Button(action: {
            Task {
                await loadOrderForTransaction(transaction)
            }
        }) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(transaction.listing?.title ?? "Order")
                            .font(.headline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        Text(transaction.formattedAmount)
                            .font(.subheadline)
                            .foregroundColor(Color("ThemeColor"))
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        // Status badge - use order status if available, otherwise fall back to payment status
                        let statusText = getOrderStatusText(for: transaction)
                        let statusColor = getOrderStatusColor(for: transaction)
                        Text(statusText)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(statusColor.opacity(0.15))
                            .foregroundColor(statusColor)
                            .cornerRadius(8)
                        
                        Text(transaction.createdAt.formatted(date: .abbreviated, time: .omitted))
                            .font(.caption2)
                            .foregroundColor(.secondary)
                    }
                }

                // Summary badges row
                HStack(spacing: 8) {
                    // Sale/Purchase badge - show first for clarity
                    if let currentUserId = authManager.currentUserId {
                        if transaction.sellerId == currentUserId {
                            badge(text: "Sale", color: .blue)
                        } else if transaction.buyerId == currentUserId {
                            badge(text: "Purchase", color: .purple)
                        }
                    }
                    
                    if transaction.isDisputed {
                        badge(text: "Disputed", color: .orange)
                    }
                    if transaction.isCompleted {
                        badge(text: "Paid", color: .green)
                    }
                    // Add order status badge if we have order data
                    if let order = getOrderForTransaction(transaction) {
                        badge(text: order.orderStatus.displayName, color: order.orderStatus.badgeColor)
                    }
                }

                // Action buttons row
                HStack(spacing: 12) {
                    Button(action: {}) {
                        Text("View Details")
                            .font(.caption)
                            .fontWeight(.semibold)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 8)
                            .background(Color.blue.opacity(0.15))
                            .foregroundColor(.blue)
                            .cornerRadius(8)
                    }
                    
                    Spacer()
                    
                    // Arrow indicator
                    Image(systemName: "chevron.right")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.15), radius: 6, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
        .sheet(item: $selectedOrder) { order in
            OrderDetailView(order: order)
                .environmentObject(authManager)
        }
    }
    
    // MARK: - Badge Helper
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
    
    // MARK: - Order Loading
    private func loadOrderForTransaction(_ transaction: PaymentTransaction) async {
        // Check viewModel cache first
        if let cachedOrder = viewModel.orderCache[transaction.id] {
            await MainActor.run {
                self.selectedOrder = cachedOrder
            }
            return
        }
        
        // If not in cache, load it (this should rarely happen with preloading)
        guard let listingId = transaction.listingId,
              let currentUserId = authManager.currentUserId else {
            return
        }
        
        do {
            // Try to find the order by listing ID and user ID
            let orders: [Order] = try await supabase
                .from("orders")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("listing_id", value: listingId.uuidString)
                .or("buyer_id.eq.\(currentUserId),seller_id.eq.\(currentUserId)")
                .order("created_at", ascending: false)
                .limit(1)
                .execute()
                .value
            
            await MainActor.run {
                if let order = orders.first {
                    self.selectedOrder = order
                    // Update the viewModel cache
                    self.viewModel.orderCache[transaction.id] = order
                }
            }
        } catch {
            print("Failed to load order for transaction: \(error)")
        }
    }
    
    // MARK: - Status Helper Functions
    private func getOrderForTransaction(_ transaction: PaymentTransaction) -> Order? {
        return viewModel.orderCache[transaction.id]
    }
    
    private func getOrderStatusText(for transaction: PaymentTransaction) -> String {
        if let order = getOrderForTransaction(transaction) {
            return order.orderStatus.displayName
        }
        // Fallback to payment status
        return transaction.isCompleted ? "Completed" : "Pending"
    }
    
    private func getOrderStatusColor(for transaction: PaymentTransaction) -> Color {
        if let order = getOrderForTransaction(transaction) {
            return order.orderStatus.badgeColor
        }
        // Fallback to payment status colors
        return transaction.isCompleted ? .green : .orange
    }
    
    // MARK: - Offer Management Functions
    private func acceptOffer(_ offer: UserOffer) {
        guard let offerId = UUID(uuidString: offer.offerId.uuidString) else { return }
        
        isProcessingOffer = true
        offerError = nil
        
        Task {
            do {
                let success = try await OfferService.shared.acceptOfferStatus(offerId)
                await MainActor.run {
                    isProcessingOffer = false
                    showingOfferAcceptance = false
                    if success {
                        viewModel.errorMessage = "Offer accepted! Please proceed with payment to complete the order."
                        viewModel.isShowingError = true
                    }
                    // Refresh data
                    Task {
                        await viewModel.refreshData()
                        await viewModel.loadPendingOffers()
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
    
    private func declineOffer(_ offer: UserOffer) {
        guard let offerId = UUID(uuidString: offer.offerId.uuidString) else { return }
        
        isProcessingOffer = true
        offerError = nil
        
        Task {
            do {
                try await OfferService.shared.declineOffer(offerId)
                await MainActor.run {
                    isProcessingOffer = false
                    showingOfferAcceptance = false
                    // Refresh offers
                    Task {
                        await viewModel.loadPendingOffers()
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

}

// MARK: - Safari View
struct SafariView: UIViewControllerRepresentable {
    let url: URL
    
    func makeUIViewController(context: Context) -> SFSafariViewController {
        let controller = SFSafariViewController(url: url)
        controller.preferredControlTintColor = UIColor(named: "ThemeColor")
        return controller
    }
    
    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

// MARK: - Preview
struct WalletView_Previews: PreviewProvider {
    static var previews: some View {
        WalletView()
            .environmentObject(AuthManager())
    }
}

