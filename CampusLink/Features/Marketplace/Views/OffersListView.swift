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
        guard let currentUserId = authManager.currentUserId else { return }
        
        do {
            // Update offer status to accepted
            let _: [Offer] = try await supabase
                .from("offers")
                .update(["status": "accepted", "updated_at": Date().ISO8601Format()])
                .eq("id", value: offer.id.uuidString)
                .execute()
                .value
            
            // Archive the seek listing
            let _: [Listing] = try await supabase
                .from("listings")
                .update(["archived": "true", "status": "inactive"])
                .eq("id", value: seekListing.id.uuidString)
                .execute()
                .value
            
            // Create order using the seller's listing
            await createOrderFromOffer(offer)
            
            // Decline all other pending offers for this seek
            let _: [Offer] = try await supabase
                .from("offers")
                .update(["status": "declined"])
                .eq("seek_listing_id", value: seekListing.id.uuidString)
                .neq("id", value: offer.id.uuidString)
                .eq("status", value: "pending")
                .execute()
                .value
            
            // Analytics: Track offer acceptance
            print("📊 Analytics: Offer accepted - Seek: \(seekListing.id), Offer: \(offer.id)")
            
            // Refresh offers list
            await loadOffers()
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to accept offer: \(error.localizedDescription)"
            }
        }
    }
    
    private func declineOffer(_ offer: Offer) async {
        do {
            let _: [Offer] = try await supabase
                .from("offers")
                .update(["status": "declined", "updated_at": Date().ISO8601Format()])
                .eq("id", value: offer.id.uuidString)
                .execute()
                .value
            
            // Analytics: Track offer decline
            print("📊 Analytics: Offer declined - Seek: \(seekListing.id), Offer: \(offer.id)")
            
            // Refresh offers list
            await loadOffers()
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to decline offer: \(error.localizedDescription)"
            }
        }
    }
    
    private func createOrderFromOffer(_ offer: Offer) async {
        do {
            // Get the seller's listing details to determine price
            let sellerListing: Listing = try await supabase
                .from("listings")
                .select("*")
                .eq("id", value: offer.offerListingId.uuidString)
                .single()
                .execute()
                .value
            
            // Create OrderCreate object
            let basePriceCents = Int((sellerListing.price ?? 0) * 100)
            let orderCreate = OrderCreate(
                listingId: offer.offerListingId,  // Use seller's listing, not the seek
                buyerId: UUID(uuidString: offer.seekerId) ?? UUID(),
                sellerId: UUID(uuidString: offer.sellerId) ?? UUID(),
                priceCents: basePriceCents, // Convert to cents
                paymentMethod: .card, // Default to card for now
                timeSlotId: nil // TODO: Handle time slots if needed
            )
            
            // Create the order using OrderService
            let _ = try await OrderService.shared.createOrder(orderCreate)
            
            print("✅ Order created successfully from offer \(offer.id)")
            
        } catch {
            await MainActor.run {
                errorMessage = "Failed to create order: \(error.localizedDescription)"
            }
            print("❌ Failed to create order from offer: \(error)")
        }
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
            HStack {
                Text("Offer from \(offer.sellerId)")
                    .font(.headline)
                    .lineLimit(1)
                
                Spacer()
                
                Text(offer.createdAt, style: .relative)
                    .font(.caption)
                    .foregroundColor(.secondary)
            }
            
            if let message = offer.message, !message.isEmpty {
                Text(message)
                    .font(.body)
                    .foregroundColor(.secondary)
                    .lineLimit(3)
                    .padding(.vertical, 4)
                    .padding(.horizontal, 8)
                    .background(Color(.systemGray5))
                    .cornerRadius(8)
            }
            
            // Status badge
            HStack {
                Text(offer.status.capitalized)
                    .font(.caption)
                    .fontWeight(.medium)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(offer.statusColor)
                    .foregroundColor(.white)
                    .cornerRadius(6)
                Spacer()
            }
            
            // Action buttons - only show for pending offers
            if offer.status == "pending" {
                HStack(spacing: 12) {
                    Button("Accept") {
                        onAction(.accept)
                    }
                    .buttonStyle(.borderedProminent)
                    .accessibilityLabel("Accept offer")
                    .accessibilityHint("Accepts this offer and creates an order")
                    
                    Button("Decline") {
                        onAction(.decline)
                    }
                    .buttonStyle(.bordered)
                    .accessibilityLabel("Decline offer")
                    .accessibilityHint("Declines this offer")
                    
                    Spacer()
                    
                    Button("View Listing") {
                        onAction(.viewListing)
                    }
                    .font(.caption)
                    .foregroundColor(Color("ThemeColor"))
                    .accessibilityLabel("View offered listing")
                    .accessibilityHint("Shows details of the item being offered")
                }
            }
        }
        .padding()
        .background(Color(.systemGray6))
        .cornerRadius(12)
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
    let offerListingId: UUID
    let seekerId: String
    let sellerId: String
    let message: String?
    let status: String
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
