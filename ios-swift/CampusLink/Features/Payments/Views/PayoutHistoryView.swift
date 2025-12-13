import SwiftUI

/// View for displaying payout history and status tracking
/// Shows payout history, current status, and allows cancellation of pending payouts
struct PayoutHistoryView: View {
    let userId: String
    
    @StateObject private var payoutService = PayoutService.shared
    @State private var payouts: [Payout] = []
    @State private var payoutStats: PayoutStats?
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var selectedPayout: Payout?
    @State private var showingPayoutDetails = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                if isLoading {
                    loadingView
                } else if let errorMessage = errorMessage {
                    errorView(message: errorMessage)
                } else {
                    // Content
                    ScrollView {
                        VStack(spacing: 24) {
                            // Stats Section
                            if let stats = payoutStats {
                                statsSection(stats)
                            }
                            
                            // Payouts List
                            payoutsSection
                        }
                        .padding(.horizontal, 20)
                        .padding(.vertical, 24)
                    }
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .sheet(isPresented: $showingPayoutDetails) {
            if let payout = selectedPayout {
                PayoutDetailView(payout: payout)
            }
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            await loadPayoutData()
        }
        .refreshable {
            await loadPayoutData()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Done") {
                    dismiss()
                }
                .foregroundColor(.accentColor)
                .fontWeight(.medium)
                
                Spacer()
                
                Text("Payout History")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Refresh") {
                    Task {
                        await loadPayoutData()
                    }
                }
                .foregroundColor(.secondary)
                .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Loading View
    
    private var loadingView: some View {
        VStack(spacing: 20) {
            ProgressView()
                .progressViewStyle(CircularProgressViewStyle())
                .scaleEffect(1.2)
            
            Text("Loading payout history...")
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
    
    // MARK: - Error View
    
    private func errorView(message: String) -> some View {
        VStack(spacing: 20) {
            Image(systemName: "exclamationmark.triangle")
                .font(.largeTitle)
                .foregroundColor(.orange)
            
            Text("Error Loading Payouts")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text(message)
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
            
            Button("Try Again") {
                Task {
                    await loadPayoutData()
                }
            }
            .foregroundColor(.white)
            .padding(.horizontal, 24)
            .padding(.vertical, 12)
            .background(Color("ThemeColor"))
            .cornerRadius(8)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 40)
    }
    
    // MARK: - Stats Section
    
    private func statsSection(_ stats: PayoutStats) -> some View {
        VStack(spacing: 16) {
            Text("Payout Summary")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            LazyVGrid(columns: [
                GridItem(.flexible()),
                GridItem(.flexible()),
                GridItem(.flexible())
            ], spacing: 16) {
                StatCard(
                    title: "Total",
                    value: stats.totalAmountFormatted,
                    subtitle: "\(stats.totalPayouts) payouts",
                    color: .blue
                )
                
                StatCard(
                    title: "Fees",
                    value: stats.totalFeesFormatted,
                    subtitle: "Total charges",
                    color: .orange
                )
                
                StatCard(
                    title: "Success",
                    value: "\(Int(stats.successRate))%",
                    subtitle: "Completion rate",
                    color: .green
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Payouts Section
    
    private var payoutsSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Recent Payouts")
                .font(.headline)
                .fontWeight(.semibold)
            
            if payouts.isEmpty {
                emptyStateView
            } else {
                LazyVStack(spacing: 12) {
                    ForEach(payouts) { payout in
                        PayoutRow(
                            payout: payout,
                            onTap: {
                                selectedPayout = payout
                                showingPayoutDetails = true
                            },
                            onCancel: {
                                Task {
                                    await cancelPayout(payout)
                                }
                            }
                        )
                    }
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Empty State
    
    private var emptyStateView: some View {
        VStack(spacing: 16) {
            Image(systemName: "creditcard")
                .font(.largeTitle)
                .foregroundColor(.secondary)
            
            Text("No Payouts Yet")
                .font(.headline)
                .fontWeight(.semibold)
            
            Text("When you request payouts, they'll appear here with status updates.")
                .font(.subheadline)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 40)
    }
    
    // MARK: - Data Loading
    
    private func loadPayoutData() async {
        isLoading = true
        errorMessage = nil
        
        do {
            async let payoutsTask = payoutService.getPayoutHistory(for: userId)
            async let statsTask = payoutService.getPayoutStats(for: userId)
            
            let (payoutsResult, statsResult) = try await (payoutsTask, statsTask)
            
            await MainActor.run {
                self.payouts = payoutsResult
                self.payoutStats = statsResult
                self.isLoading = false
            }
            
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.isLoading = false
                self.showingError = true
            }
        }
    }
    
    // MARK: - Payout Cancellation
    
    private func cancelPayout(_ payout: Payout) async {
        do {
            let _ = try await payoutService.cancelPayout(payout.id)
            await MainActor.run {
                // Show success message
                self.errorMessage = "Payout cancelled successfully. Funds have been restored to your wallet."
                self.showingError = true
            }
            await loadPayoutData() // Refresh data
        } catch {
            await MainActor.run {
                self.errorMessage = error.localizedDescription
                self.showingError = true
            }
        }
    }
}

// MARK: - Stat Card

struct StatCard: View {
    let title: String
    let value: String
    let subtitle: String
    let color: Color
    
    var body: some View {
        VStack(spacing: 8) {
            Text(title)
                .font(.caption)
                .foregroundColor(.secondary)
                .textCase(.uppercase)
            
            Text(value)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(color)
            
            Text(subtitle)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 16)
        .background(color.opacity(0.1))
        .cornerRadius(12)
    }
}

// MARK: - Payout Row

struct PayoutRow: View {
    let payout: Payout
    let onTap: () -> Void
    let onCancel: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                // Status Icon
                Image(systemName: payout.status.icon)
                    .font(.title3)
                    .foregroundColor(Color(payout.status.color))
                    .frame(width: 24)
                
                // Payout Details
                VStack(alignment: .leading, spacing: 4) {
                    Text(payout.formattedAmount)
                        .font(.subheadline)
                        .fontWeight(.semibold)
                        .foregroundColor(.primary)
                    
                    HStack(spacing: 8) {
                        Text(payout.payoutType.capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text("•")
                            .font(.caption)
                            .foregroundColor(.secondary)
                        
                        Text(payout.payoutMethod.replacingOccurrences(of: "_", with: " ").capitalized)
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Text(payout.createdAt, style: .relative)
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                // Action Button
                if payout.status == .pending || payout.status == .processing {
                    Button("Cancel") {
                        onCancel()
                    }
                    .font(.caption)
                    .fontWeight(.medium)
                    .foregroundColor(.facebookBlue)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Color.facebookBlue.opacity(0.1))
                    .cornerRadius(8)
                    .onTapGesture {
                        onCancel()
                    }
                } else {
                    Text(payout.status.displayName)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(Color(payout.status.color))
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .background(Color(payout.status.color).opacity(0.1))
                        .cornerRadius(8)
                }
            }
            .padding(16)
            .background(Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Payout Detail View

struct PayoutDetailView: View {
    let payout: Payout
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 24) {
                    // Status Header
                    statusHeader
                    
                    // Amount Details
                    amountDetails
                    
                    // Payout Information
                    payoutInfo
                    
                    // Timeline
                    timelineSection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 24)
            }
            .navigationTitle("Payout Details")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
    
    private var statusHeader: some View {
        VStack(spacing: 16) {
            Image(systemName: payout.status.icon)
                .font(.largeTitle)
                .foregroundColor(Color(payout.status.color))
            
            Text(payout.status.displayName)
                .font(.title2)
                .fontWeight(.bold)
                .foregroundColor(Color(payout.status.color))
            
            Text(payout.createdAt, style: .date)
                .font(.subheadline)
                .foregroundColor(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var amountDetails: some View {
        VStack(spacing: 16) {
            Text("Amount Details")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                DetailRow(title: "Payout Amount", value: payout.formattedAmount)
                DetailRow(title: "Processing Fee", value: payout.formattedFee, valueColor: .orange)
                Divider()
                DetailRow(title: "You'll Receive", value: payout.formattedNetAmount, valueColor: Color("ThemeColor"), isBold: true)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var payoutInfo: some View {
        VStack(spacing: 16) {
            Text("Payout Information")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 12) {
                DetailRow(title: "Type", value: payout.payoutType.capitalized)
                DetailRow(title: "Method", value: payout.payoutMethod.replacingOccurrences(of: "_", with: " ").capitalized)
                DetailRow(title: "Created", value: payout.createdAt.formatted(date: .abbreviated, time: .omitted))
                if let updatedAt = payout.updatedAt {
                    DetailRow(title: "Updated", value: updatedAt.formatted(date: .abbreviated, time: .omitted))
                }
                if let paidAt = payout.paidAt {
                    DetailRow(title: "Paid", value: paidAt.formatted(date: .abbreviated, time: .omitted))
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    private var timelineSection: some View {
        VStack(spacing: 16) {
            Text("Timeline")
                .font(.headline)
                .fontWeight(.semibold)
                .frame(maxWidth: .infinity, alignment: .leading)
            
            VStack(spacing: 16) {
                TimelineItem(
                    title: "Payout Requested",
                    subtitle: "Your payout request was submitted",
                    date: payout.createdAt,
                    icon: "clock",
                    color: .blue,
                    isCompleted: true
                )
                
                TimelineItem(
                    title: "Processing",
                    subtitle: "Payout is being processed",
                    date: payout.createdAt.addingTimeInterval(300), // 5 minutes later
                    icon: "arrow.triangle.2.circlepath",
                    color: .orange,
                    isCompleted: payout.status != .pending
                )
                
                TimelineItem(
                    title: "Completed",
                    subtitle: "Funds transferred to your account",
                    date: payout.paidAt ?? payout.updatedAt ?? payout.createdAt.addingTimeInterval(86400), // 1 day later
                    icon: "checkmark.circle.fill",
                    color: .green,
                    isCompleted: payout.isCompleted
                )
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
}

// MARK: - Detail Row

struct DetailRow: View {
    let title: String
    let value: String
    let valueColor: Color?
    let isBold: Bool
    
    init(title: String, value: String, valueColor: Color? = nil, isBold: Bool = false) {
        self.title = title
        self.value = value
        self.valueColor = valueColor
        self.isBold = isBold
    }
    
    init(title: String, value: Date, style: Date.FormatStyle) {
        self.title = title
        self.value = value.formatted(style)
        self.valueColor = nil
        self.isBold = false
    }
    
    var body: some View {
        HStack {
            Text(title)
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Spacer()
            
            Text(value)
                .font(.subheadline)
                .fontWeight(isBold ? .bold : .medium)
                .foregroundColor(valueColor ?? .primary)
        }
    }
}

// MARK: - Timeline Item

struct TimelineItem: View {
    let title: String
    let subtitle: String
    let date: Date
    let icon: String
    let color: Color
    let isCompleted: Bool
    
    var body: some View {
        HStack(spacing: 16) {
            // Icon
            Image(systemName: icon)
                .font(.title3)
                .foregroundColor(isCompleted ? color : .secondary)
                .frame(width: 24)
            
            // Content
            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(isCompleted ? .primary : .secondary)
                
                Text(subtitle)
                    .font(.caption)
                    .foregroundColor(.secondary)
                
                Text(date, style: .relative)
                    .font(.caption2)
                    .foregroundColor(.secondary)
            }
            
            Spacer()
            
            // Status indicator
            if isCompleted {
                Image(systemName: "checkmark.circle.fill")
                    .foregroundColor(color)
                    .font(.title3)
            }
        }
        .opacity(isCompleted ? 1.0 : 0.6)
    }
}

// MARK: - Preview

struct PayoutHistoryView_Previews: PreviewProvider {
    static var previews: some View {
        PayoutHistoryView(userId: "sample-user-id")
    }
}
