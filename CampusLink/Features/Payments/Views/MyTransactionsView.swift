import SwiftUI

struct MyTransactionsView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var selection: Segment = .purchases
    @State private var purchases: [PaymentTransaction] = []
    @State private var sales: [PaymentTransaction] = []
    @State private var isLoading = true
    @State private var errorMessage: String?

    enum Segment: String, CaseIterable { case purchases = "Purchases", sales = "Sales" }

    var body: some View {
        VStack(spacing: 12) {
                Picker("Type", selection: $selection) {
                    ForEach(Segment.allCases, id: \.self) { seg in
                        Text(seg.rawValue).tag(seg)
                    }
                }
                .pickerStyle(SegmentedPickerStyle())
                .padding(.horizontal)

                if isLoading {
                    Spacer(); ProgressView("Loading transactions..."); Spacer()
                } else if let errorMessage = errorMessage {
                    Spacer(); Text(errorMessage).foregroundColor(.secondary); Spacer()
                } else {
                    List {
                        ForEach(selection == .purchases ? purchases : sales) { tx in
                            TransactionRow(
                                transaction: tx,
                                isBuyer: selection == .purchases,
                                onConfirmReceived: { pendingCaptureTx = tx; showConfirmAlert = true },
                                onReportProblem: { reportProblem(transaction: tx) },
                                onMarkDelivered: { pendingDeliveredTx = tx; showDeliveredAlert = true }
                            )
                            .contentShape(Rectangle())
                            .onTapGesture { activeTransaction = tx }
                        }
                    }
                    .listStyle(PlainListStyle())
                }
        }
        .navigationTitle("My Transactions")
        .onAppear { Task { await loadData() } }
        .alert("Error", isPresented: .constant(errorMessage != nil)) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
        .alert("Confirm Received?", isPresented: $showConfirmAlert) {
            Button("Cancel", role: .cancel) { pendingCaptureTx = nil }
            Button("Confirm") {
                if let tx = pendingCaptureTx { Task { await confirmReceived(transaction: tx) } }
                pendingCaptureTx = nil
            }
        } message: { Text("This will release funds to the seller.") }
        .alert("Mark as Delivered?", isPresented: $showDeliveredAlert) {
            Button("Cancel", role: .cancel) { pendingDeliveredTx = nil }
            Button("Mark Delivered") {
                if let tx = pendingDeliveredTx { Task { await markDelivered(tx) } }
                pendingDeliveredTx = nil
            }
        } message: { Text("This notifies the buyer and enables capture.") }
        .sheet(item: $disputeDraft) { draft in
            ReportDisputeView(transaction: draft.transaction) {
                Task { await loadData() }
            }
            .environmentObject(authManager)
        }
        .sheet(item: $disputeToView) { tx in
            DisputeDetailView(transaction: tx)
        }
        .fullScreenCover(item: $activeTransaction) { tx in
            TransactionActionSheetView(
                transaction: tx,
                isBuyer: selection == .purchases,
                canConfirm: PaymentLogic.canBuyerConfirm(transaction: tx, isBuyer: true),
                onConfirm: { pendingCaptureTx = tx; showConfirmAlert = true },
                onContactSeller: { Task { await contactSeller(tx) } },
                onReport: { reportProblem(transaction: tx) }
            )
            .environmentObject(authManager)
        }
        .sheet(item: $activeConversation) { convo in
            ChatView(conversation: convo)
                .environmentObject(authManager)
        }
    }

    // MARK: - Data

    private func loadData() async {
        guard let currentUserId = authManager.session?.user.id.uuidString else { return }
        await MainActor.run { isLoading = true; errorMessage = nil }
        do {
            let purchaseResults: [PaymentTransaction] = try await supabase
                .from("payments")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("buyer_id", value: currentUserId)
                .order("created_at", ascending: false)
                .execute()
                .value

            let saleResults: [PaymentTransaction] = try await supabase
                .from("payments")
                .select("""
                    *,
                    listing:listings(*)
                """)
                .eq("seller_id", value: currentUserId)
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
                self.errorMessage = "Failed to load transactions"
                self.isLoading = false
            }
        }
    }

    // MARK: - Actions

    private func confirmReceived(transaction: PaymentTransaction) async {
        guard let intentId = transaction.paymentIntentId else { return }
        // Ensure caller is buyer
        guard let currentUserId = authManager.session?.user.id.uuidString,
              transaction.buyerId.lowercased() == currentUserId.lowercased() else {
            await MainActor.run { errorMessage = "Only the buyer can confirm receipt." }
            return
        }
        // Only attempt capture when Stripe says it's capturable
        guard PaymentLogic.canBuyerConfirm(transaction: transaction, isBuyer: true) else {
            await MainActor.run { errorMessage = "This payment isn't ready to capture yet." }
            return
        }
        do {
            try await PaymentService.shared.capturePayment(paymentIntentId: intentId)
            await loadData()
        } catch {
            await MainActor.run { errorMessage = error.localizedDescription }
        }
    }

    private func markDelivered(_ tx: PaymentTransaction) async {
        // Verify current user is seller
        guard let currentUserId = authManager.session?.user.id.uuidString,
              tx.sellerId.lowercased() == currentUserId.lowercased() else {
            await MainActor.run { errorMessage = "Only the seller can mark delivered." }
            return
        }
        do {
            try await supabase
                .from("payments")
                .update(["delivered_at": ISO8601DateFormatter().string(from: Date())])
                .eq("id", value: tx.id.uuidString)
                .execute()
            await loadData()
        } catch {
            // no-op; UI refresh will pick up server-side status
        }
    }

    @State private var disputeDraft: DisputeDraft?
    @State private var disputeToView: PaymentTransaction?
    @State private var pendingCaptureTx: PaymentTransaction?
    @State private var pendingDeliveredTx: PaymentTransaction?
    @State private var showConfirmAlert = false
    @State private var showDeliveredAlert = false
    @State private var activeTransaction: PaymentTransaction?
    @State private var activeConversation: Conversation?

    private func reportProblem(transaction: PaymentTransaction) {
        disputeDraft = DisputeDraft(transaction: transaction)
    }
    private func viewDispute(transaction: PaymentTransaction) {
        disputeToView = transaction
    }

    private func contactSeller(_ tx: PaymentTransaction) async {
        guard let currentUserId = authManager.session?.user.id.uuidString,
              let listingId = tx.listingId?.uuidString else { return }
        do {
            // find existing
            let existing: [Conversation] = try await supabase
                .from("conversations")
                .select("*")
                .eq("buyer_id", value: currentUserId)
                .eq("seller_id", value: tx.sellerId)
                .eq("listing_id", value: listingId)
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
            }
            let created: Conversation = try await supabase
                .from("conversations")
                .insert(ConversationInsert(buyer_id: currentUserId, seller_id: tx.sellerId, listing_id: listingId))
                .select("*")
                .single()
                .execute()
                .value
            await MainActor.run { activeConversation = created }
        } catch {
            await MainActor.run { errorMessage = "Unable to open chat." }
        }
    }
}

// MARK: - Row

    private struct TransactionRow: View {
    let transaction: PaymentTransaction
    let isBuyer: Bool
    let onConfirmReceived: () -> Void
        let onReportProblem: () -> Void
        var onMarkDelivered: (() -> Void)? = nil
        var onViewDispute: (() -> Void)? = nil

    private var statusBadgeColor: Color {
        switch transaction.status.lowercased() {
        case "succeeded", "completed": return .green
        case "pending", "requires_capture", "authorized": return .orange
        case "disputed", "canceled", "failed": return .red
        default: return .gray
        }
    }

        private var canConfirm: Bool {
            isBuyer && transaction.status.lowercased() == "requires_capture" && !transaction.isDisputed
        }

        private var statusLabel: String {
            transaction.status.replacingOccurrences(of: "_", with: " ").capitalized
        }

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .top) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(transaction.listing?.title ?? "Listing")
                        .font(.headline)
                        .lineLimit(2)
                    Text(transaction.formattedAmount)
                        .font(.subheadline)
                        .foregroundColor(Color("ThemeColor"))
                }
                Spacer()
                Text(statusLabel)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(statusBadgeColor.opacity(0.15))
                    .foregroundColor(statusBadgeColor)
                    .cornerRadius(8)
            }

            // Summary badges row
            HStack(spacing: 8) {
                if transaction.isDisputed {
                    CampusLink.badge(text: "Disputed", color: .orange)
                }
                if transaction.status.lowercased() == "requires_capture" {
                    CampusLink.badge(text: "Requires Capture", color: .orange)
                }
                if ["succeeded","completed"].contains(transaction.status.lowercased()) {
                    CampusLink.badge(text: "Captured", color: .green)
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

                if transaction.isDisputed {
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
                            .background(Color.red.opacity(0.1))
                            .foregroundColor(.red)
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
    let transaction: PaymentTransaction
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


