import SwiftUI

struct TransactionDetailView: View {
    let transaction: PaymentTransaction
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    @State private var isLoading = false
    @State private var errorMessage: String?
    @State private var order: Order?
    
    private var isBuyer: Bool {
        transaction.buyerId == authManager.currentUserId
    }
    
    var body: some View {
        NavigationView {
            Group {
                if isLoading {
                    loadingView
                } else if let order = order {
                    orderDetailContent(order: order)
                } else {
                    transactionFallbackView
                }
            }
            .navigationTitle("Order Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
        .task {
            await loadOrderDetails()
        }
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    @ViewBuilder
    private var loadingView: some View {
        VStack(spacing: 16) {
            ProgressView()
                .scaleEffect(1.2)
            Text("Loading order details...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    @ViewBuilder
    private func orderDetailContent(order: Order) -> some View {
        ScrollView {
            VStack(spacing: 20) {
                // Order Header
                VStack(spacing: 12) {
                    Text(order.listing?.title ?? "Order")
                        .font(.title2)
                        .fontWeight(.bold)
                        .multilineTextAlignment(.center)
                    
                    Text(order.formattedPrice)
                        .font(.title3)
                        .fontWeight(.semibold)
                        .foregroundColor(Color("ThemeColor"))
                }
                .padding()
                .background(Color(UIColor.secondarySystemBackground))
                .cornerRadius(12)
                
                // Order Status
                VStack(alignment: .leading, spacing: 12) {
                    Text("Order Status")
                        .font(.headline)
                    
                    HStack {
                        Text(order.orderStatus.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(order.orderStatus.badgeColor.opacity(0.15))
                            .foregroundColor(order.orderStatus.badgeColor)
                            .cornerRadius(8)
                        
                        Spacer()
                        
                        Text(order.paymentStatus.displayName)
                            .font(.subheadline)
                            .fontWeight(.medium)
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(order.paymentStatus.badgeColor.opacity(0.15))
                            .foregroundColor(order.paymentStatus.badgeColor)
                            .cornerRadius(8)
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Order Details
                VStack(alignment: .leading, spacing: 12) {
                    Text("Order Information")
                        .font(.headline)
                    
                    VStack(spacing: 8) {
                        DetailRow(title: "Order ID", value: order.id.uuidString.prefix(8) + "...")
                        DetailRow(title: "Created", value: order.createdAt.formatted(date: .abbreviated, time: .shortened))
                        DetailRow(title: "Payment Method", value: order.paymentMethod.displayName)
                        
                        if let confirmedAt = order.sellerConfirmedAt {
                            DetailRow(title: "Seller Confirmed", value: confirmedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        
                        if let inProgressAt = order.inProgressAt {
                            DetailRow(title: "In Progress", value: inProgressAt.formatted(date: .abbreviated, time: .shortened))
                        }
                        
                        if let completedAt = order.completedAt {
                            DetailRow(title: "Completed", value: completedAt.formatted(date: .abbreviated, time: .shortened))
                        }
                    }
                }
                .padding()
                .background(Color(UIColor.systemBackground))
                .cornerRadius(12)
                .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                
                // Listing Details
                if let listing = order.listing {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Item Details")
                            .font(.headline)
                        
                        VStack(spacing: 8) {
                            DetailRow(title: "Title", value: listing.title)
                            DetailRow(title: "Category", value: listing.category)
                            DetailRow(title: "Type", value: listing.listingType.displayName)
                            
                            if !listing.description.isEmpty {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Description")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Text(listing.description)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color(UIColor.systemBackground))
                    .cornerRadius(12)
                    .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
                }
                
                // Dispute Information
                if transaction.isDisputed {
                    VStack(alignment: .leading, spacing: 12) {
                        Text("Dispute Information")
                            .font(.headline)
                            .foregroundColor(.orange)
                        
                        VStack(spacing: 8) {
                            if let reason = transaction.disputeReason {
                                DetailRow(title: "Reason", value: reason)
                            }
                            
                            if let notes = transaction.disputeNotes {
                                VStack(alignment: .leading, spacing: 4) {
                                    Text("Notes")
                                        .font(.subheadline)
                                        .fontWeight(.medium)
                                        .foregroundColor(.secondary)
                                    Text(notes)
                                        .font(.subheadline)
                                }
                            }
                        }
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
            }
            .padding()
        }
    }
    
    @ViewBuilder
    private var transactionFallbackView: some View {
        VStack(spacing: 16) {
            Image(systemName: "exclamationmark.triangle")
                .font(.system(size: 48))
                .foregroundColor(.orange)
            
            Text("Order Details Unavailable")
                .font(.headline)
            
            Text("Unable to load full order details for this transaction.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            // Show basic transaction info
            VStack(alignment: .leading, spacing: 8) {
                Text("Transaction Information")
                    .font(.headline)
                
                DetailRow(title: "Amount", value: transaction.formattedAmount)
                DetailRow(title: "Status", value: transaction.isCompleted ? "Completed" : "Pending")
                DetailRow(title: "Date", value: transaction.createdAt.formatted(date: .abbreviated, time: .shortened))
                
                if let listing = transaction.listing {
                    DetailRow(title: "Item", value: listing.title)
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
        }
        .padding()
    }
    
    private func loadOrderDetails() async {
        guard let listingId = transaction.listingId,
              let currentUserId = authManager.currentUserId else {
            await MainActor.run { isLoading = false }
            return
        }
        
        await MainActor.run { isLoading = true; errorMessage = nil }
        
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
                self.order = orders.first
                self.isLoading = false
            }
        } catch {
            await MainActor.run {
                self.errorMessage = "Failed to load order details: \(error.localizedDescription)"
                self.isLoading = false
            }
        }
    }
}


// MARK: - Extensions for Payment Status Colors
extension PaymentStatus {
    var badgeColor: Color {
        switch self {
        case .pending:
            return .orange
        case .requiresCapture:
            return .blue
        case .captured:
            return .purple
        case .succeeded:
            return .green
        case .released:
            return .green
        case .failed:
            return .facebookBlue
        case .refunded:
            return .purple
        }
    }
}

// MARK: - Preview
struct TransactionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        TransactionDetailView(transaction: PaymentTransaction(
            id: UUID(),
            listingId: UUID(),
            buyerId: "buyer123",
            sellerId: "seller456",
            paymentIntentId: "pi_123",
            amount: 25.99,
            status: "completed",
            createdAt: Date(),
            escrowReleaseAt: nil,
            deliveredAt: nil,
            buyerConfirmedAt: nil,
            disputeStatus: nil,
            disputeReason: nil,
            disputeNotes: nil,
            listing: nil
        ))
        .environmentObject(AuthManager())
    }
}
