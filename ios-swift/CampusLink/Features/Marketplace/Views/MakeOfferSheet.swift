import SwiftUI

struct MakeOfferSheet: View {
    let listing: ListingWithUser
    @Environment(\.dismiss) private var dismiss
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var offerAmount: String = ""
    @State private var offerMessage: String = ""
    @State private var isSubmitting = false
    @State private var errorMessage: String?
    @State private var showOfferSent = false
    
    @StateObject private var offerService = UnifiedOfferService.shared
    
    // Computed properties
    private var offerAmountCents: Int? {
        guard let amount = Double(offerAmount), amount > 0 else { return nil }
        return Int(amount * 100)
    }
    
    private var isValidOffer: Bool {
        guard let amount = Double(offerAmount), amount > 0 else { return false }
        return true
    }
    
    private var listingType: OfferListingType {
        listing.intent == .seek ? .seek : .regular
    }
    
    private var role: String {
        listing.intent == .seek ? "seller" : "buyer"
    }
    
    var body: some View {
        NavigationView {
            ScrollView {
                VStack(spacing: 20) {
                    // Listing Preview
                    listingPreview
                    
                    // Offer Amount Input
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Offer")
                            .font(.headline)
                        
                        HStack {
                            Text("$")
                                .foregroundColor(.secondary)
                            TextField("0.00", text: $offerAmount)
                                .keyboardType(.decimalPad)
                        }
                        .padding()
                        .background(Color(UIColor.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    // Optional Message
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Message (Optional)")
                            .font(.headline)
                        
                        TextEditor(text: $offerMessage)
                            .frame(height: 100)
                            .padding(8)
                            .background(Color(UIColor.systemGray6))
                            .cornerRadius(10)
                            .overlay(
                                RoundedRectangle(cornerRadius: 10)
                                    .stroke(Color.gray.opacity(0.2), lineWidth: 1)
                            )
                    }
                    
                    // Info Box
                    infoBox
                    
                    // Submit Button
                    Button(action: submitOffer) {
                        if isSubmitting {
                            ProgressView()
                                .progressViewStyle(CircularProgressViewStyle(tint: .white))
                        } else {
                            Text("Submit Offer")
                                .fontWeight(.semibold)
                        }
                    }
                    .frame(maxWidth: .infinity)
                    .padding()
                    .background(isValidOffer ? Color.blue : Color.gray)
                    .foregroundColor(.white)
                    .cornerRadius(10)
                    .disabled(!isValidOffer || isSubmitting)
                }
                .padding()
            }
            .navigationTitle("Make Offer")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) {
                    Button("Cancel") { dismiss() }
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
            .overlay {
                if showOfferSent {
                    offerSentOverlay
                }
            }
        }
    }
    
    private var listingPreview: some View {
        HStack(spacing: 12) {
            // Photo
            if let photoURL = listing.photos.first ?? listing.photo, let url = URL(string: photoURL) {
                AsyncImage(url: url) { phase in
                    switch phase {
                    case .success(let image):
                        image
                            .resizable()
                            .aspectRatio(contentMode: .fill)
                            .frame(width: 60, height: 60)
                            .clipped()
                            .cornerRadius(8)
                    case .failure(_), .empty:
                        Rectangle()
                            .fill(Color.gray.opacity(0.3))
                            .frame(width: 60, height: 60)
                            .cornerRadius(8)
                            .overlay(
                                Image(systemName: "photo")
                                    .foregroundColor(.gray)
                            )
                    @unknown default:
                        EmptyView()
                    }
                }
            } else {
                Rectangle()
                    .fill(Color.gray.opacity(0.3))
                    .frame(width: 60, height: 60)
                    .cornerRadius(8)
                    .overlay(
                        Image(systemName: "photo")
                            .foregroundColor(.gray)
                    )
            }
            
            VStack(alignment: .leading, spacing: 4) {
                Text(listing.title)
                    .font(.subheadline)
                    .fontWeight(.medium)
                    .lineLimit(2)
                
                if listing.intent == .seek {
                    // Seek listing - show budget
                    if let budgetMax = listing.budgetMax {
                        Text("Budget: up to $\(String(format: "%.2f", budgetMax))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                } else {
                    // Regular listing - show seller's posted price (fees shown at checkout)
                    if let sellerPrice = listing.price {
                        Text("Listed at: $\(String(format: "%.2f", sellerPrice))")
                            .font(.caption)
                            .foregroundColor(.secondary)
                    }
                }
            }
            
            Spacer()
        }
        .padding()
        .background(Color(UIColor.systemGray6))
        .cornerRadius(10)
    }
    
    private var infoBox: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: "info.circle.fill")
                    .foregroundColor(.blue)
                Text("How Offers Work")
                    .font(.subheadline)
                    .fontWeight(.semibold)
            }
            
            if listing.intent == .offer {
                Text("• The seller can accept, reject, or counter your offer")
                Text("• You'll be notified of any response via chat and push notification")
                Text("• If accepted, you'll complete payment (fees will be added at checkout)")
            } else {
                Text("• The buyer can accept, reject, or counter your offer")
                Text("• They'll be notified via chat and push notification")
                Text("• If accepted, they'll complete payment (fees added at checkout)")
            }
        }
        .font(.caption)
        .foregroundColor(.secondary)
        .padding()
        .background(Color.blue.opacity(0.1))
        .cornerRadius(10)
    }
    
    private var offerSentOverlay: some View {
        ZStack {
            // Semi-transparent background
            Color.black.opacity(0.4)
                .ignoresSafeArea()
            
            // Success card
            VStack(spacing: 20) {
                // Success icon with animation
                Image(systemName: "checkmark.circle.fill")
                    .font(.system(size: 60))
                    .foregroundColor(.green)
                    .scaleEffect(showOfferSent ? 1.0 : 0.5)
                    .animation(.spring(response: 0.3, dampingFraction: 0.6), value: showOfferSent)
                
                VStack(spacing: 8) {
                    Text("Offer Sent!")
                        .font(.title2)
                        .fontWeight(.bold)
                    
                    Text("The seller will be notified")
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                }
            }
            .padding(40)
            .background(
                RoundedRectangle(cornerRadius: 20)
                    .fill(Color(UIColor.systemBackground))
                    .shadow(color: Color.black.opacity(0.2), radius: 20, x: 0, y: 10)
            )
            .padding(.horizontal, 40)
        }
    }
    
    private func submitOffer() {
        guard let currentUserId = authManager.currentUserId else {
            errorMessage = "You must be logged in to make an offer"
            return
        }
        
        guard let amountCents = offerAmountCents else {
            errorMessage = "Please enter a valid offer amount"
            return
        }
        
        Task {
            await MainActor.run { isSubmitting = true }
            
            do {
                // Determine toUserId based on listing type
                let toUserId: String
                if listing.intent == .seek {
                    // Seller offering to seeker (buyer)
                    toUserId = listing.user.id
                } else {
                    // Buyer offering to seller
                    toUserId = listing.user.id
                }
                
                let offer = try await offerService.createOffer(
                    listingId: listing.id,
                    listingType: listingType,
                    toUserId: toUserId,
                    amountCents: amountCents,
                    message: offerMessage.isEmpty ? nil : offerMessage,
                    fromUserId: currentUserId
                )
                
                print("✅ Offer created: \(offer.id)")
                
                await MainActor.run {
                    isSubmitting = false
                    showOfferSent = true
                }
                
                // Auto-dismiss after showing success for 1.5 seconds
                try? await Task.sleep(nanoseconds: 1_500_000_000)
                
                await MainActor.run {
                    dismiss()
                }
            } catch {
                await MainActor.run {
                    errorMessage = "Failed to create offer: \(error.localizedDescription)"
                    isSubmitting = false
                }
            }
        }
    }
}

// Preview
struct MakeOfferSheet_Previews: PreviewProvider {
    static var previews: some View {
        MakeOfferSheet(listing: ListingWithUser.sampleListing)
            .environmentObject(AuthManager())
    }
}

