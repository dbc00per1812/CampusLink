import SwiftUI
import Combine

struct PaymentMethodSheet: View {
    let listing: ListingWithUser
    let wallet: Wallet?
    let onPaymentMethodSelected: (PaymentMethod) -> Void
    
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @StateObject private var feeService = FeeCalculationService.shared
    @State private var selectedPaymentMethod: PaymentMethod?
    @State private var showingWalletInfo = false
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    @State private var animationOffset: CGFloat = 50
    @State private var animationOpacity: Double = 0
    
    private var priceCents: Int { Int((listing.price ?? 0) * 100) }
    private var stripeFeeCents: Int { feeService.calculateStripeProcessingFee(amountCents: priceCents) }
    private var totalWithFeesCents: Int { feeService.calculateTotalWithFees(baseAmountCents: priceCents) }
    private var canUseWallet: Bool {
        guard let wallet = wallet else { return false }
        return wallet.availableCents >= priceCents
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                VStack(spacing: 16) {
                    Text("Choose Payment Method")
                        .font(.title2)
                        .fontWeight(.bold)
                        .foregroundColor(.primary)
                        .accessibilityAddTraits(.isHeader)
                    
                    Text("Select how you'd like to pay for this item")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .accessibilityLabel("Payment method selection instructions")
                    
                    // Price display with fee breakdown
                    VStack(spacing: 12) {
                        // Base price
                        HStack {
                            Text("Item Price:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityLabel("Item price")
                            Spacer()
                            Text("$\((listing.price ?? 0), specifier: "%.2f")")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityLabel("Item price \((listing.price ?? 0), specifier: "%.2f") dollars")
                        }
                        
                        // Stripe processing fee
                        HStack {
                            Text("Processing Fee:")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityLabel("Stripe processing fee")
                            Spacer()
                            Text(feeService.formatFee(feeCents: stripeFeeCents))
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .accessibilityLabel("Processing fee \(feeService.formatFee(feeCents: stripeFeeCents))")
                        }
                        
                        // Divider
                        Divider()
                            .background(Color.secondary.opacity(0.3))
                        
                        // Total with fees
                        HStack {
                            Text("Total:")
                                .font(.headline)
                                .fontWeight(.semibold)
                                .foregroundColor(.primary)
                                .accessibilityLabel("Total amount including fees")
                            Spacer()
                            Text(feeService.formatTotal(totalCents: totalWithFeesCents))
                                .font(.title2)
                                .fontWeight(.bold)
                                .foregroundColor(Color("ThemeColor"))
                                .accessibilityLabel("Total price including fees \(feeService.formatTotal(totalCents: totalWithFeesCents))")
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 16)
                    .background(Color("ThemeColor").opacity(0.1))
                    .cornerRadius(12)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)
                .opacity(animationOpacity)
                .offset(y: animationOffset)
                
                // Payment Methods
                ScrollView {
                    VStack(spacing: 16) {
                        // Wallet Payment Option
                        PaymentMethodOption(
                            title: "Wallet Payment",
                            subtitle: wallet?.formattedAvailableBalance ?? "Loading...",
                            icon: "creditcard.fill",
                            iconColor: .green,
                            isEnabled: canUseWallet,
                            isSelected: selectedPaymentMethod == .wallet,
                            onTap: {
                                selectPaymentMethod(.wallet)
                            }
                        )
                        .accessibilityLabel("Wallet payment option")
                        .accessibilityHint(canUseWallet ? "Sufficient funds available" : "Insufficient funds")
                        
                        if let wallet = wallet {
                            if canUseWallet {
                                HStack {
                                    Image(systemName: "checkmark.circle.fill")
                                        .foregroundColor(.green)
                                        .font(.caption)
                                        .accessibilityHidden(true)
                                    Text("Sufficient funds available")
                                        .font(.caption)
                                        .foregroundColor(.green)
                                        .accessibilityLabel("Wallet has sufficient funds")
                                    Spacer()
                                }
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .scale))
                            } else {
                                HStack {
                                    Image(systemName: "exclamationmark.triangle.fill")
                                        .foregroundColor(.orange)
                                        .font(.caption)
                                        .accessibilityHidden(true)
                                    Text("Insufficient funds - need $\((listing.price ?? 0), specifier: "%.2f")")
                                        .font(.caption)
                                        .foregroundColor(.orange)
                                        .accessibilityLabel("Insufficient funds, need \((listing.price ?? 0), specifier: "%.2f") dollars")
                                    Spacer()
                                    Button("Add Funds") {
                                        showingWalletInfo = true
                                    }
                                    .font(.caption)
                                    .foregroundColor(.blue)
                                    .accessibilityLabel("Add funds to wallet")
                                }
                                .padding(.horizontal, 20)
                                .transition(.opacity.combined(with: .scale))
                            }
                        }
                        
                        // Card Payment Option
                        PaymentMethodOption(
                            title: "Credit/Debit Card",
                            subtitle: "Secure payment via Stripe",
                            icon: "creditcard",
                            iconColor: .blue,
                            isEnabled: true,
                            isSelected: selectedPaymentMethod == .card,
                            onTap: {
                                selectPaymentMethod(.card)
                            }
                        )
                        .accessibilityLabel("Credit or debit card payment option")
                        .accessibilityHint("Secure payment via Stripe")
                        

                        
                        // Escrow Protection Info
                        VStack(alignment: .leading, spacing: 12) {
                            HStack {
                                Image(systemName: "shield.checkered")
                                    .foregroundColor(.green)
                                    .font(.title3)
                                    .accessibilityHidden(true)
                                Text("Escrow Protection")
                                    .font(.headline)
                                    .foregroundColor(.primary)
                                    .accessibilityAddTraits(.isHeader)
                            }
                            
                            Text("Your payment is held securely until you confirm receipt. This protects both buyers and sellers.")
                                .font(.subheadline)
                                .foregroundColor(.secondary)
                                .lineSpacing(2)
                                .accessibilityLabel("Escrow protection explanation")
                            
                            HStack(spacing: 16) {
                                EscrowFeatureRow(
                                    icon: "clock",
                                    title: "Secure Holding",
                                    description: "Funds held until delivery"
                                )
                                
                                EscrowFeatureRow(
                                    icon: "checkmark.shield",
                                    title: "Buyer Protection",
                                    description: "Get refund if item not as described"
                                )
                                
                                EscrowFeatureRow(
                                    icon: "arrow.left.arrow.right",
                                    title: "Seller Protection",
                                    description: "Payment guaranteed on delivery"
                                )
                            }
                        }
                        .padding(20)
                        .background(Color.green.opacity(0.1))
                        .cornerRadius(16)
                        .padding(.horizontal, 20)
                        .accessibilityElement(children: .combine)
                        .accessibilityLabel("Escrow protection features")
                    }
                    .padding(.vertical, 20)
                }
                
                // Continue Button
                VStack(spacing: 16) {
                    Button(action: {
                        processPaymentMethodSelection()
                    }) {
                        HStack {
                            if isProcessing {
                                ProgressView()
                                    .progressViewStyle(CircularProgressViewStyle(tint: .white))
                                    .scaleEffect(0.8)
                                    .accessibilityLabel("Processing payment method selection")
                            } else {
                                Text("Continue with \(selectedPaymentMethod?.displayName ?? "Payment Method")")
                                    .font(.headline)
                                    .fontWeight(.semibold)
                                    .foregroundColor(.white)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 16)
                        .background(selectedPaymentMethod != nil && !isProcessing ? Color("ThemeColor") : Color.gray)
                        .cornerRadius(12)
                    }
                    .disabled(selectedPaymentMethod == nil || isProcessing)
                    .padding(.horizontal, 20)
                    .accessibilityLabel("Continue with selected payment method")
                    .accessibilityHint(selectedPaymentMethod == nil ? "Select a payment method first" : "Proceed with \(selectedPaymentMethod?.displayName ?? "")")
                    
                    Button("Cancel") {
                        dismiss()
                    }
                    .font(.subheadline)
                    .foregroundColor(.secondary)
                    .padding(.bottom, 20)
                    .accessibilityLabel("Cancel payment method selection")
                }
                .background(Color(UIColor.systemBackground))
            }
            .navigationBarHidden(true)
            .onAppear {
                animateIn()
            }
        }
        .sheet(isPresented: $showingWalletInfo) {
            WalletInfoSheet()
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") {
                errorMessage = nil
                showingError = false
            }
        } message: {
            Text(errorMessage ?? "An unknown error occurred")
        }
        .accessibilityAction(.escape) {
            dismiss()
        }
    }
    
    // MARK: - Private Methods
    
    private func selectPaymentMethod(_ method: PaymentMethod) {
        let impactFeedback = UIImpactFeedbackGenerator(style: .medium)
        impactFeedback.impactOccurred()
        
        withAnimation(.easeInOut(duration: 0.2)) {
            selectedPaymentMethod = method
        }
        
        // Analytics tracking
        #if DEBUG
        print("📱 Payment method selected: \(method.displayName)")
        #endif
    }
    
    private func processPaymentMethodSelection() {
        guard let selectedMethod = selectedPaymentMethod else { return }
        
        isProcessing = true
        
        // Simulate processing delay for better UX
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            isProcessing = false
            
            // Success haptic feedback
            let successFeedback = UINotificationFeedbackGenerator()
            successFeedback.notificationOccurred(.success)
            
            // Call the callback
            onPaymentMethodSelected(selectedMethod)
        }
    }
    
    private func animateIn() {
        withAnimation(.easeOut(duration: 0.6)) {
            animationOffset = 0
            animationOpacity = 1
        }
    }
}

// MARK: - Payment Method Option

struct PaymentMethodOption: View {
    let title: String
    let subtitle: String
    let icon: String
    let iconColor: Color
    let isEnabled: Bool
    let isSelected: Bool
    let onTap: () -> Void
    
    @State private var isPressed = false
    
    var body: some View {
        Button(action: onTap) {
            HStack(spacing: 16) {
                Image(systemName: icon)
                    .font(.title2)
                    .foregroundColor(iconColor)
                    .frame(width: 24)
                    .accessibilityHidden(true)
                
                VStack(alignment: .leading, spacing: 4) {
                    Text(title)
                        .font(.headline)
                        .foregroundColor(isEnabled ? .primary : .secondary)
                    
                    Text(subtitle)
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
                
                Spacer()
                
                if isSelected {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundColor(Color("ThemeColor"))
                        .font(.title2)
                        .accessibilityHidden(true)
                        .transition(.scale.combined(with: .opacity))
                } else {
                    Image(systemName: "circle")
                        .foregroundColor(.secondary)
                        .font(.title2)
                        .accessibilityHidden(true)
                }
            }
            .padding(20)
            .background(
                RoundedRectangle(cornerRadius: 12)
                    .fill(isSelected ? Color("ThemeColor").opacity(0.1) : Color(UIColor.systemGray6))
                    .overlay(
                        RoundedRectangle(cornerRadius: 12)
                            .stroke(isSelected ? Color("ThemeColor") : Color.clear, lineWidth: 2)
                    )
            )
            .scaleEffect(isPressed ? 0.95 : 1.0)
            .animation(.easeInOut(duration: 0.1), value: isPressed)
        }
        .disabled(!isEnabled)
        .buttonStyle(PlainButtonStyle())
        .onLongPressGesture(minimumDuration: 0, maximumDistance: .infinity, pressing: { pressing in
            isPressed = pressing
        }, perform: {})
        .accessibilityElement(children: .combine)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
        .accessibilityHint(isEnabled ? "Tap to select this payment method" : "This payment method is not available")
    }
}

// MARK: - Escrow Feature Row

struct EscrowFeatureRow: View {
    let icon: String
    let title: String
    let description: String
    
    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: icon)
                .font(.title2)
                .foregroundColor(.green)
                .accessibilityHidden(true)
            
            Text(title)
                .font(.caption)
                .fontWeight(.semibold)
                .foregroundColor(.primary)
                .multilineTextAlignment(.center)
            
            Text(description)
                .font(.caption2)
                .foregroundColor(.secondary)
                .multilineTextAlignment(.center)
                .lineLimit(2)
        }
        .frame(maxWidth: .infinity)
        .accessibilityElement(children: .combine)
        .accessibilityLabel("\(title): \(description)")
    }
}

// MARK: - Wallet Info Sheet

struct WalletInfoSheet: View {
    @Environment(\.dismiss) private var dismiss
    @Environment(\.colorScheme) private var colorScheme
    @State private var animationOffset: CGFloat = 30
    @State private var animationOpacity: Double = 0
    
    var body: some View {
        NavigationView {
            VStack(spacing: 20) {
                Image(systemName: "creditcard.fill")
                    .font(.system(size: 60))
                    .foregroundColor(Color("ThemeColor"))
                    .accessibilityHidden(true)
                
                Text("Add Funds to Wallet")
                    .font(.title2)
                    .fontWeight(.bold)
                    .accessibilityAddTraits(.isHeader)
                
                Text("You can add funds to your wallet using a credit/debit card or bank transfer. Funds are held securely and can be used for future purchases.")
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .lineSpacing(4)
                    .accessibilityLabel("Wallet funding instructions")
                
                VStack(alignment: .leading, spacing: 12) {
                    FeatureRow(icon: "creditcard", text: "Add funds with any major credit/debit card")
                    FeatureRow(icon: "banknote", text: "Bank transfer available for larger amounts")
                    FeatureRow(icon: "shield", text: "Secure payment processing via Stripe")
                    FeatureRow(icon: "clock", text: "Funds available immediately after processing")
                }
                .padding(.vertical, 20)
                
                Spacer()
                
                Button("Go to Wallet") {
                    // TODO: Navigate to wallet view
                    dismiss()
                }
                .font(.headline)
                .foregroundColor(.white)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
                .background(Color("ThemeColor"))
                .cornerRadius(12)
                .padding(.horizontal, 20)
                .accessibilityLabel("Navigate to wallet view")
            }
            .padding(20)
            .navigationTitle("Wallet")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                    .accessibilityLabel("Close wallet information")
                }
            }
            .onAppear {
                animateIn()
            }
        }
        .opacity(animationOpacity)
        .offset(y: animationOffset)
    }
    
    private func animateIn() {
        withAnimation(.easeOut(duration: 0.5)) {
            animationOffset = 0
            animationOpacity = 1
        }
    }
}

struct FeatureRow: View {
    let icon: String
    let text: String
    
    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .foregroundColor(Color("ThemeColor"))
                .frame(width: 20)
                .accessibilityHidden(true)
            
            Text(text)
                .font(.subheadline)
                .foregroundColor(.primary)
            
            Spacer()
        }
        .accessibilityLabel(text)
    }
}

// MARK: - Previews

struct PaymentMethodSheet_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            PaymentMethodSheet(
                listing: ListingWithUser.sampleListing,
                wallet: Wallet(
                    userId: UUID(),
                    availableCents: 5000,
                    escrowCents: 0,
                    updatedAt: Date()
                ),
                onPaymentMethodSelected: { _ in }
            )
            .previewDisplayName("Sufficient Funds")
            
            PaymentMethodSheet(
                listing: ListingWithUser.sampleListing,
                wallet: Wallet(
                    userId: UUID(),
                    availableCents: 1000,
                    escrowCents: 0,
                    updatedAt: Date()
                ),
                onPaymentMethodSelected: { _ in }
            )
            .previewDisplayName("Insufficient Funds")
            
            PaymentMethodSheet(
                listing: ListingWithUser.sampleListing,
                wallet: nil,
                onPaymentMethodSelected: { _ in }
            )
            .previewDisplayName("No Wallet")
        }
    }
}
