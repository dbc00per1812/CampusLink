import SwiftUI

/// View for requesting payouts from Campus Wallet to external accounts
/// Provides options for standard vs instant payouts with different methods
struct PayoutRequestView: View {
    let availableBalance: Int
    let onPayoutRequested: (Payout) -> Void
    let onDismiss: () -> Void
    
    @StateObject private var payoutService = PayoutService.shared
    @EnvironmentObject private var authManager: AuthManager
    @State private var selectedPayoutType: PayoutService.PayoutType = .standard
    @State private var selectedPayoutMethod: PayoutService.PayoutMethod = .bankAccount
    @State private var amountCents: Int = 0
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var hasDebitCard: Bool = false
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Balance Display
                        balanceSection
                        
                        // Amount Input
                        amountSection
                        
                        // Payout Type Selection
                        payoutTypeSection
                        
                        // Payout Method Selection
                        payoutMethodSection
                        
                        // Fee Breakdown
                        feeBreakdownSection
                        
                        // Request Button
                        requestButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
            .hideKeyboardOnTap()
        }
        .alert("Payout Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
        }
        .task {
            await checkDebitCardStatus()
        }
    }
    
    // MARK: - Header Section
    
    private var headerSection: some View {
        VStack(spacing: 16) {
            HStack {
                Button("Cancel") {
                    onDismiss()
                }
                .foregroundColor(.secondary)
                
                Spacer()
                
                Text("Request Payout")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    onDismiss()
                }
                .foregroundColor(.accentColor)
                .fontWeight(.medium)
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Balance Section
    
    private var balanceSection: some View {
        VStack(spacing: 12) {
            Text("Available Balance")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            Text(formatAmount(availableBalance))
                .font(.largeTitle)
                .fontWeight(.bold)
                .foregroundColor(Color("ThemeColor"))
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Amount Section
    
    private var amountSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payout Amount")
                .font(.headline)
                .fontWeight(.semibold)
            
            HStack {
                Text("$")
                    .font(.title2)
                    .fontWeight(.medium)
                    .foregroundColor(.secondary)
                
                TextField("0.00", value: Binding(
                    get: { Double(amountCents) / 100.0 },
                    set: { amountCents = Int($0 * 100) }
                ), format: .number)
                .font(.title2)
                .fontWeight(.medium)
                .keyboardType(.decimalPad)
                .textFieldStyle(PlainTextFieldStyle())
                
                Spacer()
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)
            .background(Color(.systemGray6))
            .cornerRadius(12)
            
            // Quick amount buttons
            HStack(spacing: 12) {
                ForEach([25, 50, 100, 250], id: \.self) { amount in
                    Button("$\(amount)") {
                        amountCents = amount * 100
                    }
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .foregroundColor(amountCents == amount * 100 ? .white : .primary)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(amountCents == amount * 100 ? Color("ThemeColor") : Color(.systemGray5))
                    .cornerRadius(20)
                }
                
                // "All" button to select full available balance
                Button("All") {
                    amountCents = availableBalance
                }
                .font(.subheadline)
                .fontWeight(.medium)
                .foregroundColor(amountCents == availableBalance ? .white : .primary)
                .padding(.horizontal, 16)
                .padding(.vertical, 8)
                .background(amountCents == availableBalance ? Color("ThemeColor") : Color(.systemGray5))
                .cornerRadius(20)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Payout Type Section
    
    private var payoutTypeSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payout Type")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(PayoutService.PayoutType.allCases, id: \.self) { payoutType in
                    if payoutType == .standard || (payoutType == .instant && hasDebitCard) {
                        PayoutTypeOption(
                            payoutType: payoutType,
                            isSelected: selectedPayoutType == payoutType,
                            onTap: {
                                selectedPayoutType = payoutType
                                // Auto-select appropriate method
                                if payoutType == .instant {
                                    selectedPayoutMethod = .debitCard
                                } else {
                                    selectedPayoutMethod = .bankAccount
                                }
                            }
                        )
                    }
                }
                
                // Show info about instant payouts if no debit card
                if !hasDebitCard {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle.fill")
                            .font(.title3)
                            .foregroundColor(.orange)
                        
                        VStack(alignment: .leading, spacing: 4) {
                            Text("Instant Payouts Unavailable")
                                .font(.subheadline)
                                .fontWeight(.medium)
                            
                            Text("Complete Stripe Connect onboarding with a debit card to enable instant payouts (1.5% fee)")
                                .font(.caption)
                                .foregroundColor(.secondary)
                        }
                        
                        Spacer()
                    }
                    .padding(16)
                    .background(Color.orange.opacity(0.1))
                    .cornerRadius(12)
                }
                
                // Info about holding period for new accounts
                HStack(spacing: 12) {
                    Image(systemName: "clock.fill")
                        .font(.title3)
                        .foregroundColor(.blue)
                    
                    VStack(alignment: .leading, spacing: 4) {
                        Text("First Payout Timing")
                            .font(.subheadline)
                            .fontWeight(.medium)
                        
                        Text("New accounts: First payout may take 2-7 days. After that, standard payouts are 2-3 days and instant payouts are immediate.")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                }
                .padding(16)
                .background(Color.blue.opacity(0.1))
                .cornerRadius(12)
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Payout Method Section
    
    private var payoutMethodSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Payout Method")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                ForEach(PayoutService.PayoutMethod.allCases, id: \.self) { method in
                    PayoutMethodOption(
                        method: method,
                        isSelected: selectedPayoutMethod == method,
                        isEnabled: isMethodEnabled(for: method),
                        onTap: {
                            if isMethodEnabled(for: method) {
                                selectedPayoutMethod = method
                            }
                        }
                    )
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Fee Breakdown Section
    
    private var feeBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 16) {
            Text("Fee Breakdown")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 12) {
                HStack {
                    Text("Payout Amount")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatAmount(amountCents))
                        .font(.subheadline)
                        .fontWeight(.medium)
                }
                
                HStack {
                    Text("Processing Fee")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    Spacer()
                    Text(formatAmount(Int(Double(amountCents) * selectedPayoutType.feePercentage)))
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(selectedPayoutType.feePercentage > 0 ? .orange : .green)
                }
                
                Divider()
                
                HStack {
                    Text("You'll Receive")
                        .font(.subheadline)
                        .fontWeight(.semibold)
                    Spacer()
                    Text(formatAmount(Int(Double(amountCents) * (1 - selectedPayoutType.feePercentage))))
                        .font(.subheadline)
                        .fontWeight(.bold)
                        .foregroundColor(Color("ThemeColor"))
                }
            }
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Request Button
    
    private var requestButton: some View {
        VStack(spacing: 8) {
            Button(action: requestPayout) {
                HStack {
                    if isProcessing {
                        ProgressView()
                            .progressViewStyle(CircularProgressViewStyle(tint: .white))
                            .scaleEffect(0.8)
                    } else {
                        Text("Request Payout")
                            .font(.headline)
                            .fontWeight(.semibold)
                    }
                }
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(canRequestPayout ? Color("ThemeColor") : Color(.systemGray4))
                .cornerRadius(12)
            }
            .disabled(!canRequestPayout || isProcessing)
            
            // Validation message
            if let message = validationMessage {
                Text(message)
                    .font(.caption)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(.bottom, 20)
    }
    
    // MARK: - Computed Properties
    
    private var canRequestPayout: Bool {
        amountCents > 0 && 
        amountCents <= availableBalance &&
        amountCents >= 50 // Minimum $0.50
    }
    
    private var validationMessage: String? {
        if amountCents == 0 {
            return "Enter an amount to request payout"
        } else if amountCents < 50 {
            return "Minimum payout amount is $0.50"
        } else if amountCents > availableBalance {
            return "Amount exceeds available balance"
        }
        return nil
    }
    
    // MARK: - Helper Methods
    
    private func isMethodEnabled(for method: PayoutService.PayoutMethod) -> Bool {
        switch (selectedPayoutType, method) {
        case (.standard, .bankAccount):
            return true
        case (.instant, .debitCard):
            return hasDebitCard // Only enable if user has added a debit card
        default:
            return false
        }
    }
    
    private func checkDebitCardStatus() async {
        // Check if user has a debit card on file
        struct GetCardsResponse: Decodable {
            let cards: [DebitCard]?
            let count: Int?
            let error: String?
        }
        
        struct DebitCard: Decodable {
            let id: String
            let last4: String
            let brand: String
        }
        
        do {
            let response: GetCardsResponse = try await supabase.functions.invoke(
                "super-handler"
            )
            
            await MainActor.run {
                hasDebitCard = (response.count ?? 0) > 0
            }
        } catch {
            print("Error checking debit card status: \(error)")
            // Default to false if error
            await MainActor.run {
                hasDebitCard = false
            }
        }
    }
    
    private func formatAmount(_ cents: Int) -> String {
        let amount = Double(cents) / 100.0
        return String(format: "$%.2f", amount)
    }
    
    private func requestPayout() {
        guard canRequestPayout else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                guard let userId = authManager.session?.user.id.uuidString else {
                    throw PayoutServiceError.authenticationRequired
                }
                
                let payout = try await payoutService.requestPayout(
                    amountCents: amountCents,
                    payoutType: selectedPayoutType,
                    payoutMethod: selectedPayoutMethod,
                    accountId: userId
                )
                
                await MainActor.run {
                    isProcessing = false
                    onPayoutRequested(payout)
                    dismiss()
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

// MARK: - Payout Type Option

struct PayoutTypeOption: View {
    let payoutType: PayoutService.PayoutType
    let isSelected: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(payoutType.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : .primary)
                    
                    Text(payoutType.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(payoutType.processingTime)
                        .font(.caption)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : .secondary)
                    
                    if payoutType.feePercentage > 0 {
                        Text("\(payoutType.feePercentage * 100, specifier: "%.1f")% fee")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.orange)
                    } else {
                        Text("No fee")
                            .font(.caption)
                            .fontWeight(.medium)
                            .foregroundColor(.green)
                    }
                }
            }
            .padding(16)
            .background(isSelected ? Color("ThemeColor") : Color(.systemGray6))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
    }
}

// MARK: - Payout Method Option

struct PayoutMethodOption: View {
    let method: PayoutService.PayoutMethod
    let isSelected: Bool
    let isEnabled: Bool
    let onTap: () -> Void
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: method.icon)
                    .font(.title3)
                    .foregroundColor(isSelected ? .white : (isEnabled ? .primary : .secondary))
                    .frame(width: 24)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(method.displayName)
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(isSelected ? .white : (isEnabled ? .primary : .secondary))
                    
                    Text(method.description)
                        .font(.caption)
                        .foregroundColor(isSelected ? .white.opacity(0.8) : (isEnabled ? .secondary : .secondary.opacity(0.5)))
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(.white)
                        .font(.title3)
                }
            }
            .padding(16)
            .background(isSelected ? Color("ThemeColor") : (isEnabled ? Color(.systemGray6) : Color(.systemGray5)))
            .cornerRadius(12)
        }
        .buttonStyle(PlainButtonStyle())
        .disabled(!isEnabled)
    }
}

// MARK: - Preview

struct PayoutRequestView_Previews: PreviewProvider {
    static var previews: some View {
        PayoutRequestView(
            availableBalance: 5000, // $50.00
            onPayoutRequested: { _ in },
            onDismiss: {}
        )
    }
}
