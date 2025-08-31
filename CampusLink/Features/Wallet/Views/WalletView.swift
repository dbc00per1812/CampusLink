import SwiftUI
import SafariServices

struct WalletView: View {
    @StateObject private var viewModel = WalletViewModel()
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedTransaction: PaymentTransaction?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Balance Card
                    balanceCard
                    
                    // Action Buttons
                    actionButtons
                    
                    // Transaction History
                    transactionHistory
                }
                .padding()
            }
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.large)
            .refreshable { await viewModel.refreshData() }
        }
        .task { await viewModel.loadWalletData() }
        .sheet(isPresented: $viewModel.showPayoutRequestSheet, onDismiss: { viewModel.showPayoutRequestSheet = false }) { 
            if let wallet = viewModel.wallet {
                PayoutRequestView(
                    availableBalance: wallet.availableCents,
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
        }
        .sheet(isPresented: $viewModel.showPayoutHistorySheet, onDismiss: { viewModel.showPayoutHistorySheet = false }) {
            if let userId = authManager.session?.user.id.uuidString {
                PayoutHistoryView(userId: userId)
            }
        }
        .sheet(item: $viewModel.onboardingLink, onDismiss: { viewModel.onboardingLink = nil }) { link in
            SafariView(url: link.url).ignoresSafeArea()
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
        VStack(spacing: 0) {
            // Available Balance
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Available Balance")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.wallet?.formattedAvailableBalance ?? "$0.00")
                        .font(.system(size: 36, weight: .bold, design: .rounded))
                        .foregroundColor(Color("ThemeColor"))
                }
                Spacer()
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 28))
                    .foregroundColor(Color("ThemeColor").opacity(0.7))
            }
            .padding()
            
            Divider()
            
            // Escrow Balance
            if let wallet = viewModel.wallet, wallet.hasEscrowBalance {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("In Escrow")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        Text(wallet.formattedEscrowBalance)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundColor(.orange)
                    }
                    Spacer()
                    Image(systemName: "lock.fill")
                        .font(.system(size: 16))
                        .foregroundColor(.orange.opacity(0.7))
                }
                .padding()
                .background(Color.orange.opacity(0.1))
            }
            
            // Total Balance Footer
            HStack {
                Text("Total Balance")
                    .font(.caption)
                    .foregroundColor(.secondary)
                Spacer()
                Text(viewModel.wallet?.formattedTotalBalance ?? "$0.00")
                    .font(.system(size: 18, weight: .semibold))
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
        }
        .background(Color(UIColor.systemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Action Buttons
    private var actionButtons: some View {
        VStack(spacing: 12) {
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
                .disabled(viewModel.wallet?.availableCents ?? 0 <= 0 && viewModel.hasStripeConnectAccount)
                
                // Payout History Button
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
                } else {
                    // Add Funds Button (placeholder for future)
                    Button(action: {
                        // Future: Add funds functionality
                    }) {
                        HStack {
                            Image(systemName: "plus.circle")
                            Text("Add Funds")
                        }
                        .frame(maxWidth: .infinity)
                        .padding()
                        .background(Color(UIColor.secondarySystemBackground))
                        .foregroundColor(.primary)
                        .cornerRadius(12)
                    }
                    .disabled(true) // Not implemented yet
                    .opacity(0.5)
                }
            }
        }
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
                VStack(spacing: 0) {
                    ForEach(viewModel.transactions.prefix(5)) { transaction in
                        transactionRow(transaction)
                        if transaction.id != viewModel.transactions.prefix(5).last?.id {
                            Divider()
                        }
                    }
                }
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
            }
        }
    }
    
    // MARK: - Transaction Row
    private func transactionRow(_ transaction: PaymentTransaction) -> some View {
        HStack {
            // Icon
            Image(systemName: transaction.isCompleted ? "checkmark.circle.fill" : "clock.fill")
                .foregroundColor(transaction.isCompleted ? .green : .orange)
                .font(.title3)
            
            // Details
            VStack(alignment: .leading, spacing: 2) {
                Text(transaction.listing?.title ?? "Transaction")
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(1)
                
                Text(transaction.createdAt, style: .date)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Amount
            Text(transaction.formattedAmount)
                .font(.system(.body, design: .rounded))
                .fontWeight(.semibold)
                .foregroundColor(transaction.buyerId == authManager.currentUserId ? .red : .green)
        }
        .padding()
        .contentShape(Rectangle())
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

