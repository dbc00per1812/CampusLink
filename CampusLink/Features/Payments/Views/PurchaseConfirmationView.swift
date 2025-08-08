import SwiftUI

/// A view that displays the result of a payment attempt.
/// Shows success, failure, or cancellation messages with appropriate UI feedback.
struct PurchaseConfirmationView: View {
    let listing: ListingWithUser
    let paymentResult: PaymentSheetResult?
    let onDismiss: () -> Void
    
    @Environment(\.dismiss) private var dismiss
    
    private var statusIcon: String {
        guard let result = paymentResult else { return "questionmark.circle" }
        switch result {
        case .completed:
            return "checkmark.circle.fill"
        case .canceled:
            return "xmark.circle"
        case .failed:
            return "exclamationmark.triangle.fill"
        }
    }
    
    private var statusColor: Color {
        guard let result = paymentResult else { return .gray }
        switch result {
        case .completed:
            return .green
        case .canceled:
            return .orange
        case .failed:
            return .red
        }
    }
    
    private var statusTitle: String {
        guard let result = paymentResult else { return "Processing Payment..." }
        switch result {
        case .completed:
            return "Payment Successful!"
        case .canceled:
            return "Payment Canceled"
        case .failed:
            return "Payment Failed"
        }
    }
    
    private var statusMessage: String {
        guard let result = paymentResult else { 
            return "Please wait while we process your payment."
        }
        switch result {
        case .completed:
            return "Your purchase of \"\(listing.title)\" for $\(String(format: "%.2f", listing.price)) has been completed successfully.\n\nThe seller has been notified and will contact you about delivery."
        case .canceled:
            return "You canceled the payment process. No charges were made to your account."
        case .failed(let error):
            return "There was an error processing your payment: \(error.localizedDescription)\n\nPlease try again or contact support if the issue persists."
        }
    }
    
    var body: some View {
        NavigationView {
            VStack(spacing: 30) {
                Spacer()
                
                // Status Icon
                Image(systemName: statusIcon)
                    .font(.system(size: 80))
                    .foregroundColor(statusColor)
                    .padding()
                
                // Status Title
                Text(statusTitle)
                    .font(.largeTitle)
                    .fontWeight(.bold)
                    .multilineTextAlignment(.center)
                
                // Status Message
                Text(statusMessage)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 30)
                
                Spacer()
                
                // Action Buttons
                VStack(spacing: 16) {
                    if case .completed = paymentResult {
                        // Success actions
                        Button(action: {
                            onDismiss()
                        }) {
                            Text("View My Purchases")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("ThemeColor"))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)
                        
                        Button(action: {
                            // TODO: Navigate to messaging with seller
                            print("📱 Contact seller about delivery")
                            onDismiss()
                        }) {
                            Text("Contact Seller")
                                .font(.headline)
                                .foregroundColor(Color("ThemeColor"))
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(
                                    RoundedRectangle(cornerRadius: 12)
                                        .stroke(Color("ThemeColor"), lineWidth: 2)
                                )
                        }
                        .padding(.horizontal, 30)
                    } else if case .failed = paymentResult {
                        // Failure actions
                        Button(action: {
                            dismiss()
                        }) {
                            Text("Try Again")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color("ThemeColor"))
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)
                        
                        Button(action: {
                            onDismiss()
                        }) {
                            Text("Cancel")
                                .font(.headline)
                                .foregroundColor(.secondary)
                        }
                    } else {
                        // Canceled or processing
                        Button(action: {
                            onDismiss()
                        }) {
                            Text("Done")
                                .font(.headline)
                                .foregroundColor(.white)
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(Color.gray)
                                .cornerRadius(12)
                        }
                        .padding(.horizontal, 30)
                    }
                }
                
                Spacer()
            }
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Close") {
                        onDismiss()
                    }
                }
            }
        }
        .onAppear {
            // Haptic feedback based on result
            if let result = paymentResult {
                let generator = UINotificationFeedbackGenerator()
                switch result {
                case .completed:
                    generator.notificationOccurred(.success)
                case .failed:
                    generator.notificationOccurred(.error)
                case .canceled:
                    generator.notificationOccurred(.warning)
                }
            }
        }
    }
}

// MARK: - Preview

struct PurchaseConfirmationView_Previews: PreviewProvider {
    static var previews: some View {
        Group {
            // Success state
            PurchaseConfirmationView(
                listing: sampleListing,
                paymentResult: .completed,
                onDismiss: {}
            )
            .previewDisplayName("Success")
            
            // Failed state
            PurchaseConfirmationView(
                listing: sampleListing,
                paymentResult: .failed(NSError(domain: "StripeError", code: 1001, userInfo: [NSLocalizedDescriptionKey: "Your card was declined"])),
                onDismiss: {}
            )
            .previewDisplayName("Failed")
            
            // Canceled state
            PurchaseConfirmationView(
                listing: sampleListing,
                paymentResult: .canceled,
                onDismiss: {}
            )
            .previewDisplayName("Canceled")
        }
    }
    
    static var sampleListing: ListingWithUser {
        ListingWithUser(
            id: UUID(),
            title: "MacBook Pro 14\"",
            description: "Excellent condition laptop",
            price: 1299.99,
            category: "Electronics",
            photo: nil,
            isSold: false,
            listingType: .product,
            serviceDuration: nil,
            serviceLocation: nil,
            serviceAvailability: nil,
            createdAt: Date(),
            user: UserProfile(
                id: UUID().uuidString,
                name: "John Doe",
                bio: nil,
                profilePic: nil,
                email: "john@university.edu",
                createdAt: Date()
            )
        )
    }
}
