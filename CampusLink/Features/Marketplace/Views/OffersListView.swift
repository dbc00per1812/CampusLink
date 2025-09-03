import SwiftUI

struct OffersListView: View {
    let seekListing: ListingWithUser
    @EnvironmentObject private var authManager: AuthManager
    
    @State private var offers: [Offer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if AppConfig.enableSeekMode {
                    if isLoading {
                        ProgressView("Loading offers...")
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else if offers.isEmpty {
                        VStack(spacing: 20) {
                            Image(systemName: "tray")
                                .font(.system(size: 60))
                                .foregroundColor(.secondary)
                            
                            Text("No offers yet")
                                .font(.title2)
                                .fontWeight(.semibold)
                            
                            Text("When sellers respond to your wanted post, their offers will appear here.")
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                        }
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                    } else {
                        ScrollView {
                            LazyVStack(spacing: 12) {
                                ForEach(offers) { offer in
                                    OfferRowView(offer: offer) { action in
                                        handleOfferAction(offer: offer, action: action)
                                    }
                                }
                            }
                            .padding()
                        }
                    }
                } else {
                    // Feature disabled
                    VStack(spacing: 20) {
                        Image(systemName: "hammer.circle")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("Coming Soon")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("Managing offers is currently under development.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                }
            }
            .navigationTitle("Offers")
            .navigationBarTitleDisplayMode(.inline)
        }
        .onAppear {
            if AppConfig.enableSeekMode {
                Task { await loadOffers() }
            }
        }
    }
    
    private func loadOffers() async {
        // Stub implementation
        await MainActor.run {
            isLoading = false
        }
    }
    
    private func handleOfferAction(offer: Offer, action: OfferAction) {
        // Stub implementation
        print("Offer action \(action) for offer \(offer.id)")
    }
}

enum OfferAction {
    case accept
    case decline
    case viewListing
    case contactSeller
}

struct OfferRowView: View {
    let offer: Offer
    let onAction: (OfferAction) -> Void
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Offer from seller")
                .font(.headline)
            
            if let message = offer.message, !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(2)
            }
            
            HStack(spacing: 12) {
                Button("Accept") {
                    onAction(.accept)
                }
                .buttonStyle(.borderedProminent)
                
                Button("Decline") {
                    onAction(.decline)
                }
                .buttonStyle(.bordered)
                
                Spacer()
                
                Button("View Listing") {
                    onAction(.viewListing)
                }
                .font(.caption)
                .foregroundColor(Color("ThemeColor"))
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
    }
}

struct OffersListView_Previews: PreviewProvider {
    static var previews: some View {
        OffersListView(seekListing: .sampleListing)
            .environmentObject(AuthManager())
    }
}
