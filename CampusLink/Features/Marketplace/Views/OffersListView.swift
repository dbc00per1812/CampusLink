import SwiftUI
import Supabase

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
                            
                            Text("💡 Tip: Make sure your wanted post has a clear description and reasonable budget to attract offers.")
                                .font(.caption)
                                .multilineTextAlignment(.center)
                                .foregroundColor(.secondary)
                                .padding(.horizontal)
                                .padding(.top, 8)
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
        .alert("Error", isPresented: Binding(
            get: { errorMessage != nil },
            set: { if !$0 { errorMessage = nil } }
        )) {
            Button("OK") { errorMessage = nil }
        } message: {
            Text(errorMessage ?? "")
        }
    }
    
    private func loadOffers() async {
        guard let currentUserId = authManager.currentUserId else {
            await MainActor.run {
                errorMessage = "You must be logged in to view offers"
                isLoading = false
            }
            return
        }
        
        do {
            // Fetch offers for this seek listing where current user is the seeker
            let response: [OfferWithDetails] = try await supabase
                .from("offers")
                .select("""
                    *,
                    offer_listing:listings!offers_offer_listing_id_fkey(*,user:users(*)),
                    seller:users!offers_seller_id_fkey(*)
                """)
                .eq("seek_listing_id", value: seekListing.id.uuidString)
                .eq("seeker_id", value: currentUserId)
                .order("created_at", ascending: false)
                .execute()
                .value
            
            await MainActor.run {
                // Convert to simple Offer models
                self.offers = response.map { $0.toOffer() }
                isLoading = false
            }
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to load offers: \(error.localizedDescription)"
                isLoading = false
            }
        }
    }
    
    private func handleOfferAction(offer: Offer, action: OfferAction) {
        switch action {
        case .accept:
            Task { await acceptOffer(offer) }
        case .decline:
            Task { await declineOffer(offer) }
        case .viewListing:
            // TODO: Navigate to listing detail
            print("View listing for offer \(offer.id)")
        case .contactSeller:
            // TODO: Open chat with seller
            print("Contact seller for offer \(offer.id)")
        }
    }
    
    private func acceptOffer(_ offer: Offer) async {
        do {
            let response = try await OfferService.shared.acceptOffer(offer.id)
            
            await MainActor.run {
                errorMessage = "Offer accepted! Order #\(response.orderId.uuidString.prefix(8)) created."
                // Refresh offers list
                Task {
                    await loadOffers()
                }
            }
            
            print("📊 Analytics: Offer accepted - Seek: \(seekListing.id), Offer: \(offer.id)")
            
        } catch {
            await MainActor.run {
                let errorDesc = error.localizedDescription
                if errorDesc.contains("function") || errorDesc.contains("accept_offer") {
                    errorMessage = "Database setup required. Please run the offers migration script in Supabase first."
                } else {
                    errorMessage = "Failed to accept offer: \(errorDesc)"
                }
            }
            print("❌ Failed to accept offer: \(error)")
        }
    }
    
    private func declineOffer(_ offer: Offer) async {
        do {
            try await OfferService.shared.declineOffer(offer.id)
            
            print("📊 Analytics: Offer declined - Seek: \(seekListing.id), Offer: \(offer.id)")
            
            // Refresh offers list
            await loadOffers()
            
        } catch {
            await MainActor.run {
                let errorDesc = error.localizedDescription
                if errorDesc.contains("function") || errorDesc.contains("decline_offer") {
                    errorMessage = "Database setup required. Please run the offers migration script in Supabase first."
                } else {
                    errorMessage = "Failed to decline offer: \(errorDesc)"
                }
            }
            print("❌ Failed to decline offer: \(error)")
        }
    }
    
    // createOrderFromOffer is no longer needed - the accept_offer RPC function handles order creation
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
    
    @State private var sellerName: String = "Loading..."
    
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Offer from \(sellerName)")
                        .font(.headline)
                        .lineLimit(1)
                    
                    // Show offer amount
                    if let price = offer.formattedPrice {
                        Text(price)
                            .font(.title2)
                            .fontWeight(.bold)
                            .foregroundColor(Color("ThemeColor"))
                    } else {
                        Text("Custom offer")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                    }
                }
                
                Spacer()
                
                VStack(alignment: .trailing, spacing: 4) {
                    Text(offer.createdAt, style: .relative)
                        .font(.caption)
                        .foregroundColor(.secondary)
                    
                    // Status badge
                    Text(offer.status.capitalized)
                        .font(.caption)
                        .fontWeight(.medium)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(offer.statusColor.opacity(0.2))
                        .foregroundColor(offer.statusColor)
                        .cornerRadius(8)
                }
            }
            
            // Message from seller
            if let message = offer.message, !message.isEmpty {
                VStack(alignment: .leading, spacing: 4) {
                    Text("Message:")
                        .font(.caption)
                        .foregroundColor(.secondary)
                        .fontWeight(.medium)
                    
                    Text(message)
                        .font(.body)
                        .foregroundColor(.primary)
                        .lineLimit(3)
                        .padding(.vertical, 8)
                        .padding(.horizontal, 12)
                        .background(Color(.systemGray6))
                        .cornerRadius(8)
                }
            }
            
            // Action buttons for pending offers
            if offer.status == "pending" {
                HStack(spacing: 12) {
                    Button(action: { onAction(.accept) }) {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                            Text("Accept")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.white)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color.green)
                        .cornerRadius(10)
                    }
                    
                    Button(action: { onAction(.decline) }) {
                        HStack {
                            Image(systemName: "xmark.circle")
                            Text("Decline")
                        }
                        .font(.subheadline)
                        .fontWeight(.medium)
                        .foregroundColor(.red)
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(Color(.systemGray6))
                        .cornerRadius(10)
                    }
                    
                    Spacer()
                    
                    // Only show "View Listing" if there's an actual listing (not custom price)
                    if offer.offerListingId != nil {
                        Button(action: { onAction(.viewListing) }) {
                            Text("View Item")
                                .font(.caption)
                                .foregroundColor(Color("ThemeColor"))
                        }
                    }
                }
            }
        }
        .padding()
        .background(Color(.secondarySystemBackground))
        .cornerRadius(12)
        .shadow(color: Color.black.opacity(0.05), radius: 2, x: 0, y: 1)
        .task {
            await loadSellerName()
        }
    }
    
    private func loadSellerName() async {
        do {
            let seller: User = try await supabase
                .from("users")
                .select("name")
                .eq("id", value: offer.sellerId)
                .single()
                .execute()
                .value
            
            await MainActor.run {
                sellerName = seller.name ?? "Unknown Seller"
            }
        } catch {
            await MainActor.run {
                sellerName = "Seller"
            }
        }
    }
}

// Add status color extension for Offer
extension Offer {
    var statusColor: Color {
        switch status {
        case "pending": return .orange
        case "accepted": return .green
        case "declined": return .red
        case "withdrawn": return .gray
        case "expired": return .gray
        default: return .gray
        }
    }
}

// Helper model for fetching offers with details
struct OfferWithDetails: Codable {
    let id: UUID
    let seekListingId: UUID
    let offerListingId: UUID?
    let seekerId: String
    let sellerId: String
    let message: String?
    let status: String
    let priceCents: Int?
    let createdAt: Date
    let updatedAt: Date
    
    // Joined data
    let offerListing: ListingWithUser?
    let seller: User?
    
    enum CodingKeys: String, CodingKey {
        case id
        case seekListingId = "seek_listing_id"
        case offerListingId = "offer_listing_id"
        case seekerId = "seeker_id"
        case sellerId = "seller_id"
        case message, status
        case priceCents = "price_cents"
        case createdAt = "created_at"
        case updatedAt = "updated_at"
        case offerListing = "offer_listing"
        case seller
    }
    
    func toOffer() -> Offer {
        return Offer(
            id: id,
            seekListingId: seekListingId,
            offerListingId: offerListingId,
            seekerId: seekerId,
            sellerId: sellerId,
            message: message,
            status: status,
            priceCents: priceCents,
            createdAt: createdAt,
            updatedAt: updatedAt
        )
    }
}

struct OffersListView_Previews: PreviewProvider {
    static var previews: some View {
        OffersListView(seekListing: .sampleListing)
            .environmentObject(AuthManager())
    }
}
