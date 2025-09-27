import SwiftUI

struct AllOffersView: View {
    @EnvironmentObject private var authManager: AuthManager
    @State private var userOffers: [UserOffer] = []
    @State private var isLoading = true
    @State private var errorMessage: String?
    @State private var selectedOffer: UserOffer?
    @State private var showingOfferAcceptance = false
    @State private var isProcessingOffer = false
    @State private var offerError: String?
    
    var body: some View {
        NavigationView {
            VStack {
                if isLoading {
                    ProgressView("Loading offers...")
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else if userOffers.isEmpty {
                    VStack(spacing: 20) {
                        Image(systemName: "tray")
                            .font(.system(size: 60))
                            .foregroundColor(.secondary)
                        
                        Text("No offers yet")
                            .font(.title2)
                            .fontWeight(.semibold)
                        
                        Text("When sellers respond to your wanted posts, their offers will appear here.")
                            .multilineTextAlignment(.center)
                            .foregroundColor(.secondary)
                            .padding(.horizontal)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                } else {
                    ScrollView {
                        LazyVStack(spacing: 12) {
                            ForEach(userOffers) { offer in
                                offerCard(offer)
                            }
                        }
                        .padding()
                    }
                }
            }
            .navigationTitle("All Offers")
            .navigationBarTitleDisplayMode(.large)
            .refreshable {
                await loadOffers()
            }
        }
        .onAppear {
            Task { await loadOffers() }
        }
        .sheet(isPresented: $showingOfferAcceptance) {
            if let offer = selectedOffer {
                OfferAcceptanceDetailView(
                    userOffer: offer,
                    isProcessing: $isProcessingOffer,
                    errorMessage: $offerError,
                    onAccept: { acceptOffer(offer) },
                    onDecline: { declineOffer(offer) },
                    onDismiss: { showingOfferAcceptance = false }
                )
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
    
    private func offerCard(_ offer: UserOffer) -> some View {
        Button(action: {
            selectedOffer = offer
            showingOfferAcceptance = true
        }) {
            VStack(alignment: .leading, spacing: 12) {
                // Header with status
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(offer.seekListingTitle)
                            .font(.headline)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        Text("From: \(offer.sellerName)")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                    
                    Spacer()
                    
                    VStack(alignment: .trailing, spacing: 4) {
                        Text(offer.formattedPrice ?? "$0.00")
                            .font(.title3)
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                        
                        HStack {
                            Image(systemName: statusIcon(for: offer.status))
                                .foregroundColor(statusColor(for: offer.status))
                            Text(offer.status.capitalized)
                                .font(.caption)
                                .fontWeight(.medium)
                                .foregroundColor(statusColor(for: offer.status))
                        }
                    }
                }
                
                // Message preview if available
                if let message = offer.message, !message.isEmpty {
                    Text(message)
                        .font(.body)
                        .foregroundColor(.secondary)
                        .lineLimit(2)
                        .padding(.top, 4)
                }
                
                // Action buttons for pending offers
                if offer.canAccept {
                    HStack(spacing: 12) {
                        Button(action: { acceptOffer(offer) }) {
                            Label("Accept", systemImage: "checkmark.circle.fill")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.white)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color.green)
                                .cornerRadius(8)
                        }
                        
                        Button(action: { declineOffer(offer) }) {
                            Label("Decline", systemImage: "xmark.circle")
                                .font(.subheadline)
                                .fontWeight(.medium)
                                .foregroundColor(.red)
                                .padding(.horizontal, 16)
                                .padding(.vertical, 8)
                                .background(Color(.systemGray6))
                                .cornerRadius(8)
                        }
                        
                        Spacer()
                    }
                    .padding(.top, 8)
                }
                
                // Date
                HStack {
                    Text(offer.createdAt.formatted(date: .abbreviated, time: .shortened))
                        .font(.caption)
                        .foregroundColor(.secondary)
                    Spacer()
                }
            }
            .padding()
            .background(Color(UIColor.secondarySystemBackground))
            .cornerRadius(12)
            .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        }
        .buttonStyle(PlainButtonStyle())
    }
    
    private func loadOffers() async {
        isLoading = true
        errorMessage = nil
        
        do {
            userOffers = try await OfferService.shared.getUserOffers(role: .seeker)
            isLoading = false
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load offers: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func acceptOffer(_ offer: UserOffer) {
        guard let offerId = UUID(uuidString: offer.offerId.uuidString) else { return }
        
        isProcessingOffer = true
        offerError = nil
        
        Task {
            do {
                let success = try await OfferService.shared.acceptOfferStatus(offerId)
                await MainActor.run {
                    isProcessingOffer = false
                    showingOfferAcceptance = false
                    if success {
                        errorMessage = "Offer accepted! Please check your wallet to complete payment."
                    }
                    // Refresh offers
                    Task {
                        await loadOffers()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingOffer = false
                    offerError = error.localizedDescription
                }
            }
        }
    }
    
    private func declineOffer(_ offer: UserOffer) {
        guard let offerId = UUID(uuidString: offer.offerId.uuidString) else { return }
        
        isProcessingOffer = true
        offerError = nil
        
        Task {
            do {
                try await OfferService.shared.declineOffer(offerId)
                await MainActor.run {
                    isProcessingOffer = false
                    showingOfferAcceptance = false
                    // Refresh offers
                    Task {
                        await loadOffers()
                    }
                }
            } catch {
                await MainActor.run {
                    isProcessingOffer = false
                    offerError = error.localizedDescription
                }
            }
        }
    }
    
    private func statusIcon(for status: String) -> String {
        switch status {
        case "pending":
            return "clock.circle.fill"
        case "accepted":
            return "checkmark.circle.fill"
        case "declined":
            return "xmark.circle.fill"
        default:
            return "questionmark.circle.fill"
        }
    }
    
    private func statusColor(for status: String) -> Color {
        switch status {
        case "pending":
            return .orange
        case "accepted":
            return .green
        case "declined":
            return .red
        default:
            return .gray
        }
    }
}

struct AllOffersView_Previews: PreviewProvider {
    static var previews: some View {
        AllOffersView()
            .environmentObject(AuthManager())
    }
}
