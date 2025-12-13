import SwiftUI

struct PendingTransactionDetailView: View {
    let transaction: PendingTransaction
    @EnvironmentObject private var authManager: AuthManager
    @Environment(\.dismiss) private var dismiss
    
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var showingSuccess = false
    @State private var successMessage: String?
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Header Card
                    headerCard
                    
                    // Transaction-specific content
                    if let offer = transaction.offer {
                        offerContent(offer)
                    } else if let order = transaction.order {
                        orderContent(order)
                    } else if let payout = transaction.payout {
                        payoutContent(payout)
                    }
                    
                    Spacer(minLength: 20)
                }
                .padding()
            }
            .navigationTitle("Transaction Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .foregroundColor(Color("ThemeColor"))
                }
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK", role: .cancel) {}
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .alert("Success", isPresented: $showingSuccess) {
            Button("OK", role: .cancel) {
                dismiss()
            }
        } message: {
            Text(successMessage ?? "Action completed successfully")
        }
    }
    
    // MARK: - Cancel Payout
    private func cancelPayout(_ payout: Payout) async {
        isProcessing = true
        errorMessage = nil
        
        do {
            let cancelled = try await PayoutService.shared.cancelPayout(payout.id)
            
            await MainActor.run {
                isProcessing = false
                // Dismiss immediately after successful cancellation
                dismiss()
            }
        } catch {
            await MainActor.run {
                isProcessing = false
                // Only show error if cancellation actually failed
                // (Not for "already completed" type errors)
                if error.localizedDescription.contains("already") || 
                   error.localizedDescription.contains("completed") {
                    // Payout already completed/processed - just dismiss
                    dismiss()
                } else {
                    errorMessage = "Failed to cancel payout: \(error.localizedDescription)"
                    showingError = true
                }
            }
        }
    }
    
    // MARK: - Header Card
    private var headerCard: some View {
        VStack(spacing: 16) {
            // Type Badge
            HStack(spacing: 6) {
                Image(systemName: transaction.typeIcon)
                    .font(.title3)
                Text(transaction.typeTag)
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            .foregroundColor(transaction.typeColor)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(transaction.typeColor.opacity(0.15))
            .cornerRadius(12)
            
            // Title
            Text(transaction.title)
                .font(.title2)
                .fontWeight(.bold)
                .multilineTextAlignment(.center)
                .foregroundColor(.primary)
            
            // Amount
            Text(transaction.amount)
                .font(.system(size: 36, weight: .bold, design: .rounded))
                .foregroundColor(Color("ThemeColor"))
            
            // Status Badge
            Text(transaction.status)
                .font(.subheadline)
                .fontWeight(.medium)
                .padding(.horizontal, 12)
                .padding(.vertical, 6)
                .background(transaction.statusColor.opacity(0.15))
                .foregroundColor(transaction.statusColor)
                .cornerRadius(10)
            
            // Date
            HStack(spacing: 4) {
                Image(systemName: "clock")
                    .font(.caption)
                Text(transaction.createdAt, style: .relative)
                    .font(.caption)
            }
            .foregroundColor(.secondary)
        }
        .padding()
        .frame(maxWidth: .infinity)
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
        .shadow(color: Color.black.opacity(0.1), radius: 8, x: 0, y: 2)
    }
    
    // MARK: - Offer Content
    private func offerContent(_ offer: Offer) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Offer Details", icon: "doc.text")
            
            DetailRow(label: "Type", value: offer.listingType == .seek ? "Seek Offer" : "Buyer Offer")
            
            if let fromUser = transaction.fromUser {
                DetailRow(label: "From", value: fromUser)
            }
            
            if let message = offer.message {
                VStack(alignment: .leading, spacing: 8) {
                    Text("Message")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.secondary)
                    Text(message)
                        .font(.body)
                        .foregroundColor(.primary)
                        .padding()
                        .background(Color(UIColor.tertiarySystemBackground))
                        .cornerRadius(10)
                }
            }
            
            DetailRow(label: "Created", value: transaction.createdAt.formatted(date: .long, time: .shortened))
            DetailRow(label: "Updated", value: offer.updatedAt.formatted(date: .long, time: .shortened))
            
            // Action Buttons - only show if offer is pending and user can respond
            if offer.status == "pending", let currentUserId = authManager.currentUserId {
                let userRole = offer.getUserRole(currentUserId: currentUserId)
                
                if userRole == .receiver {
                    // User is receiving the offer - show Accept/Decline
                    VStack(spacing: 12) {
                        // Accept Button
                        Button(action: {
                            acceptOffer(offer)
                        }) {
                            HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "checkmark.circle.fill")
                                    Text("Accept Offer")
                                }
                            }
                            .frame(maxWidth: .infinity)
                            .padding()
                            .background(Color.green)
                            .foregroundColor(.white)
                            .cornerRadius(12)
                        }
                        .disabled(isProcessing)
                        
                        // Decline Button
                Button(action: {
                            declineOffer(offer)
                }) {
                    HStack {
                                if isProcessing {
                                    ProgressView()
                                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                } else {
                                    Image(systemName: "xmark.circle.fill")
                                    Text("Decline Offer")
                                }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                            .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                        .disabled(isProcessing)
                    }
                    .padding(.top, 8)
                } else if userRole == .sender {
                    // User sent this offer - show status message
                    VStack(alignment: .leading, spacing: 8) {
                        HStack(spacing: 6) {
                            Image(systemName: "clock")
                                .foregroundColor(.orange)
                            Text("Waiting for Response")
                                .font(.subheadline)
                                .fontWeight(.semibold)
                        }
                        Text("You sent this offer. The seller will review it shortly.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    .padding()
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(10)
                .padding(.top, 8)
                }
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Order Content
    private func orderContent(_ order: Order) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Order Details", icon: "cart")
            
            if let listing = order.listing {
                DetailRow(label: "Item", value: listing.title)
                DetailRow(label: "Category", value: listing.category ?? "N/A")
            }
            
            DetailRow(label: "Quantity", value: "\(order.quantity)")
            DetailRow(label: "Payment Method", value: order.paymentMethod.displayName)
            DetailRow(label: "Payment Status", value: order.paymentStatus.displayName)
            
            if let fromUser = transaction.fromUser {
                DetailRow(label: "From", value: fromUser)
            }
            if let toUser = transaction.toUser {
                DetailRow(label: "To", value: toUser)
            }
            
            DetailRow(label: "Order Placed", value: order.createdAt.formatted(date: .long, time: .shortened))
            
            if let confirmedAt = order.sellerConfirmedAt {
                DetailRow(label: "Seller Confirmed", value: confirmedAt.formatted(date: .long, time: .shortened))
            }
            
            if let inProgressAt = order.inProgressAt {
                DetailRow(label: "In Progress Since", value: inProgressAt.formatted(date: .long, time: .shortened))
            }
            
            // Escrow Info
            if order.hasEscrowAccount {
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 6) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundColor(.orange)
                        Text("Payment Secured")
                            .font(.subheadline)
                            .fontWeight(.semibold)
                    }
                    Text("Funds are held securely in escrow until the order is completed.")
                        .font(.caption)
                        .foregroundColor(.secondary)
                }
                .padding()
                .background(Color.orange.opacity(0.1))
                .cornerRadius(10)
            }
            
            // Action Button
            Button(action: {
                // Navigate to full order detail view
            }) {
                HStack {
                    Image(systemName: "doc.text.magnifyingglass")
                    Text("View Full Order Details")
                }
                .frame(maxWidth: .infinity)
                .padding()
                .background(Color("ThemeColor"))
                .foregroundColor(.white)
                .cornerRadius(12)
            }
            .padding(.top, 8)
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Payout Content
    private func payoutContent(_ payout: Payout) -> some View {
        VStack(alignment: .leading, spacing: 16) {
            sectionHeader(title: "Payout Details", icon: "banknote")
            
            DetailRow(label: "Method", value: payout.payoutMethod.capitalized)
            DetailRow(label: "Net Amount", value: payout.formattedNetAmount)
            DetailRow(label: "Fee", value: payout.formattedFee)
            DetailRow(label: "Requested", value: payout.createdAt.formatted(date: .long, time: .shortened))
            
            if let paidAt = payout.paidAt {
                DetailRow(label: "Completed", value: paidAt.formatted(date: .long, time: .shortened))
            }
            
            // Status Info
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 6) {
                    Image(systemName: payout.status.icon)
                        .foregroundColor(transaction.statusColor)
                    Text("Status: \(payout.status.displayName)")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                }
                
                switch payout.status {
                case .pending:
                    Text("Your payout request is being processed.")
                case .processing:
                    Text("Your payout is currently being transferred.")
                case .inTransit:
                    Text("Your payout is on its way to your account.")
                case .completed, .paid:
                    Text("Your payout has been completed successfully.")
                case .failed:
                    Text("There was an issue processing your payout. Please contact support.")
                case .cancelled:
                    Text("This payout was cancelled.")
                }
            }
            .font(.caption)
            .foregroundColor(.secondary)
            .padding()
            .background(transaction.statusColor.opacity(0.1))
            .cornerRadius(12)
            
            // Cancel Button for Pending Payouts
            if payout.status == .pending || payout.status == .processing {
                Button(action: {
                    Task {
                        await cancelPayout(payout)
                    }
                }) {
                    HStack {
                        if isProcessing {
                            ProgressView()
                                .tint(.white)
                        } else {
                            Image(systemName: "xmark.circle.fill")
                            Text("Cancel Payout")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(Color.red)
                    .foregroundColor(.white)
                    .cornerRadius(12)
                }
                .disabled(isProcessing)
            }
        }
        .padding()
        .background(Color(UIColor.secondarySystemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Helper Views
    private func sectionHeader(title: String, icon: String) -> some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .foregroundColor(Color("ThemeColor"))
            Text(title)
                .font(.headline)
                .fontWeight(.semibold)
        }
    }
    
    // Local DetailRow component
    private struct DetailRow: View {
        let label: String
        let value: String
        
        var body: some View {
            HStack {
                Text(label)
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                Spacer()
                Text(value)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.trailing)
            }
            .padding(.vertical, 4)
        }
    }
    
    // MARK: - Offer Actions
    
    private func acceptOffer(_ offer: Offer) {
        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "User not authenticated"
            showingError = true
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                print("🟢 Accepting offer: \(offer.id)")
                let order = try await UnifiedOfferService.shared.acceptOffer(
                    offerId: offer.id,
                    currentUserId: currentUserId
                )
                
                await MainActor.run {
                    isProcessing = false
                    
                    // Different message for seller vs buyer
                    let userRole = offer.getUserRole(currentUserId: currentUserId)
                    if userRole == .receiver {
                        // Seller accepted the buyer's offer
                        successMessage = "Offer accepted! Order created for \(order.formattedPrice). Waiting for buyer to complete payment."
                    } else {
                        // Buyer's offer was accepted (shouldn't happen in this view, but just in case)
                        successMessage = "Offer accepted! Order created for \(order.formattedPrice). Please complete payment to proceed."
                    }
                    
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
    
    private func declineOffer(_ offer: Offer) {
        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "User not authenticated"
            showingError = true
            return
        }
        
        isProcessing = true
        
        Task {
            do {
                print("🔴 Declining offer: \(offer.id)")
                try await UnifiedOfferService.shared.rejectOffer(
                    offerId: offer.id,
                    currentUserId: currentUserId
                )
                
                await MainActor.run {
                    isProcessing = false
                    successMessage = "Offer declined successfully."
                    showingSuccess = true
                }
            } catch {
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Preview
struct PendingTransactionDetailView_Previews: PreviewProvider {
    static var previews: some View {
        PendingTransactionDetailView(
            transaction: PendingTransaction(
                id: UUID(),
                type: .order,
                title: "Sample Order",
                amount: "$25.00",
                status: "Pending",
                statusColor: .orange,
                createdAt: Date(),
                fromUser: "Buyer",
                toUser: "Seller",
                offer: nil,
                order: nil,
                payout: nil
            )
        )
        .environmentObject(AuthManager())
    }
}

