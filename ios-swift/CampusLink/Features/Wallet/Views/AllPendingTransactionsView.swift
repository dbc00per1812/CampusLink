import SwiftUI

struct AllPendingTransactionsView: View {
    let transactions: [PendingTransaction]
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedOrder: Order?
    @State private var selectedPendingTransaction: PendingTransaction?
    @State private var sortOption: PendingTransactionSort = .dateNewest
    @State private var filterType: PendingTransactionType? = nil
    @Environment(\.dismiss) private var dismiss
    
    private var filteredAndSortedTransactions: [PendingTransaction] {
        var result = transactions
        
        // Apply type filter
        if let filterType = filterType {
            result = result.filter { $0.type == filterType }
        }
        
        // Apply sort
        switch sortOption {
        case .dateNewest:
            result.sort { $0.createdAt > $1.createdAt }
        case .dateOldest:
            result.sort { $0.createdAt < $1.createdAt }
        case .amountHighest:
            result.sort { parseAmount($0.amount) > parseAmount($1.amount) }
        case .amountLowest:
            result.sort { parseAmount($0.amount) < parseAmount($1.amount) }
        case .type:
            result.sort { $0.type.displayName < $1.type.displayName }
        }
        
        return result
    }
    
    var body: some View {
        VStack(spacing: 0) {
            // Filter and Sort Bar
            filterSortBar
            
            Divider()
            
            // Transaction List
            if filteredAndSortedTransactions.isEmpty {
                emptyState
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(filteredAndSortedTransactions) { transaction in
                            pendingTransactionCard(transaction)
                        }
                    }
                    .padding()
                }
            }
        }
        .navigationTitle("Pending Transactions")
        .navigationBarTitleDisplayMode(.large)
        .sheet(item: $selectedOrder) { order in
            OrderDetailView(order: order)
                .environmentObject(authManager)
        }
        .sheet(item: $selectedPendingTransaction) { transaction in
            PendingTransactionDetailView(transaction: transaction)
                .environmentObject(authManager)
        }
    }
    
    // MARK: - Filter and Sort Bar
    private var filterSortBar: some View {
        HStack {
            // Type Filter Menu
            Menu {
                Button(action: { filterType = nil }) {
                    Label("All Types", systemImage: filterType == nil ? "checkmark" : "")
                }
                Divider()
                Button(action: { filterType = .offer }) {
                    Label("Offers", systemImage: filterType == .offer ? "checkmark" : "hand.raised.fill")
                }
                Button(action: { filterType = .order }) {
                    Label("Orders", systemImage: filterType == .order ? "checkmark" : "cart.fill")
                }
                Button(action: { filterType = .payout }) {
                    Label("Payouts", systemImage: filterType == .payout ? "checkmark" : "banknote.fill")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "line.3.horizontal.decrease.circle")
                    Text(filterType?.displayName ?? "All")
                        .font(.subheadline)
                }
                .foregroundColor(Color("ThemeColor"))
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color("ThemeColor").opacity(0.1))
                .cornerRadius(8)
            }
            
            Spacer()
            
            // Sort Menu
            Menu {
                Button(action: { sortOption = .dateNewest }) {
                    Label("Newest First", systemImage: sortOption == .dateNewest ? "checkmark" : "")
                }
                Button(action: { sortOption = .dateOldest }) {
                    Label("Oldest First", systemImage: sortOption == .dateOldest ? "checkmark" : "")
                }
                Divider()
                Button(action: { sortOption = .amountHighest }) {
                    Label("Highest Amount", systemImage: sortOption == .amountHighest ? "checkmark" : "")
                }
                Button(action: { sortOption = .amountLowest }) {
                    Label("Lowest Amount", systemImage: sortOption == .amountLowest ? "checkmark" : "")
                }
                Divider()
                Button(action: { sortOption = .type }) {
                    Label("By Type", systemImage: sortOption == .type ? "checkmark" : "")
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "arrow.up.arrow.down")
                    Text("Sort")
                        .font(.subheadline)
                }
                .foregroundColor(.secondary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .background(Color(.systemGray6))
                .cornerRadius(8)
            }
        }
        .padding()
        .background(Color(.systemBackground))
    }
    
    // MARK: - Empty State
    private var emptyState: some View {
        VStack(spacing: 16) {
            Image(systemName: "tray")
                .font(.system(size: 60))
                .foregroundColor(.secondary)
            Text("No Pending Transactions")
                .font(.headline)
            Text(filterType != nil ? "No \(filterType!.displayName.lowercased())s found" : "You have no pending transactions")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding()
    }
    
    // MARK: - Pending Transaction Card
    private func pendingTransactionCard(_ transaction: PendingTransaction) -> some View {
        Button(action: {
            if let order = transaction.order {
                selectedOrder = order
            } else if transaction.offer != nil || transaction.payout != nil {
                // Show pending transaction detail for offers and payouts
                selectedPendingTransaction = transaction
            }
        }) {
            VStack(spacing: 0) {
                // Main content
                HStack {
                    VStack(alignment: .leading, spacing: 8) {
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
                            .font(.body)
                            .fontWeight(.medium)
                            .foregroundColor(.primary)
                            .lineLimit(2)
                            .multilineTextAlignment(.leading)
                        
                        // Amount
                        Text(transaction.amount)
                            .font(.title3)
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
                        
                        // Date
                        HStack(spacing: 4) {
                            Image(systemName: "clock")
                                .font(.caption2)
                            Text(transaction.createdAt, style: .relative)
                                .font(.caption)
                        }
                        .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 8) {
                        // Status badge
                        Text(transaction.status)
                            .font(.caption)
                            .fontWeight(.medium)
                            .padding(.horizontal, 8)
                            .padding(.vertical, 4)
                            .background(transaction.statusColor.opacity(0.15))
                            .foregroundColor(transaction.statusColor)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        // Arrow
                        Image(systemName: "chevron.right")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
                .padding()
            }
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 4, x: 0, y: 2)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    // MARK: - Helper Methods
    private func parseAmount(_ amountString: String) -> Double {
        // Remove $ and convert to double
        let cleanString = amountString.replacingOccurrences(of: "$", with: "")
            .replacingOccurrences(of: ",", with: "")
        return Double(cleanString) ?? 0.0
    }
}

// MARK: - Preview
struct AllPendingTransactionsView_Previews: PreviewProvider {
    static var previews: some View {
        NavigationView {
            AllPendingTransactionsView(transactions: [])
                .environmentObject(AuthManager())
        }
    }
}

