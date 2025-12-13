import SwiftUI
@_spi(STP) import StripePayments
import Supabase

/// View for adding debit card for instant payouts
/// Uses Stripe iOS SDK to securely collect card information
struct AddDebitCardView: View {
    let onCardAdded: () -> Void
    let onDismiss: () -> Void
    
    @EnvironmentObject private var authManager: AuthManager
    @State private var cardNumber: String = ""
    @State private var expMonth: String = ""
    @State private var expYear: String = ""
    @State private var cvc: String = ""
    @State private var isProcessing = false
    @State private var errorMessage: String?
    @State private var showingError = false
    
    @Environment(\.dismiss) private var dismiss
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                // Header
                headerSection
                
                ScrollView {
                    VStack(spacing: 24) {
                        // Info Banner
                        infoBanner
                        
                        // Card Input Form
                        cardFormSection
                        
                        // Add Card Button
                        addCardButton
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 24)
                }
            }
            .navigationBarHidden(true)
            .background(Color(.systemGroupedBackground))
        }
        .alert("Error", isPresented: $showingError) {
            Button("OK") { }
        } message: {
            Text(errorMessage ?? "An error occurred")
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
                
                Text("Add Debit Card")
                    .font(.headline)
                    .fontWeight(.semibold)
                
                Spacer()
                
                Button("Done") {
                    onDismiss()
                }
                .foregroundColor(.accentColor)
                .fontWeight(.medium)
                .opacity(0) // Hidden but maintains spacing
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            
            Divider()
        }
        .background(Color(.systemBackground))
    }
    
    // MARK: - Info Banner
    
    private var infoBanner: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 12) {
                Image(systemName: "bolt.fill")
                    .foregroundColor(.orange)
                    .font(.title3)
                
                Text("Instant Payouts")
                    .font(.headline)
                    .fontWeight(.semibold)
            }
            
            Text("Add a debit card to enable instant payouts (within minutes) for a 1.5% fee. Standard bank payouts remain free.")
                .font(.subheadline)
                .foregroundColor(.secondary)
            
            HStack(spacing: 16) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("⚡️ Instant")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Within minutes")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("💰 1.5% fee")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Stripe processing")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
                
                VStack(alignment: .leading, spacing: 4) {
                    Text("🔒 Secure")
                        .font(.caption)
                        .fontWeight(.medium)
                    Text("Stripe encrypted")
                        .font(.caption2)
                        .foregroundColor(.secondary)
                }
            }
        }
        .padding(16)
        .background(Color.orange.opacity(0.1))
        .cornerRadius(12)
    }
    
    // MARK: - Card Form Section
    
    private var cardFormSection: some View {
        VStack(alignment: .leading, spacing: 20) {
            Text("Debit Card Information")
                .font(.headline)
                .fontWeight(.semibold)
            
            VStack(spacing: 16) {
                // Card Number
                VStack(alignment: .leading, spacing: 8) {
                    Text("Card Number")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    
                    TextField("1234 5678 9012 3456", text: $cardNumber)
                        .keyboardType(.numberPad)
                        .textFieldStyle(RoundedTextFieldStyle())
                        .onChange(of: cardNumber) { newValue in
                            // Format card number with spaces
                            let filtered = newValue.filter { $0.isNumber }
                            let formatted = filtered.enumerated().map { index, char in
                                index > 0 && index % 4 == 0 ? " \(char)" : String(char)
                            }.joined()
                            if formatted != newValue {
                                cardNumber = String(formatted.prefix(19)) // 16 digits + 3 spaces
                            }
                        }
                }
                
                // Expiration & CVC
                HStack(spacing: 16) {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("MM")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("12", text: $expMonth)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .onChange(of: expMonth) { newValue in
                                expMonth = String(newValue.filter { $0.isNumber }.prefix(2))
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("YY")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("25", text: $expYear)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .onChange(of: expYear) { newValue in
                                expYear = String(newValue.filter { $0.isNumber }.prefix(2))
                            }
                    }
                    
                    VStack(alignment: .leading, spacing: 8) {
                        Text("CVC")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        
                        TextField("123", text: $cvc)
                            .keyboardType(.numberPad)
                            .textFieldStyle(RoundedTextFieldStyle())
                            .onChange(of: cvc) { newValue in
                                cvc = String(newValue.filter { $0.isNumber }.prefix(4))
                            }
                    }
                }
            }
            
            // Security Notice
            HStack(spacing: 8) {
                Image(systemName: "lock.shield.fill")
                    .font(.caption)
                    .foregroundColor(.green)
                
                Text("Your card information is encrypted and securely processed by Stripe. We never store your card details.")
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            .padding(12)
            .background(Color(.systemGray6))
            .cornerRadius(8)
        }
        .padding(20)
        .background(Color(.systemBackground))
        .cornerRadius(16)
    }
    
    // MARK: - Add Card Button
    
    private var addCardButton: some View {
        Button(action: addCard) {
            HStack {
                if isProcessing {
                    ProgressView()
                        .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        .scaleEffect(0.8)
                } else {
                    Text("Add Debit Card")
                        .font(.headline)
                        .fontWeight(.semibold)
                }
            }
            .foregroundColor(.white)
            .frame(maxWidth: .infinity)
            .padding(.vertical, 16)
            .background(canAddCard ? Color("ThemeColor") : Color(.systemGray4))
            .cornerRadius(12)
        }
        .disabled(!canAddCard || isProcessing)
        .padding(.bottom, 20)
    }
    
    // MARK: - Computed Properties
    
    private var canAddCard: Bool {
        let cleanCardNumber = cardNumber.filter { $0.isNumber }
        return cleanCardNumber.count == 16 &&
               expMonth.count == 2 &&
               expYear.count == 2 &&
               cvc.count >= 3 &&
               Int(expMonth) ?? 0 >= 1 && Int(expMonth) ?? 0 <= 12
    }
    
    // MARK: - Helper Methods
    
    private func addCard() {
        guard canAddCard else { return }
        
        isProcessing = true
        errorMessage = nil
        
        Task {
            do {
                // 1. Configure Stripe API client
                STPAPIClient.shared.publishableKey = Secrets.stripePublishableKey
                
                // 2. Create Stripe token from card details
                let cleanCardNumber = cardNumber.filter { $0.isNumber }
                
                let cardParams = STPCardParams()
                cardParams.number = cleanCardNumber
                cardParams.expMonth = UInt(expMonth) ?? 0
                cardParams.expYear = UInt("20\(expYear)") ?? 0
                cardParams.cvc = cvc
                
                // 3. Tokenize card with Stripe (bridge from callback to async/await)
                let token = try await withCheckedThrowingContinuation { (continuation: CheckedContinuation<STPToken, Error>) in
                    STPAPIClient.shared.createToken(withCard: cardParams) { token, error in
                        if let error = error {
                            continuation.resume(throwing: error)
                        } else if let token = token {
                            continuation.resume(returning: token)
                        } else {
                            continuation.resume(throwing: NSError(
                                domain: "AddDebitCard",
                                code: -1,
                                userInfo: [NSLocalizedDescriptionKey: "Failed to create token"]
                            ))
                        }
                    }
                }
                
                print("✅ Stripe token created: \(token.tokenId)")
                
                // 4. Call Edge Function to save card using the real token
                struct AddCardRequest: Encodable {
                    let token_id: String
                }
                
                struct AddCardResponse: Decodable {
                    let success: Bool?
                    let card_id: String?
                    let last4: String?
                    let brand: String?
                    let instant_available: Bool?
                    let error: String?
                    let error_type: String?
                    let error_code: String?
                }
                
                do {
                    let response: AddCardResponse = try await supabase.functions.invoke(
                        "add-debit-card",
                        options: .init(body: AddCardRequest(token_id: token.tokenId))
                    )
                    
                    if let error = response.error {
                        var fullError = error
                        if let errorType = response.error_type {
                            fullError += " (Type: \(errorType))"
                        }
                        if let errorCode = response.error_code {
                            fullError += " [Code: \(errorCode)]"
                        }
                        throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: fullError])
                    }
                    
                    print("✅ Card added successfully: ****\(response.last4 ?? "????") (\(response.brand ?? "Unknown"))")
                    
                    await MainActor.run {
                        isProcessing = false
                        onCardAdded()
                        dismiss()
                    }
                } catch let functionError as FunctionsError {
                    // Extract the actual error message from the Edge Function
                    print("❌ Edge Function error: \(functionError)")
                    let errorMsg = "Backend error: \(functionError.localizedDescription)"
                    throw NSError(domain: "", code: -1, userInfo: [NSLocalizedDescriptionKey: errorMsg])
                }
                
            } catch {
                print("❌ Error adding card: \(error.localizedDescription)")
                print("❌ Full error: \(error)")
                await MainActor.run {
                    isProcessing = false
                    errorMessage = error.localizedDescription
                    showingError = true
                }
            }
        }
    }
}

// MARK: - Custom Text Field Style

struct RoundedTextFieldStyle: TextFieldStyle {
    func _body(configuration: TextField<Self._Label>) -> some View {
        configuration
            .padding()
            .background(Color(.systemGray6))
            .cornerRadius(10)
    }
}

// MARK: - Preview

struct AddDebitCardView_Previews: PreviewProvider {
    static var previews: some View {
        AddDebitCardView(
            onCardAdded: {},
            onDismiss: {}
        )
    }
}

