import SwiftUI

struct OfferComposeView: View {
    let seekListing: ListingWithUser
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var selectedListing: ListingWithUser?
    @State private var message = ""
    @State private var isLoading = false
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack(spacing: 0) {
                if AppConfig.enableSeekMode {
                    // Full implementation will go here
                    ScrollView {
                        VStack(spacing: 20) {
                            // Seeker info section
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Responding to:")
                                    .font(.headline)
                                    .foregroundColor(.secondary)
                                
                                HStack {
                                    Text(seekListing.title)
                                        .font(.title3)
                                        .fontWeight(.semibold)
                                    Spacer()
                                }
                                
                                if let budgetMin = seekListing.budgetMin, let budgetMax = seekListing.budgetMax {
                                    Text("Budget: $\(budgetMin, specifier: "%.2f") - $\(budgetMax, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                } else if let budgetMax = seekListing.budgetMax {
                                    Text("Budget: Up to $\(budgetMax, specifier: "%.2f")")
                                        .font(.subheadline)
                                        .foregroundColor(.secondary)
                                }
                            }
                            .padding()
                            .background(Color(.secondarySystemBackground))
                            .cornerRadius(12)
                            
                            // Listing selection
                            VStack(alignment: .leading, spacing: 12) {
                                Text("Select your listing to offer:")
                                    .font(.headline)
                                
                                // Placeholder for listing selection
                                Text("Listing selection coming soon...")
                                    .foregroundColor(.secondary)
                                    .frame(maxWidth: .infinity)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(8)
                            }
                            
                            // Message input
                            VStack(alignment: .leading, spacing: 8) {
                                Text("Message (optional)")
                                    .font(.headline)
                                TextField("Add a message to the seeker...", text: $message, axis: .vertical)
                                    .lineLimit(3...6)
                                    .padding()
                                    .background(Color(.systemGray6))
                                    .cornerRadius(12)
                            }
                            
                            // Submit button
                            Button(action: submitOffer) {
                                HStack {
                                    if isLoading {
                                        ProgressView()
                                            .scaleEffect(0.8)
                                    }
                                    Text(isLoading ? "Sending Offer..." : "Send Offer")
                                }
                                .frame(maxWidth: .infinity)
                                .padding()
                                .background(selectedListing == nil ? Color.gray : Color("ThemeColor"))
                                .foregroundColor(.white)
                                .cornerRadius(12)
                            }
                            .disabled(selectedListing == nil || isLoading)
                        }
                        .padding()
                    }
                } else {
                    // Feature disabled message
                    VStack(spacing: 20) {
                        Image(systemName: "hammer.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Coming Soon")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("The ability to respond to wanted posts is currently under development.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Make an Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
            }
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
    
    private func submitOffer() {
        // Stub implementation
        guard AppConfig.enableSeekMode else { return }
        
        // TODO: Implement offer submission
        errorMessage = "Offer submission not yet implemented"
    }
}

struct OfferComposeView_Previews: PreviewProvider {
    static var previews: some View {
        OfferComposeView(seekListing: .sampleListing)
            .environmentObject(AuthManager())
    }
}
