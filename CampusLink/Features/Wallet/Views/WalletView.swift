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
        .sheet(isPresented: $viewModel.showWithdrawSheet) { withdrawSheet }
        .sheet(item: $viewModel.onboardingURL) { url in
            SafariView(url: url).ignoresSafeArea()
        }
        .alert("Wallet", isPresented: .constant(viewModel.errorMessage != nil)) {
            Button("OK") { viewModel.errorMessage = nil }
        } message: { Text(viewModel.errorMessage ?? "") }
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
        HStack(spacing: 12) {
            // Withdraw Button
            Button(action: {
                if viewModel.hasStripeConnectAccount {
                    viewModel.showWithdrawSheet = true
                } else {
                    Task {
                        await viewModel.startStripeOnboarding()
                    }
                }
            }) {
                HStack {
                    Image(systemName: viewModel.hasStripeConnectAccount ? "banknote" : "link")
                    Text(viewModel.hasStripeConnectAccount ? "Withdraw" : "Setup Payouts")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("ThemeColor"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .disabled(viewModel.wallet?.availableCents ?? 0 <= 0 && viewModel.hasStripeConnectAccount)
            
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
    
    // MARK: - Withdraw Sheet
    private var withdrawSheet: some View {
        NavigationView {
            VStack(spacing: 24) {
                // Available Balance Display
                VStack(spacing: 8) {
                    Text("Available to Withdraw")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Text(viewModel.wallet?.formattedAvailableBalance ?? "$0.00")
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .foregroundColor(Color("ThemeColor"))
                }
                .padding(.top)
                
                // Amount Input
                VStack(alignment: .leading, spacing: 8) {
                    Text("Withdraw Amount")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    HStack {
                        Text("$")
                            .font(.title2)
                        TextField("0.00", text: $viewModel.withdrawAmount)
                            .keyboardType(.decimalPad)
                            .font(.title2)
                    }
                    .padding()
                    .background(Color(UIColor.secondarySystemBackground))
                    .cornerRadius(12)
                    
                    // Quick Amount Buttons
                    HStack(spacing: 12) {
                        ForEach([25, 50, 100], id: \.self) { amount in
                            Button(action: {
                                viewModel.withdrawAmount = String(amount)
                            }) {
                                Text("$\(amount)")
                                    .font(.subheadline)
                                    .fontWeight(.medium)
                                    .padding(.horizontal, 16)
                                    .padding(.vertical, 8)
                                    .background(Color(UIColor.tertiarySystemBackground))
                                    .cornerRadius(8)
                            }
                        }
                        
                        Button(action: {
                            if let wallet = viewModel.wallet {
                                viewModel.withdrawAmount = String(format: "%.2f", wallet.availableBalance)
                            }
                        }) {
                            Text("Max")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color("ThemeColor").opacity(0.1))
                                .foregroundColor(Color("ThemeColor"))
                                .cornerRadius(8)
                        }
                    }
                }
                
                // Platform Fee Notice
                VStack(alignment: .leading, spacing: 4) {
                    HStack {
                        Image(systemName: "info.circle")
                            .font(.caption)
                        Text("Platform fee: 5% (min $0.50)")
                            .font(.caption)
                    }
                    .foregroundColor(.secondary)
                    
                    if let amount = Double(viewModel.withdrawAmount), amount > 0 {
                        let fee = max(0.50, amount * 0.05)
                        let netAmount = amount - fee
                        HStack {
                            Text("You'll receive:")
                                .font(.caption)
                            Text(String(format: "$%.2f", netAmount))
                                .font(.caption)
                                .fontWeight(.semibold)
                        }
                        .foregroundColor(.secondary)
                    }
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                
                Spacer()
                
                // Withdraw Button
                Button(action: {
                    Task {
                        await viewModel.requestPayout()
                    }
                }) {
                    if viewModel.isProcessingPayout {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                    } else {
                        Text("Withdraw Funds")
                    }
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("ThemeColor"))
                .foregroundColor(.white)
                .cornerRadius(12)
                .disabled(viewModel.isProcessingPayout || viewModel.withdrawAmount.isEmpty)
            }
            .padding()
            .navigationTitle("Withdraw Funds")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") {
                        viewModel.showWithdrawSheet = false
                    }
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

